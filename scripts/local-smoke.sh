#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

runtime_dir="$repo_root/.tmp/local"
kubeconfig_path="$runtime_dir/kubeconfig"
local_port="${LOCAL_FORGEJO_PORT:-3000}"

if [[ ! -s "$kubeconfig_path" ]]; then
  echo "ERROR: local kubeconfig not found. Run 'make local-up' first." >&2
  exit 1
fi

export KUBECONFIG="$kubeconfig_path"

kubectl -n platform rollout status statefulset/postgres --timeout=30s
kubectl -n platform rollout status deployment/forgejo --timeout=30s
kubectl -n platform get service forgejo-http >/dev/null

port_forward_log="$runtime_dir/forgejo-port-forward.log"
kubectl -n platform port-forward service/forgejo-http "$local_port:3000" >"$port_forward_log" 2>&1 &
port_forward_pid=$!

cleanup_port_forward() {
  kill "$port_forward_pid" >/dev/null 2>&1 || true
  wait "$port_forward_pid" >/dev/null 2>&1 || true
}
trap cleanup_port_forward EXIT

health_url="http://127.0.0.1:$local_port/api/healthz"
version_url="http://127.0.0.1:$local_port/api/v1/version"

healthy=false
for _ in $(seq 1 30); do
  if curl -fsS "$health_url" >"$runtime_dir/healthz.json"; then
    healthy=true
    break
  fi
  sleep 1
done

if [[ "$healthy" != "true" ]]; then
  echo "ERROR: Forgejo health endpoint did not become reachable" >&2
  cat "$port_forward_log" >&2 || true
  exit 1
fi

curl -fsS "$version_url" >"$runtime_dir/version.json"

expected_version="${FORGEJO_IMAGE_TAG%-rootless}"
if ! grep -Fq "$expected_version" "$runtime_dir/version.json"; then
  echo "ERROR: unexpected Forgejo version response" >&2
  cat "$runtime_dir/version.json" >&2
  exit 1
fi

echo "local Forgejo smoke: PASS ($expected_version)"
