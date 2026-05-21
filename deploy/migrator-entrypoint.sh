#!/bin/sh
# Apply our migrations + seed AFTER GoTrue has bootstrapped its own auth
# schema. Run as a one-shot container; rest/app depend on this completing
# successfully (compose `service_completed_successfully` condition).
#
# The depends_on chain ensures auth (GoTrue) is healthy before we run,
# so auth.users exists at this point and public.users.id REFERENCES
# auth.users(id) resolves cleanly.

set -e

export PGHOST="${PGHOST:-db}"
export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"
export PGPASSWORD="${PGPASSWORD:?PGPASSWORD must be set}"

echo "Migrator: applying project migrations…"
for f in $(ls /migrations/*.sql | sort); do
  echo "  - $(basename "$f")"
  psql -v ON_ERROR_STOP=1 -f "$f"
done

if [ -f /seed.sql ]; then
  echo "Migrator: applying seed…"
  psql -v ON_ERROR_STOP=1 -f /seed.sql
else
  echo "Migrator: no seed file present, skipping."
fi

echo "Migrator: done."
