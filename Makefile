# Release path for https://vadneyk.github.io/ (the host root). `make ship` is the only way to release.
# This site's robots.txt is the one crawlers read for every vadneyk.github.io project site, so a
# mistake here reaches all of them; tests/check_site.py guards it.
# make check : file checks, plus every sitemap it names answers 200 on the live sites
# make ship  : check, then squash-merge this branch's open PR, wait for the Pages deploy run of that commit
#              to finish, check the live root files, and revert the merge if the deploy failed or the
#              smoke test fails.
# Lessons from 2026-11-18:
#  - The PR number is fixed when make starts (:=), so switching branches while a ship runs cannot make it
#    merge a different PR.
#  - A deploy that is only queued (the account's Actions queue was full) is not a failure: ship waits for
#    the run itself, up to 60 minutes, and stops without reverting if it never finished.
#  - The revert push uses the VadneyK token, like the merge.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
REPO    := VadneyK/vadneyk.github.io
LIVE    := https://vadneyk.github.io/
GHTOKEN  = $${GH_TOKEN:-$$(gh auth token -u VadneyK)}
BRANCH  := $(shell git rev-parse --abbrev-ref HEAD)
PR      := $(shell GH_TOKEN=$$(gh auth token -u VadneyK 2>/dev/null) gh pr list --repo $(REPO) --head "$(BRANCH)" --json number -q ".[0].number" 2>/dev/null)

.PHONY: check ship
check:
	python3 tests/check_site.py --live

ship: check
	@[ -n "$(PR)" ] || { echo "No open PR for branch $(BRANCH). Push and open one first."; exit 1; }
	@[ "$$(git rev-parse --abbrev-ref HEAD)" = "$(BRANCH)" ] || { echo "The branch changed while make ran. Run make ship again."; exit 1; }
	@[ -z "$$(git status --porcelain)" ] || { echo "Commit your changes first."; exit 1; }
	@git fetch -q origin && [ "$$(git rev-parse HEAD)" = "$$(git rev-parse @{u})" ] || { echo "Push the branch first: the PR must match what was tested."; exit 1; }
	GH_TOKEN=$(GHTOKEN) gh pr merge $(PR) --repo $(REPO) --squash --delete-branch
	git fetch -q origin main
	sha=$$(git rev-parse origin/main); echo "PR $(PR) merged as $$sha; waiting for its Pages deploy run"; \
	st=""; for i in $$(seq 1 360); do \
	  st=$$(GH_TOKEN=$(GHTOKEN) gh run list --repo $(REPO) --workflow pages.yml --commit $$sha --event push --json status,conclusion --jq '.[0] | .status + " " + (.conclusion // "")' 2>/dev/null || true); \
	  case "$$st" in "completed "*) break;; esac; sleep 10; \
	done; echo "deploy run: $${st:-not found}"; \
	case "$$st" in "completed "*) ;; *) echo "DEPLOY NOT FINISHED after 60 minutes (queued, not failed): not reverting. Check the Actions queue, then run the smoke test with: python3 tests/check_site.py --live --live-root"; exit 1;; esac; \
	for i in $$(seq 1 30); do [ "$$(curl -sf "$(LIVE)version.txt?n=$$i" | tr -d '[:space:]')" = "$$sha" ] && break; sleep 10; done; \
	if [ "$$st" = "completed success" ] && \
	   [ "$$(curl -sf "$(LIVE)version.txt?n=final" | tr -d '[:space:]')" = "$$sha" ] && \
	   curl -sf "$(LIVE)robots.txt" | grep -qx 'Allow: /' && \
	   curl -sf "$(LIVE)" | grep -q 'url=https://vadneyk.github.io/portfolio/' && \
	   python3 tests/check_site.py --live --live-root; then \
	  echo "SHIPPED: $(LIVE) serves $$sha and passes the smoke test"; \
	else \
	  echo "DEPLOY OR SMOKE TEST FAILED: reverting $$sha on main"; \
	  git checkout -q --detach "$$sha" && git revert --no-edit "$$sha" && \
	  git push "https://VadneyK:$(GHTOKEN)@github.com/$(REPO).git" HEAD:main 2>&1 | sed -E 's/gh[op]_[A-Za-z0-9]+/***/g'; \
	  git checkout -q "$(BRANCH)" 2>/dev/null || true; exit 1; \
	fi
