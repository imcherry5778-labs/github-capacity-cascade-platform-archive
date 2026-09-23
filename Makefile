.PHONY: check-local-config local-up local-smoke local-down local-verify

check-local-config:
	bash ./scripts/check-local-config.sh

local-up:
	bash ./scripts/local-up.sh

local-smoke:
	bash ./scripts/local-smoke.sh

local-down:
	bash ./scripts/local-down.sh

local-verify:
	bash ./scripts/local-verify.sh
