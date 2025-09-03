#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL not set}"
OUT_DIR="infra/inventory"
mkdir -p "$OUT_DIR"

psql() { command psql "$SUPABASE_DB_URL" -At -F, -v "ON_ERROR_STOP=1" -c "$1"; }

# Tables & views (non-system)
psql "select table_schema,table_name,table_type
from information_schema.tables
where table_schema not in ('pg_catalog','information_schema')
order by 1,2" > "$OUT_DIR/tables.csv"

# Approx rowcounts
psql "select schemaname,relname,n_live_tup
from pg_stat_all_tables
where schemaname not in ('pg_catalog','information_schema')
order by n_live_tup desc" > "$OUT_DIR/rowcounts.csv"

# RLS policies
psql "select schemaname,tablename,policyname,cmd,roles,qual,with_check
from pg_policies
order by schemaname,tablename,policyname" > "$OUT_DIR/policies.csv"

# RLS enabled tables
psql "select n.nspname as schema, c.relname as table, c.relrowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema')
order by 1,2" > "$OUT_DIR/rls_enabled_tables.csv"

# Triggers
psql "select n.nspname as schema, c.relname as table, t.tgname as trigger, p.proname as function
from pg_trigger t
join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
join pg_proc p on p.oid=t.tgfoid
where not t.tgisinternal
order by 1,2,3" > "$OUT_DIR/triggers.csv"

# Functions
psql "select n.nspname as schema, p.proname as name,
pg_get_function_result(p.oid) as returns, pg_get_function_arguments(p.oid) as args, l.lanname as lang
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
join pg_language l on l.oid=p.prolang
where n.nspname not in ('pg_catalog','information_schema')
order by 1,2" > "$OUT_DIR/functions.csv"

# Extensions
psql "select e.extname, n.nspname as schema, e.extversion
from pg_extension e join pg_namespace n on n.oid=e.extnamespace
order by 1" > "$OUT_DIR/extensions.csv"

# Realtime publications → tables
psql "select pubname, schemaname, tablename
from pg_publication_tables
order by pubname, schemaname, tablename" > "$OUT_DIR/publications_tables.csv"

# Replication identity
psql "select n.nspname as schema, c.relname as table, c.relreplident as repl_identity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema')
order by 1,2" > "$OUT_DIR/replication_identity.csv"

# Grants
psql "select table_schema,table_name,grantee,privilege_type
from information_schema.table_privileges
where table_schema not in ('pg_catalog','information_schema')
order by 1,2,3" > "$OUT_DIR/grants.csv"
