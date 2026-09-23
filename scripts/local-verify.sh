#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

runtime_dir="$repo_root/.tmp/local"
kubeconfig_path="$runtime_dir/kubeconfig"

cleanup() {
  local exit_code=$?

  if [[ "$exit_code" -ne 0 && -s "$kubeconfig_path" ]]; then
    export KUBECONFIG="$kubeconfig_path"
    echo "=== local verification diagnostics ===" >&2
    kubectl -n platform get pods -o wide >&2 || true
    kubectl -n platform get events --sort-by=.lastTimestamp >&2 || true
  fi

  bash ./scripts/local-down.sh || true
  exit "$exit_code"
}
trap cleanup EXIT

make check-local-config
bash ./scripts/local-up.sh
bash ./scripts/local-smoke.sh
make local-e2e

echo "local runtime baseline: PASS"
