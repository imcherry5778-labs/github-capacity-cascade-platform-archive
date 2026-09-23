.PHONY: check-local-config local-up local-smoke local-e2e local-down local-verify local-gitops-verify

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

.PHONY: terraform-check

terraform-check:
	terraform fmt -check -recursive infra/terraform
	terraform -chdir=infra/terraform/bootstrap init -backend=false
	terraform -chdir=infra/terraform/bootstrap validate
