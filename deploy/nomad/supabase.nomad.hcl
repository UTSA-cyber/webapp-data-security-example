# Nomad job: Postgres + GoTrue + Migrator + PostgREST
# ============================================================================
# Mirrors deploy/docker-compose.yml's core Supabase services. Each group is
# an independent allocation with its own restart policy.
#
# Prerequisites in the cluster:
#   - Vault integrated with Nomad via workload identity (no token files)
#   - A `postgres-data` host volume defined on at least one Nomad client
#   - Vault KV v2 paths populated (see deploy/vault/policies/ for layout)
#   - The `app` job (separate file) provides the public ingress that
#     proxies /auth/v1 and /rest/v1 to GoTrue and PostgREST respectively
#
# Service discovery uses Nomad's native provider — no Consul required.

job "supabase" {
  type = "service"

  group "db" {
    count = 1

    network {
      mode = "bridge"
      port "pg" {
        to = 5432
      }
    }

    volume "postgres-data" {
      type      = "host"
      source    = "postgres-data"
      read_only = false
    }

    service {
      name     = "supabase-db"
      provider = "nomad"
      port     = "pg"
      check {
        type     = "script"
        task     = "postgres"
        command  = "pg_isready"
        args     = ["-U", "postgres", "-d", "postgres"]
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "postgres" {
      driver = "docker"

      vault {
        policies = ["webapp-supabase"]
      }

      config {
        image = "postgres:16-alpine"
        ports = ["pg"]
        volumes = [
          "local/postgres-init.sh:/docker-entrypoint-initdb.d/01_init.sh:ro",
        ]
      }

      volume_mount {
        volume      = "postgres-data"
        destination = "/var/lib/postgresql/data"
      }

      # Bootstrap script — kept inline so the job is self-contained.
      template {
        destination = "local/postgres-init.sh"
        perms       = "0755"
        data        = <<EOF
#!/bin/bash
set -euo pipefail
psql -v ON_ERROR_STOP=1 -U postgres -d postgres <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon')            then create role anon noinherit nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated')   then create role authenticated noinherit nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role')    then create role service_role noinherit nologin bypassrls; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticator')   then create role authenticator noinherit login password 'CHANGE_ME_AUTHENTICATOR'; end if;
  grant anon, authenticated, service_role to authenticator;
end $$;
grant usage on schema auth, public to anon, authenticated, service_role;
alter default privileges in schema public grant select on tables to anon, authenticated;
alter default privileges in schema public grant insert, update, delete on tables to authenticated;
alter default privileges in schema public grant usage, select on sequences to anon, authenticated;
alter default privileges in schema public grant execute on functions to anon, authenticated;
create or replace function auth.uid()  returns uuid  language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $$;
create or replace function auth.jwt()  returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim', true), ''), nullif(current_setting('request.jwt.claims', true), ''))::jsonb $$;
create or replace function auth.role() returns text  language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'))::text $$;
grant execute on function auth.uid(), auth.jwt(), auth.role() to anon, authenticated, service_role;
SQL
EOF
      }

      template {
        destination = "secrets/db.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/postgres" }}
POSTGRES_PASSWORD = "{{ .Data.data.password }}"
{{ end }}
POSTGRES_DB = "postgres"
EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }

  group "auth" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 9999
      }
    }

    service {
      name     = "supabase-auth"
      provider = "nomad"
      port     = "http"
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "gotrue" {
      driver = "docker"

      vault {
        policies = ["webapp-supabase"]
      }

      config {
        image = "supabase/gotrue:v2.181.0"
        ports = ["http"]
      }

      template {
        destination = "secrets/auth.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/postgres" -}}
{{ with secret "secret/data/webapp/jwt" -}}
{{ with secret "secret/data/webapp/authentik-oidc" }}
API_EXTERNAL_URL                       = "{{ env "NOMAD_META_site_url" }}/auth/v1"
GOTRUE_API_HOST                        = "0.0.0.0"
GOTRUE_API_PORT                        = "9999"
GOTRUE_DB_DRIVER                       = "postgres"
GOTRUE_DB_DATABASE_URL                 = "postgres://postgres:{{ (with secret "secret/data/webapp/postgres").Data.data.password }}@{{ range nomadService "supabase-db" }}{{ .Address }}:{{ .Port }}{{ end }}/postgres?search_path=auth"
GOTRUE_SITE_URL                        = "{{ env "NOMAD_META_site_url" }}"
GOTRUE_URI_ALLOW_LIST                  = "{{ env "NOMAD_META_site_url" }}"
GOTRUE_JWT_SECRET                      = "{{ .Data.data.jwt_secret }}"
GOTRUE_JWT_EXP                         = "3600"
GOTRUE_JWT_DEFAULT_GROUP_NAME          = "authenticated"
GOTRUE_JWT_ADMIN_ROLES                 = "service_role"
GOTRUE_JWT_AUD                         = "authenticated"
GOTRUE_EXTERNAL_KEYCLOAK_ENABLED       = "true"
GOTRUE_EXTERNAL_KEYCLOAK_CLIENT_ID     = "{{ .Data.data.client_id }}"
GOTRUE_EXTERNAL_KEYCLOAK_SECRET        = "{{ .Data.data.client_secret }}"
GOTRUE_EXTERNAL_KEYCLOAK_REDIRECT_URI  = "{{ env "NOMAD_META_site_url" }}/auth/v1/callback"
GOTRUE_EXTERNAL_KEYCLOAK_URL           = "{{ env "NOMAD_META_authentik_oidc_url" }}"
{{ end }}{{ end }}{{ end }}
EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # Migrator: one-shot task that runs after GoTrue is healthy. Restarts only
  # if it fails — successful exits don't trigger reruns.
  group "migrator" {
    count = 1

    restart {
      attempts = 0
      mode     = "fail"
    }

    task "apply-migrations" {
      driver = "docker"
      kill_timeout = "30s"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      vault {
        policies = ["webapp-supabase"]
      }

      config {
        image      = "postgres:16-alpine"
        entrypoint = ["/bin/sh", "/local/run.sh"]
        # Migrations + seed need to be supplied via artifact, host volume,
        # or baked into a custom image. For a real deploy, prefer baking
        # them into an immutable image (e.g. ghcr.io/yourorg/webapp-migrations:<sha>).
        # The artifact-based approach below is fine for a teaching demo.
      }

      artifact {
        source      = "git::https://example.com/your-org/webapp-data-security-example//supabase/migrations"
        destination = "local/migrations"
      }

      artifact {
        source      = "git::https://example.com/your-org/webapp-data-security-example//supabase/seed.sql"
        destination = "local/seed.sql"
        mode        = "file"
      }

      template {
        destination = "local/run.sh"
        perms       = "0755"
        data        = <<EOF
#!/bin/sh
set -e
export PGHOST="{{ range nomadService "supabase-db" }}{{ .Address }}{{ end }}"
export PGPORT="{{ range nomadService "supabase-db" }}{{ .Port }}{{ end }}"
export PGUSER=postgres
export PGDATABASE=postgres
echo "Applying migrations…"
for f in $(ls /local/migrations/*.sql | sort); do
  echo "  - $(basename "$f")"
  psql -v ON_ERROR_STOP=1 -f "$f"
done
if [ -f /local/seed.sql ]; then
  echo "Applying seed…"
  psql -v ON_ERROR_STOP=1 -f /local/seed.sql
fi
EOF
      }

      template {
        destination = "secrets/migrator.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/postgres" }}
PGPASSWORD = "{{ .Data.data.password }}"
{{ end }}
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  group "rest" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 3000
      }
    }

    service {
      name     = "supabase-rest"
      provider = "nomad"
      port     = "http"
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "postgrest" {
      driver = "docker"

      vault {
        policies = ["webapp-supabase"]
      }

      config {
        image = "postgrest/postgrest:v12.2.3"
        ports = ["http"]
      }

      template {
        destination = "secrets/rest.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/jwt" }}
PGRST_DB_URI            = "postgres://authenticator:CHANGE_ME_AUTHENTICATOR@{{ range nomadService "supabase-db" }}{{ .Address }}:{{ .Port }}{{ end }}/postgres"
PGRST_DB_SCHEMAS        = "public"
PGRST_DB_ANON_ROLE      = "anon"
PGRST_JWT_SECRET        = "{{ .Data.data.jwt_secret }}"
PGRST_DB_USE_LEGACY_GUCS = "false"
{{ end }}
EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  meta {
    site_url           = "https://webapp.example.com"
    authentik_oidc_url = "https://auth.example.com/application/o/webapp/"
  }
}
