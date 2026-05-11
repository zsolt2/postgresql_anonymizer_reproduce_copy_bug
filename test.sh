#!/usr/bin/env bash
#set -euo pipefail
export PGHOST=localhost
export PGDATABASE=test_db
export PSQL_PAGER=cat
export PAGER=cat

echo "== versions =="
psql -U postgres -d test_db -c 'SELECT version();'
psql -U postgres -d test_db -c 'SELECT anon.version();'

# Each entry is a SQL-quoted column identifier. Embedded double quotes are
# doubled per SQL identifier-quoting rules; the bash single-quoted strings
# below pass the literal quoted identifier through to psql.
COLUMNS=(
  '"Example Column"'
  '"col""with""quotes"'
  '"123abc"'
  '"col with  multiple   spaces"'
  '" leading_space"'
  '"trailing_space "'
)

run_case() {
  local label="$1" user="$2" pw="$3" col="$4"
  echo
  echo "== ${label}: COPY ${col} =="
  PGPASSWORD="$pw" psql -U "$user" -v ON_ERROR_STOP=1 \
    -c "COPY test_schema.test_table (${col}) TO stdout;"
}

for col in "${COLUMNS[@]}"; do
  run_case "table_owner" table_owner owner "$col"
done

for col in "${COLUMNS[@]}"; do
  echo
  echo "== anon_user: SELECT ${col} =="
  PGPASSWORD=anon psql -U anon_user -v ON_ERROR_STOP=1 \
    -c "SELECT ${col} FROM test_schema.test_table;"
done

for col in "${COLUMNS[@]}"; do
  run_case "anon_user" anon_user anon "$col"
done

echo
echo "== anon_user: pg_dump table =="
PGPASSWORD=anon pg_dump -U anon_user -d test_db -t 'test_schema.test_table' --data-only
