#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

require_literal() {
  local path="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$path"; then
    echo "ERROR: version inventory mismatch: $path does not contain '$expected'" >&2
    exit 1
  fi
}

require_literal platform/local/k3d.yaml "image: $K3S_IMAGE"
require_literal platform/local/postgres.yaml "image: $POSTGRES_IMAGE"
require_literal platform/forgejo/values-common.yaml "tag: $FORGEJO_IMAGE_TAG"
require_literal platform/gitops/forgejo-application.yaml.tmpl "targetRevision: $FORGEJO_CHART_VERSION"
require_literal infra/terraform/bootstrap/versions.tf "required_version = \"= $TERRAFORM_VERSION\""
require_literal infra/terraform/bootstrap/versions.tf "version = \"= $AZURERM_PROVIDER_VERSION\""

echo "version inventory consistency: PASS"
