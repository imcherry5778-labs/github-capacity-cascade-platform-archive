#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

target_revision="${GITOPS_TARGET_REVISION:-$(git rev-parse HEAD)}"
runtime_dir="$repo_root/.tmp/local"
kubeconfig_path="$runtime_dir/kubeconfig"
application_render="$runtime_dir/forgejo-application.yaml"

if [[ ! "$target_revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: GitOps target revision must be an exact 40-character Git SHA" >&2
  exit 1
fi

cleanup() {
  local exit_code=$?

  if [[ "$exit_code" -ne 0 && -s "$kubeconfig_path" ]]; then
    export KUBECONFIG="$kubeconfig_path"
    echo "=== GitOps verification diagnostics ===" >&2
    kubectl -n argocd get application forgejo -o yaml >&2 || true
    kubectl -n argocd get pods -o wide >&2 || true
    kubectl -n platform get pods -o wide >&2 || true
    kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=120 >&2 || true
  fi

  bash ./scripts/local-down.sh || true
  exit "$exit_code"
}
trap cleanup EXIT

wait_for_application() {
  local phase="$1"
  local sync_status=""
  local health_status=""

  for _ in $(seq 1 150); do
    sync_status="$(kubectl -n argocd get application forgejo -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n argocd get application forgejo -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
      echo "Argo CD application: $phase PASS (Synced/Healthy)"
      return 0
    fi

    sleep 2
  done

  echo "ERROR: Argo CD application did not become Synced/Healthy during $phase" >&2
  return 1
}

LOCAL_SKIP_FORGEJO=true bash ./scripts/local-up.sh
export KUBECONFIG="$kubeconfig_path"

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_COMMIT/manifests/core-install.yaml"
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
for deployment in argocd-applicationset-controller argocd-redis argocd-repo-server; do
  kubectl -n argocd rollout status "deployment/$deployment" --timeout=300s
done

kubectl apply -f platform/gitops/project.yaml
sed "s/__TARGET_REVISION__/$target_revision/g" \
  platform/gitops/forgejo-application.yaml.tmpl \
  >"$application_render"
kubectl apply -f "$application_render"

wait_for_application "initial reconciliation"
kubectl -n platform rollout status deployment/forgejo --timeout=300s

if helm -n platform list -q | grep -Fxq forgejo; then
  echo "ERROR: Forgejo was installed as a Helm release instead of being reconciled by Argo CD" >&2
  exit 1
fi

make local-smoke
make local-e2e

echo "GitOps drift test: scale Forgejo deployment to zero"
kubectl -n platform scale deployment/forgejo --replicas=0
[[ "$(kubectl -n platform get deployment forgejo -o jsonpath='{.spec.replicas}')" == "0" ]]

kubectl -n argocd annotate application forgejo \
  argocd.argoproj.io/refresh=hard \
  --overwrite

self_healed=false
for _ in $(seq 1 120); do
  replicas="$(kubectl -n platform get deployment forgejo -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
  if [[ "$replicas" == "1" ]]; then
    self_healed=true
    break
  fi
  sleep 2
done

if [[ "$self_healed" != "true" ]]; then
  echo "ERROR: Argo CD self-heal did not restore Forgejo replicas to 1" >&2
  exit 1
fi

kubectl -n platform rollout status deployment/forgejo --timeout=300s
wait_for_application "post-drift reconciliation"
make local-smoke
make local-e2e

echo "Argo CD Core GitOps reconciliation: PASS"
