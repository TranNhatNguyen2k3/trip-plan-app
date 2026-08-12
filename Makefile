# TripMate — common dev commands
# Usage: make help

.PHONY: help setup get run analyze test check clean \
	migrate migrate-cat seed-dev-user seed supabase-push supabase-link

SHELL := /bin/bash
ROOT := $(CURDIR)
MIGRATIONS := $(ROOT)/supabase/migrations
DEVICE ?=

.DEFAULT_GOAL := help

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Copy .env.example → .env (edit Supabase URL + anon key)
	@if [[ -f .env ]]; then echo ".env already exists — skipped"; else cp .env.example .env && echo "Created .env — fill SUPABASE_URL and SUPABASE_ANON_KEY"; fi

get: ## flutter pub get
	flutter pub get

run: get ## Run app (optional: make run DEVICE=chrome)
ifdef DEVICE
	flutter run -d $(DEVICE)
else
	flutter run
endif

analyze: ## flutter analyze
	flutter analyze

test: ## flutter test
	flutter test

check: analyze test ## analyze + test

clean: ## flutter clean + pub get
	flutter clean
	flutter pub get

# --- Supabase (remote Postgres) ---
# Export session/direct URI from Dashboard → Settings → Database:
#   export DATABASE_URL='postgresql://postgres.[ref]:[PASSWORD]@...:5432/postgres'

migrate: ## Apply all SQL migrations (requires DATABASE_URL)
	@if [[ -z "$$DATABASE_URL" ]]; then echo "Set DATABASE_URL first (see make help)"; exit 1; fi
	@set -euo pipefail; \
	for f in $(MIGRATIONS)/*.sql; do \
	  echo ">>> $$f"; \
	  psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$$f"; \
	done
	@echo "Migrations done."

migrate-cat: ## Same as migrate but single psql pipe (requires DATABASE_URL)
	@if [[ -z "$$DATABASE_URL" ]]; then echo "Set DATABASE_URL first"; exit 1; fi
	cat $(MIGRATIONS)/*.sql | psql "$$DATABASE_URL" -v ON_ERROR_STOP=1
	@echo "Migrations done."

seed-dev-user: ## Create demo@tripmate.dev (requires DATABASE_URL)
	@if [[ -z "$$DATABASE_URL" ]]; then echo "Set DATABASE_URL first"; exit 1; fi
	psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed_dev_user.sql

seed: ## Demo trip seed (requires DATABASE_URL; run seed-dev-user if auth.users empty)
	@if [[ -z "$$DATABASE_URL" ]]; then echo "Set DATABASE_URL first"; exit 1; fi
	psql "$$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed.sql

# --- Supabase CLI (optional: brew install supabase/tap/supabase) ---

supabase-link: ## Link project (make supabase-link REF=your_project_ref)
	@if [[ -z "$(REF)" ]]; then echo "Usage: make supabase-link REF=abcdefghijklmnop"; exit 1; fi
	supabase link --project-ref $(REF)

supabase-push: ## Push migrations via Supabase CLI (after supabase link)
	supabase db push
