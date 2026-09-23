#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

cluster_name="capacity-cascade-platform"
runtime_dir="$repo_root/.tmp/local"
kubeconfig_path="$runtime_dir/kubeconfig"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command_name" >&2
    exit 1
  fi
}

for command_name in docker k3d kubectl helm openssl; do
  require_command "$command_name"
done

docker info >/dev/null

k3d version | grep -Fq "k3d version $K3D_VERSION"

actual_helm_version="$(helm version --template '{{.Version}}')"
if [[ "$actual_helm_version" != "$HELM_VERSION" ]]; then
  echo "ERROR: Helm version mismatch: expected $HELM_VERSION, got $actual_helm_version" >&2
  exit 1
fi

kubectl version --client -o yaml | grep -Fq "gitVersion: $KUBECTL_VERSION"

if k3d cluster list | awk 'NR > 1 {print $1}' | grep -Fxq "$cluster_name"; then
  echo "ERROR: local cluster already exists: $cluster_name" >&2
  echo "Run 'make local-down' before creating a fresh baseline." >&2
  exit 1
fi

rm -rf "$runtime_dir"
mkdir -p "$runtime_dir"

k3d cluster create --config platform/local/k3d.yaml --wait
k3d kubeconfig get "$cluster_name" >"$kubeconfig_path"
chmod 600 "$kubeconfig_path"
export KUBECONFIG="$kubeconfig_path"

kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl create namespace platform

database_password="$(openssl rand -hex 24)"
admin_password="$(openssl rand -hex 24)"

kubectl -n platform create secret generic forgejo-database \
  --from-literal=password="$database_password"

kubectl -n platform create secret generic forgejo-admin \
  --from-literal=username=platform-admin \
  --from-literal=password="$admin_password"

kubectl apply -f platform/local/postgres.yaml
kubectl -n platform rollout status statefulset/postgres --timeout=180s

if [[ "${LOCAL_SKIP_FORGEJO:-false}" == "true" ]]; then
  echo "local backing services: READY"
  exit 0
fi

helm upgrade --install forgejo \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version "$FORGEJO_CHART_VERSION" \
  --namespace platform \
  -f platform/forgejo/values-common.yaml \
  -f platform/forgejo/values-local.yaml \
  --wait \
  --timeout 5m

kubectl -n platform rollout status deployment/forgejo --timeout=300s

echo "local platform: READY"
