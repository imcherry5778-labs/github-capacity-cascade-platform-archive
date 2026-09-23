#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cluster_name="capacity-cascade-platform"
runtime_dir="$repo_root/.tmp/local"

if command -v k3d >/dev/null 2>&1; then
  if k3d cluster list | awk 'NR > 1 {print $1}' | grep -Fxq "$cluster_name"; then
    k3d cluster delete "$cluster_name"
  fi
fi

rm -rf "$runtime_dir"

echo "local platform: CLEAN"
