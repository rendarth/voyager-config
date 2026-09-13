#!/usr/bin/env make
# ==============================================================================
# voyager-config: development / quality / release targets
# ==============================================================================
SHELL := /usr/bin/env bash
.PHONY: help lint fmt fmt-check test test-bats test-matrix verify setup-test \
        tarball sha256 ci clean

BATS_VERSION := 1.11.0
TOOLS        := .tools
BATS         := $(TOOLS)/bats-core/bin/bats
SHELLCHECK   := $(shell command -v shellcheck 2>/dev/null || echo "")

FILES := $(shell find . -name '*.sh' -not -path './.git/*' -not -path './.tools/*' -not -path './configs/*' -not -path './portable/*' | sort)
# shfmt only on script files that don't embed heredoc templates (theme gens contain .qml/.css)
SHFMT_FILES := $(filter-out ./scripts/theme/%,$(FILES))

help:
	@printf 'Targets:\n'
	@printf '  make setup-test   install bats + check shellcheck/shfmt\n'
	@printf '  make lint         shellcheck + shfmt diff\n'
	@printf '  make test         bats suite (repo-tree, lib-common)\n'
	@printf '  make test-matrix  container smoke matrix (archlean, debian, ubuntu, fedora, alpine)\n'
	@printf '  make verify       verify-session.sh --repo\n'
	@printf '  make tarball      build tarball + sha256sum.txt (tagged releases)\n'
	@printf '  make clean        remove .tools\n'

setup-test:
	@command -v docker >/dev/null 2>&1 || echo "NOTE: docker not found; test-matrix needs it."
	@test -x "$(BATS)" || { \
	  mkdir -p "$(TOOLS)"; \
	  echo "Fetching bats-core $(BATS_VERSION) ..."; \
	  curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/v$(BATS_VERSION).tar.gz" -o "$(TOOLS)/bats.tgz" && \
	  tar -xzf "$(TOOLS)/bats.tgz" -C "$(TOOLS)" && mv "$(TOOLS)/bats-core-$(BATS_VERSION)" "$(TOOLS)/bats-core" && rm "$(TOOLS)/bats.tgz"; }
	@test -x "$(BATS)" || { echo "ERROR: bats failed to install"; exit 1; }
	@command -v shellcheck >/dev/null 2>&1 || echo "NOTE: shellcheck not found (pacman -S shellcheck)."
	@command -v shfmt >/dev/null 2>&1 || echo "NOTE: shfmt not found (pacman -S shfmt)."

lint:
	@echo "== shellcheck =="
	@if [ -n "$(SHELLCHECK)" ]; then \
	  $(SHELLCHECK) -x -e SC2016 -e SC2015 $(FILES); \
	else echo "shellcheck not installed; run: make setup-test"; fi
	@echo "== shfmt =="
	@if command -v shfmt >/dev/null 2>&1; then shfmt -l $(SHFMT_FILES) | test -z "$$(cat)" && echo "shfmt clean" || shfmt -d $(SHFMT_FILES); else echo "shfmt not installed; run: make setup-test"; fi
	@echo "== bash -n =="
	@$(foreach f,$(FILES),bash -n $(f) || exit 1;)
	@echo "lint clean: $(words $(FILES)) files checked"

fmt:
	@if command -v shfmt >/dev/null 2>&1; then shfmt -w . ; else echo "shfmt not installed; run: make setup-test"; fi

test: setup-test
	$(BATS) test/

verify:
	bash scripts/verify/verify-session.sh --repo

test-matrix:
	bash scripts/test/docker-smoke.sh

# --- release artifacts -------------------------------------------------------
tarball:
	@test -d .git || (echo "not a git repo"; exit 1)
	@[ "$$(git rev-parse --abbrev-ref HEAD)" = "master" ] || (echo "release from master only"; exit 1)
	mkdir -p dist
	git archive --format=tar.gz --output="dist/voyager-config-$$(git describe --tags --always).tar.gz" HEAD
	@echo "built dist/voyager-config-$$(git describe --tags --always).tar.gz"

sha256: tarball
	cd dist && sha256sum voyager-config-*.tar.gz > sha256sum.txt
	@echo "sha256sum.txt written:"
	@cat dist/sha256sum.txt

clean:
	rm -rf "$(TOOLS)" dist

ci: lint test verify