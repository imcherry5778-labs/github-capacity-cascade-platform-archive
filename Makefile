.PHONY: check-versions check-local-config local-up local-smoke local-e2e local-down local-verify local-gitops-verify terraform-check

check-versions:
	bash ./scripts/check-version-inventory.sh

check-local-config:
	bash ./scripts/check-local-config.sh

local-up:
	bash ./scripts/local-up.sh

local-smoke:
	bash ./scripts/local-smoke.sh

local-e2e:
	bash ./tests/e2e/forgejo-developer-journey.sh

local-down:
	bash ./scripts/local-down.sh

local-verify:
	bash ./scripts/local-verify.sh

local-gitops-verify:
	bash ./tests/infrastructure/argocd-reconciliation.sh

terraform-check:
	bash ./scripts/check-version-inventory.sh
	terraform fmt -check -recursive infra/terraform
	terraform -chdir=infra/terraform/bootstrap init -backend=false -lockfile=readonly
	terraform -chdir=infra/terraform/bootstrap validate
