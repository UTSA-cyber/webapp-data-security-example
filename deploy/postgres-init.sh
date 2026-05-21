#!/bin/bash
# Bootstrap script run on Postgres first boot via /docker-entrypoint-initdb.d.
#
# Responsibilities (the minimum the rest of the stack needs):
#   1. pgcrypto extension (used by seed.sql for crypt() / gen_salt())
#   2. The auth schema and the roles GoTrue + PostgREST expect
#   3. auth.uid(), auth.jwt(), auth.role() — Supabase-style helpers our RLS
#      policies and seed-generation rely on
#
# This script does NOT apply our migrations. Migrations FK to auth.users,
# which doesn't exist until GoTrue runs its own migrations on first boot.
# The deploy/migrator service handles app migrations + seed after GoTrue is
# ready (see docker-compose.yml).

set -euo pipefail

PGUSER="${POSTGRES_USER:-postgres}"
PGDB="${POSTGRES_DB:-postgres}"

psql -v ON_ERROR_STOP=1 -U "$PGUSER" -d "$PGDB" <<-'SQL'
  create extension if not exists pgcrypto;

  create schema if not exists auth;

  do $$ begin
    if not exists (select 1 from pg_roles where rolname = 'anon') then
      create role anon noinherit nologin;
    end if;
    if not exists (select 1 from pg_roles where rolname = 'authenticated') then
      create role authenticated noinherit nologin;
    end if;
    if not exists (select 1 from pg_roles where rolname = 'service_role') then
      create role service_role noinherit nologin bypassrls;
    end if;
    -- The role PostgREST connects as; it switches into anon/authenticated/
    -- service_role based on the JWT claim "role".
    if not exists (select 1 from pg_roles where rolname = 'authenticator') then
      create role authenticator noinherit login password 'CHANGE_ME_AUTHENTICATOR';
    end if;
    grant anon, authenticated, service_role to authenticator;
  end $$;

  grant usage on schema auth to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;

  -- Default privileges so anything the migrator (running as postgres) creates
  -- in public is reachable by PostgREST after role-switch. RLS still gates
  -- which rows each role sees — these grants only get the request past the
  -- table-level permission check so RLS can run.
  alter default privileges in schema public
    grant select on tables to anon, authenticated;
  alter default privileges in schema public
    grant insert, update, delete on tables to authenticated;
  alter default privileges in schema public
    grant usage, select on sequences to anon, authenticated;
  alter default privileges in schema public
    grant execute on functions to anon, authenticated;

  -- auth.uid() / auth.jwt() / auth.role() — Supabase publishes these in their
  -- self-hosting init; we redefine them here so RLS policies and helper
  -- functions work the same way they do under `supabase start`.
  create or replace function auth.uid()
  returns uuid
  language sql
  stable
  as $fn$
    select coalesce(
      nullif(current_setting('request.jwt.claim.sub', true), ''),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    )::uuid
  $fn$;

  create or replace function auth.jwt()
  returns jsonb
  language sql
  stable
  as $fn$
    select coalesce(
      nullif(current_setting('request.jwt.claim', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
  $fn$;

  create or replace function auth.role()
  returns text
  language sql
  stable
  as $fn$
    select coalesce(
      nullif(current_setting('request.jwt.claim.role', true), ''),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
    )::text
  $fn$;

  grant execute on function auth.uid()  to anon, authenticated, service_role;
  grant execute on function auth.jwt()  to anon, authenticated, service_role;
  grant execute on function auth.role() to anon, authenticated, service_role;
SQL

echo "Bootstrap complete. App migrations are applied by the 'migrator' service after GoTrue runs its own."
