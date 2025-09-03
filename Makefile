SHELL := /usr/bin/env bash
PGURL ?= $(SUPABASE_DB_URL)
SCHEMAS ?= public
DUMPS_DIR := infra/dumps
DOCS_DIR  := infra/docs
SPY_DIR   := $(DOCS_DIR)/schemaspy

DB_HOST ?= $(SUPABASE_DB_HOST)
DB_NAME ?= $(SUPABASE_DB_NAME)
DB_USER ?= $(SUPABASE_DB_USER)
DB_PASS ?= $(SUPABASE_DB_PASSWORD)

SB_REF ?= $(SB_PROJECT_REF)

.DEFAULT_GOAL := report

dump-schema:
	@mkdir -p $(DUMPS_DIR)
	npx -y supabase db dump --db-url "$(PGURL)" -f "$(DUMPS_DIR)/schema.sql"

dump-roles:
	npx -y supabase db dump --db-url "$(PGURL)" -f "$(DUMPS_DIR)/roles.sql" --role-only

dump-data:
	npx -y supabase db dump --db-url "$(PGURL)" -f "$(DUMPS_DIR)/data.sql" --data-only --use-copy

inventory:
	./scripts/inventory.sh

schemaspy:
	@mkdir -p "$(SPY_DIR)"
	docker run --rm -v "$$(pwd)/$(SPY_DIR):/output" schemaspy/schemaspy:latest \
	  -t pgsql -host "$(DB_HOST)" -port 5432 -db "$(DB_NAME)" -u "$(DB_USER)" -p "$(DB_PASS)" \
	  -s public -o /output -connprops sslmode=require

erd:
	atlas schema inspect --url "postgres://$(DB_USER):$(DB_PASS)@$(DB_HOST):5432/$(DB_NAME)?search_path=$(SCHEMAS)&sslmode=require" \
	  --format '{{ mermaid . }}' > "$(DOCS_DIR)/erd.mmd"

functions:
	funcs=$$(npx -y supabase functions list --project-ref "$${SB_REF}" --output json | jq -r '.[].name'); \
	for f in $$funcs; do \
		echo "Downloading $$f"; \
		npx -y supabase functions download "$$f" --project-ref "$${SB_REF}" --path supabase/functions/"$$f" --overwrite; \
	done

report: dump-schema inventory schemaspy erd functions
	@echo "Report generated under infra/* and supabase/functions/*"
