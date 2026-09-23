#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command_name" >&2
    exit 1
  fi
}

require_command helm
actual_helm_version="$(helm version --template '{{.Version}}')"
if [[ "$actual_helm_version" != "$HELM_VERSION" ]]; then
  echo "ERROR: Helm version mismatch: expected $HELM_VERSION, got $actual_helm_version" >&2
  exit 1
fi

grep -Fq "image: $K3S_IMAGE" platform/local/k3d.yaml
grep -Fq "tag: ${FORGEJO_IMAGE_TAG}" platform/forgejo/values-common.yaml
grep -Fq "image: ${POSTGRES_IMAGE}" platform/postgres/local.yaml

grep -Fq "kind: Service" platform/postgres/local.yaml
grep -Fq "kind: StatefulSet" platform/postgres/local.yaml
grep -Fq "secretKeyRef:" platform/postgres/local.yaml
if grep -Eq '^[[:space:]]*POSTGRES_PASSWORD:[[:space:]]+[^$]' platform/postgres/local.yaml; then
  echo "ERROR: literal PostgreSQL password detected" >&2
  exit 1
fi
tmp_render="$(mktemp)"
trap 'rm -f "$tmp_render"' EXIT

helm template forgejo \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version "$FORGEJO_CHART_VERSION" \
  --namespace platform \
  -f platform/forgejo/values-common.yaml \
  -f platform/forgejo/values-local.yaml \
  >"$tmp_render"

grep -Fq "code.forgejo.org/forgejo/forgejo:${FORGEJO_IMAGE_TAG}" "$tmp_render"
grep -Fq "kind: Deployment" "$tmp_render"

echo "local baseline configuration: PASS"
