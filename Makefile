# Shortcuts for common Flutter tasks. Run `make` or `make help` to list them.
#
# Uses `fvm flutter` when FVM is installed (version pinned in .fvmrc),
# otherwise whatever `flutter` is on PATH. Override either one if needed:
#   make test FLUTTER=~/Downloads/flutter/bin/flutter DART=~/Downloads/flutter/bin/dart

ifneq ($(shell command -v fvm 2>/dev/null),)
FLUTTER ?= fvm flutter
DART    ?= fvm dart
else
FLUTTER ?= flutter
DART    ?= dart
endif

# Optional backend URL for run targets, e.g. make run API_BASE_URL=http://192.168.1.10:5289/api/v1
API_BASE_URL ?=

# Local, git-ignored settings for the deployed backend (copy env/prod.example.json).
# Keeps the real URL out of this public repo.
PROD_ENV ?= env/prod.json
DEFINES := $(if $(API_BASE_URL),--dart-define=API_BASE_URL=$(API_BASE_URL))

# Optional device id for run targets (see `make devices`), e.g. make run DEVICE=emulator-5554
DEVICE ?=
DEVICE_FLAG := $(if $(DEVICE),-d $(DEVICE))

.DEFAULT_GOAL := help
.PHONY: help get upgrade outdated format format-check lint fix test coverage \
        check ci run run-prod run-release devices build-apk build-appbundle build-apk-prod prod-env clean \
        audit secrets workflow-lint

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} \
		/^## --- / {gsub(/^## --- | ---$$/, ""); printf "\n\033[1m%s\033[0m\n", $$0} \
		/^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## --- Dependencies ---

get: ## Install dependencies from pubspec.lock (same as CI)
	$(FLUTTER) pub get --enforce-lockfile

upgrade: ## Upgrade dependencies within pubspec constraints (updates pubspec.lock)
	$(FLUTTER) pub upgrade

outdated: ## Show dependencies with newer versions
	$(FLUTTER) pub outdated

## --- Code quality ---

format: ## Format lib/ and test/
	$(DART) format lib test

format-check: ## Fail if any file is not formatted (same as CI)
	$(DART) format --output=none --set-exit-if-changed lib test

lint: ## Run flutter analyze (same as CI)
	$(FLUTTER) analyze

fix: ## Apply automated lint fixes
	$(DART) fix --apply

test: ## Run all tests
	$(FLUTTER) test

coverage: ## Run tests with coverage (writes coverage/lcov.info)
	$(FLUTTER) test --coverage

check: format-check lint test ## Run the format, lint and test checks CI runs

ci: get check build-apk ## Run every Flutter job CI runs, including the APK build

## --- Run ---

devices: ## List connected devices and emulators
	$(FLUTTER) devices

run: ## Run in debug mode (optional: API_BASE_URL=..., DEVICE=...)
	$(FLUTTER) run $(DEVICE_FLAG) $(DEFINES)

run-prod: prod-env ## Run in debug mode against the deployed backend from env/prod.json (optional: DEVICE=...)
	$(FLUTTER) run $(DEVICE_FLAG) --dart-define-from-file=$(PROD_ENV)

run-release: ## Run in release mode (optional: API_BASE_URL=..., DEVICE=...)
	$(FLUTTER) run --release $(DEVICE_FLAG) $(DEFINES)

## --- Build ---

build-apk: ## Build release APK (build/app/outputs/flutter-apk/app-release.apk)
	$(FLUTTER) build apk --release $(DEFINES)

build-appbundle: ## Build release Android App Bundle
	$(FLUTTER) build appbundle --release $(DEFINES)

build-apk-prod: prod-env ## Build release APK for the deployed backend from env/prod.json
	$(FLUTTER) build apk --release --dart-define-from-file=$(PROD_ENV)

prod-env:
	@test -f $(PROD_ENV) || { echo "Missing $(PROD_ENV): copy env/prod.example.json and set API_BASE_URL"; exit 1; }

clean: ## Delete build outputs and re-fetch dependencies
	$(FLUTTER) clean
	$(FLUTTER) pub get

## --- Security (needs the tool installed locally) ---

audit: ## Scan pubspec.lock for known vulnerabilities (osv-scanner)
	@command -v osv-scanner >/dev/null || { echo "osv-scanner not installed: https://github.com/google/osv-scanner"; exit 1; }
	osv-scanner scan source --lockfile=pubspec.lock

secrets: ## Scan git history for leaked secrets (gitleaks)
	@command -v gitleaks >/dev/null || { echo "gitleaks not installed: https://github.com/gitleaks/gitleaks"; exit 1; }
	gitleaks git --config .gitleaks.toml --redact --no-banner .

workflow-lint: ## Lint GitHub Actions workflows (actionlint)
	@command -v actionlint >/dev/null || { echo "actionlint not installed: https://github.com/rhysd/actionlint"; exit 1; }
	actionlint
