#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

revision="${GITOPS_REVISION:-}"
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: GITOPS_REVISION must be an exact 40-character Git commit SHA that is reachable from the remote repository" >&2
  exit 1
fi

runtime_dir="$repo_root/.tmp/local"
kubeconfig_path="$runtime_dir/kubeconfig"

cleanup() {
  local exit_code=$?

  if [[ "$exit_code" -ne 0 && -s "$kubeconfig_path" ]]; then
    export KUBECONFIG="$kubeconfig_path"
    echo "=== GitOps verification diagnostics ===" >&2
    kubectl -n argocd get applications.argoproj.io -o wide >&2 || true
    kubectl -n argocd get pods -o wide >&2 || true
    kubectl -n platform get service postgres -o yaml >&2 || true
  fi

  bash ./scripts/local-down.sh || true
  exit "$exit_code"
}
trap cleanup EXIT

make local-up
export KUBECONFIG="$kubeconfig_path"

kubectl create namespace argocd
core_install_url="https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_CD_CORE_INSTALL_COMMIT/manifests/core-install.yaml"
kubectl apply --namespace argocd --filename "$core_install_url" >/dev/null

kubectl -n argocd rollout status deployment/argocd-applicationset-controller --timeout=240s
kubectl -n argocd rollout status deployment/argocd-redis --timeout=240s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=240s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=240s

kubectl apply -f platform/gitops/project.yaml >/dev/null

app_manifest="$runtime_dir/postgres-local-application.yaml"
sed "s/targetRevision: main/targetRevision: $revision/" \
  platform/gitops/applications/postgres-local.yaml >"$app_manifest"
kubectl apply -f "$app_manifest" >/dev/null

wait_for_application() {
  local expected_sync="$1"
  local expected_health="$2"
  local attempts="${3:-60}"

  for _ in $(seq 1 "$attempts"); do
    local sync_status health_status
    sync_status="$(kubectl -n argocd get application postgres-local -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n argocd get application postgres-local -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    if [[ "$sync_status" == "$expected_sync" && "$health_status" == "$expected_health" ]]; then
      return 0
    fi

    sleep 2
  done

  echo "ERROR: postgres-local did not reach $expected_sync / $expected_health" >&2
  kubectl -n argocd get application postgres-local -o yaml >&2 || true
  return 1
}

wait_for_sync_status() {
  local expected_sync="$1"
  local attempts="${2:-30}"

  for _ in $(seq 1 "$attempts"); do
    local sync_status
    sync_status="$(kubectl -n argocd get application postgres-local -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    if [[ "$sync_status" == "$expected_sync" ]]; then
      return 0
    fi
    sleep 2
  done

  echo "ERROR: postgres-local did not reach sync status $expected_sync" >&2
  return 1
}

wait_for_application Synced Healthy 90
echo "GitOps application initial state: Synced / Healthy"

kubectl -n argocd patch application postgres-local --type=merge --patch \
  '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":false,"selfHeal":false}}}}' >/dev/null

kubectl -n platform patch service postgres --type=json --patch \
  '[{"op":"replace","path":"/spec/ports/0/targetPort","value":5999}]' >/dev/null

kubectl -n argocd annotate application postgres-local argocd.argoproj.io/refresh=hard --overwrite >/dev/null
wait_for_sync_status OutOfSync 45
echo "GitOps drift detection: OutOfSync PASS"

kubectl -n argocd patch application postgres-local --type=merge --patch \
  '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":false,"selfHeal":true}}}}' >/dev/null
kubectl -n argocd annotate application postgres-local argocd.argoproj.io/refresh=hard --overwrite >/dev/null

service_restored=false
for _ in $(seq 1 60); do
  target_port="$(kubectl -n platform get service postgres -o jsonpath='{.spec.ports[0].targetPort}')"
  if [[ "$target_port" == "postgres" ]]; then
    service_restored=true
    break
  fi
  sleep 2
done

if [[ "$service_restored" != "true" ]]; then
  echo "ERROR: Argo CD self-heal did not restore PostgreSQL Service targetPort" >&2
  exit 1
fi

wait_for_application Synced Healthy 60
echo "GitOps self-heal: PASS"

bash ./scripts/local-smoke.sh
echo "local GitOps reconciliation: PASS"
