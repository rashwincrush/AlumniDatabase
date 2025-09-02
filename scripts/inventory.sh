#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL not set}"

# Ensure psql exists
if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. On macOS: brew install libpq && echo 'export PATH=\"/opt/homebrew/opt/libpq/bin:$PATH\"' >> ~/.zshrc && source ~/.zshrc"
  exit 1
fi

OUT_DIR="infra/inventory"
mkdir -p "$OUT_DIR"

run_psql() {
  command psql "$SUPABASE_DB_URL" -At -F, -v "ON_ERROR_STOP=1" -c "$1"
}

# Tables & views (non-system)
run_psql "
select table_schema,table_name,table_type
from information_schema.tables
where table_schema not in ('pg_catalog','information_schema')
order by 1,2
" > "$OUT_DIR/tables.csv"

# Approx rowcounts
run_psql "
select schemaname,relname,n_live_tup
from pg_stat_all_tables
where schemaname not in ('pg_catalog','information_schema')
order by n_live_tup desc
" > "$OUT_DIR/rowcounts.csv"

# RLS policies
run_psql "
select schemaname,tablename,policyname,cmd,roles,qual,with_check
from pg_policies
order by schemaname,tablename,policyname
" > "$OUT_DIR/policies.csv"

# RLS enabled tables
run_psql "
select n.nspname as schema, c.relname as table, c.relrowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema')
order by 1,2
" > "$OUT_DIR/rls_enabled_tables.csv"

# Triggers
run_psql "
select n.nspname as schema, c.relname as table, t.tgname as trigger, p.proname as function
from pg_trigger t
join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
join pg_proc p on p.oid=t.tgfoid
where not t.tgisinternal
order by 1,2,3
" > "$OUT_DIR/triggers.csv"

# Functions
run_psql "
select n.nspname as schema, p.proname as name,
pg_get_function_result(p.oid) as returns, pg_get_function_arguments(p.oid) as args, l.lanname as lang
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
join pg_language l on l.oid=p.prolang
where n.nspname not in ('pg_catalog','information_schema')
order by 1,2
" > "$OUT_DIR/functions.csv"

# Extensions
run_psql "
select e.extname, n.nspname as schema, e.extversion
from pg_extension e join pg_namespace n on n.oid=e.extnamespace
order by 1
" > "$OUT_DIR/extensions.csv"

# Realtime publications → tables
run_psql "
select pubname, schemaname, tablename
from pg_publication_tables
order by pubname, schemaname, tablename
" > "$OUT_DIR/publications_tables.csv"

# Replication identity (important for Realtime updates)
run_psql "
select n.nspname as schema, c.relname as table, c.relreplident as repl_identity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema')
order by 1,2
" > "$OUT_DIR/replication_identity.csv"

# Grants
run_psql "
select table_schema,table_name,grantee,privilege_type
from information_schema.table_privileges
where table_schema not in ('pg_catalog','information_schema')
order by 1,2,3
" > "$OUT_DIR/grants.csv"

echo "Inventory CSVs written to $OUT_DIR/"
