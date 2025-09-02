SHELL := /usr/bin/env bash

# Inputs (set via env vars locally, or GitHub Actions secrets in CI)
PGURL ?= $(SUPABASE_DB_URL)
SCHEMAS ?= public

# Output folders
DUMPS_DIR := infra/dumps
DOCS_DIR  := infra/docs
SPY_DIR   := $(DOCS_DIR)/schemaspy

# For SchemaSpy (optional)
DB_HOST ?= $(SUPABASE_DB_HOST)
DB_NAME ?= $(SUPABASE_DB_NAME)
DB_USER ?= $(SUPABASE_DB_USER)
DB_PASS ?= $(SUPABASE_DB_PASSWORD)

# For Edge Functions (optional)
SB_REF ?= $(SB_PROJECT_REF)

.DEFAULT_GOAL := report

## 1) Dump schema (no data)
dump-schema:
	@mkdir -p $(DUMPS_DIR)
	npx -y supabase db dump --db-url "$(PGURL)" -f "$(DUMPS_DIR)/schema.sql"

## (Optional) dump roles and data
dump-roles:
	npx -y supabase db dump --db-url "$(PGURL)" -f "$(DUMPS_DIR)/roles.sql" --role-only
dump-data:
	npx -y supabase db dump --db-url "$(PGURL)" -f "$(DUMPS_DIR)/data.sql" --data-only --use-copy

## 2) Inventory CSVs
inventory:
	./scripts/inventory.sh

## 3) Docs: SchemaSpy HTML (requires Docker) — OPTIONAL
schemaspy:
	@mkdir -p "$(SPY_DIR)"
	docker run --rm -v "$$(pwd)/$(SPY_DIR):/output" schemaspy/schemaspy:latest \
	  -t pgsql -host "$(DB_HOST)" -port 5432 -db "$(DB_NAME)" -u "$(DB_USER)" -p "$(DB_PASS)" \
	  -s public -o /output -connprops sslmode=require

## 3b) Atlas ERD as Mermaid (requires atlas) — OPTIONAL
erd:
	atlas schema inspect --url "postgres://$(DB_USER):$(DB_PASS)@$(DB_HOST):5432/$(DB_NAME)?search_path=$(SCHEMAS)&sslmode=require" \
	  --format '{{ mermaid . }}' > "$(DOCS_DIR)/erd.mmd"

## 4) Edge Functions (requires SUPABASE_ACCESS_TOKEN + SB_PROJECT_REF) — OPTIONAL
functions:
	funcs=$$(npx -y supabase functions list --project-ref "$${SB_REF}" --output json | jq -r '.[].name'); \
	for f in $$funcs; do \
		echo "Downloading $$f"; \
		npx -y supabase functions download "$$f" --project-ref "$${SB_REF}" --path supabase/functions/"$$f" --overwrite; \
	done

## All-in-one (fast path used by CI)
report: dump-schema inventory
	@echo "Report generated under infra/*"
	@echo "Tip: 'make schemaspy erd functions' for optional extras locally."
