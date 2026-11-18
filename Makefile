# Release path for https://vadneyk.github.io/ (the host root). `make ship` is the only way to release.
# This site's robots.txt is the one crawlers read for every vadneyk.github.io project site, so a
# mistake here reaches all of them; tests/check_site.py guards it.
# make check : file checks, plus every sitemap it names answers 200 on the live sites
# make ship  : check, then squash-merge the open PR, wait for the Pages deploy of that commit,
#              check the live root files, and revert the merge if that fails. It waits up to 20 minutes
#              for the deploy, because the Actions queue can take more than 10 (2026-11-18).
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
REPO    := VadneyK/vadneyk.github.io
LIVE    := https://vadneyk.github.io/
GHTOKEN  = $${GH_TOKEN:-$$(gh auth token -u VadneyK)}
PR      ?= $(shell GH_TOKEN=$$(gh auth token -u VadneyK 2>/dev/null) gh pr list --repo $(REPO) --head "$$(git rev-parse --abbrev-ref HEAD)" --json number -q ".[0].number" 2>/dev/null)

.PHONY: check ship
check:
	python3 tests/check_site.py --live

ship: check
	@[ -n "$(PR)" ] || { echo "No open PR for this branch. Push and open one first."; exit 1; }
	@[ -z "$$(git status --porcelain)" ] || { echo "Commit your changes first."; exit 1; }
	@git fetch -q origin && [ "$$(git rev-parse HEAD)" = "$$(git rev-parse @{u})" ] || { echo "Push the branch first: the PR must match what was tested."; exit 1; }
	GH_TOKEN=$(GHTOKEN) gh pr merge $(PR) --repo $(REPO) --squash --delete-branch
	git fetch -q origin main
	sha=$$(git rev-parse origin/main); echo "waiting for Pages to serve $$sha"; \
	for i in $$(seq 1 120); do [ "$$(curl -sf "$(LIVE)version.txt?n=$$i" | tr -d '[:space:]')" = "$$sha" ] && break; sleep 10; done; \
	if [ "$$(curl -sf "$(LIVE)version.txt?n=final" | tr -d '[:space:]')" = "$$sha" ] && \
	   curl -sf "$(LIVE)robots.txt" | grep -qx 'Allow: /' && \
	   curl -sf "$(LIVE)" | grep -q 'url=https://vadneyk.github.io/portfolio/' && \
	   python3 tests/check_site.py --live --live-root; then \
	  echo "SHIPPED: $(LIVE) serves $$sha and passes the smoke test"; \
	else \
	  echo "SMOKE TEST FAILED: reverting $$sha on main"; \
	  git checkout -q --detach origin/main && git revert --no-edit "$$sha" && git push origin HEAD:main; exit 1; \
	fi
