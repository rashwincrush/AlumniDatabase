#!/usr/bin/env bash
set -euo pipefail

# Wrapper for psql to run inventory queries against the DB
#
# Usage:
#   SUPABASE_DB_URL=... ./inventory.sh
#
# It reads the DB connection URL from the SUPABASE_DB_URL env var.
#
# It creates CSV files in infra/inventory/

if [ -z "${SUPABASE_DB_URL}" ]; then
  echo "Error: SUPABASE_DB_URL is not set." >&2
  exit 1
fi

OUT_DIR="infra/inventory"
mkdir -p "$OUT_DIR"

run_sql() {
  local sql="$1"
  local outfile="$2"
  echo "Running inventory query: $outfile" >&2
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --quiet --csv -A -c "$sql" > "$OUT_DIR/$outfile"
}

run_sql "select table_schema,table_name,table_type from information_schema.tables where table_schema not in ('pg_catalog','information_schema') order by 1,2" tables.csv
run_sql "select schemaname,relname,n_live_tup from pg_stat_all_tables where schemaname not in ('pg_catalog','information_schema') order by n_live_tup desc" rowcounts.csv
run_sql "select schemaname,tablename,policyname,cmd,roles,qual,with_check from pg_policies order by schemaname,tablename,policyname" policies.csv
run_sql "select n.nspname as schema, c.relname as table, c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema') order by 1,2" rls_enabled_tables.csv
run_sql "select n.nspname as schema, c.relname as table, t.tgname as trigger, p.proname as function from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal order by 1,2,3" triggers.csv
run_sql "select n.nspname as schema, p.proname as name, pg_get_function_result(p.oid) as returns, pg_get_function_arguments(p.oid) as args, l.lanname as lang from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname not in ('pg_catalog','information_schema') order by 1,2" functions.csv
run_sql "select e.extname, n.nspname as schema, e.extversion from pg_extension e join pg_namespace n on n.oid=e.extnamespace order by 1" extensions.csv
run_sql "select pubname, schemaname, tablename from pg_publication_tables order by pubname, schemaname, tablename" publications_tables.csv
run_sql "select n.nspname as schema, c.relname as table, c.relreplident as repl_identity from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema') order by 1,2" replication_identity.csv
run_sql "select table_schema,table_name,grantee,privilege_type from information_schema.table_privileges where table_schema not in ('pg_catalog','information_schema') order by 1,2,3" grants.csv

echo "Inventory CSVs written to $OUT_DIR/"
