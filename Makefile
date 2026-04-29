.PHONY: build runtime grub-preview menu clean cache-clean shell down help test

COMPOSE := docker compose

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build ISO + portable runtime folder
	mkdir -p tmp/output
	$(COMPOSE) up --build builder

runtime: ## Build hasta runtime/ + grub-entry.cfg
	mkdir -p tmp/output
	$(COMPOSE) run --rm builder runtime

grub-preview: ## Generate grub.cfg + grub-entry.cfg + preview ISO without full rootfs build
	mkdir -p tmp/output
	$(COMPOSE) run --rm builder grub-preview

menu: ## Open interactive build menu inside the builder container
	mkdir -p tmp/output
	$(COMPOSE) run --rm --entrypoint /work/scripts/build-menu.sh builder

test: ## Run repository verification scripts
	@for test_script in $$(find tests -type f -name 'check-*.sh' | sort); do \
		echo "==> $$test_script"; \
		bash "$$test_script"; \
	done

clean: ## Remove generated output
	rm -rf tmp/output/*

cache-clean: ## Remove apt-cacher-ng cache volumes
	$(COMPOSE) down
	rm -rf tmp/apt-cacher

shell: ## Open shell in build container
	$(COMPOSE) run --rm --entrypoint /bin/bash builder

down: ## Stop compose services
	$(COMPOSE) down
