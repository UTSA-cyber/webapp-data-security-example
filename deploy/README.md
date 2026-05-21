# Deployment artifacts

Everything needed to run the project outside of `npx supabase start` lives here.
Two deployment targets are supported:

1. **Local Docker Compose** — for production-shaped local testing, including the SSO flow.
2. **Nomad + Vault** — for a real cluster deployment with secrets management.

## Files

```
deploy/
├── docker-compose.yml         # Full stack: db, auth, migrator, rest, app, authentik
├── Dockerfile.app             # Multi-stage Vite build → nginx static serve
├── nginx.conf                 # SPA fallback + /auth/v1 and /rest/v1 proxies
├── postgres-init.sh           # Bootstraps auth schema, supabase roles, default grants
├── migrator-entrypoint.sh     # One-shot: applies migrations + seed after GoTrue
├── .env.example               # Required env vars (copy to .env, fill in)
├── authentik/
│   └── blueprints/
│       └── webapp-oidc-provider.yaml   # Auto-creates the OIDC client on Authentik boot
├── nomad/
│   ├── supabase.nomad.hcl     # db + auth + migrator + rest groups
│   ├── app.nomad.hcl          # The web app
│   └── authentik.nomad.hcl    # Authentik + its own db + redis
└── vault/
    ├── README.md              # KV layout, policy bootstrap, Nomad ↔ Vault wiring
    └── policies/
        ├── webapp-supabase.hcl
        └── webapp-authentik.hcl
```

## Local Docker Compose

```sh
cd deploy
cp .env.example .env             # the defaults work for local dev as-is
docker compose up -d --build
```

After every container reports healthy:

| Service | URL |
|---|---|
| App | http://localhost:3000 |
| Authentik | http://localhost:9000 |

Sign in to the app with any seeded demo account (see [project README](../CLAUDE.md)
for the topology) using password `Demo123!password`.

To exercise the SSO flow:

1. Visit http://localhost:9000 and sign in as the Authentik admin
   (`AUTHENTIK_BOOTSTRAP_EMAIL` / `AUTHENTIK_BOOTSTRAP_PASSWORD` from `.env`).
2. Confirm the auto-created OIDC application "Data Security Example" is present
   (created by `authentik/blueprints/webapp-oidc-provider.yaml`).
3. Copy the client secret from the application detail page and set it as
   `GOTRUE_EXTERNAL_KEYCLOAK_SECRET` in `.env`, then `docker compose up -d auth`
   to pick up the new value.
4. From the app's login page, click "Sign in with SSO (Authentik)."

### Bringing it down

```sh
docker compose down -v   # -v drops volumes; omit to keep db state between runs
```

### Coexistence with `npx supabase start`

The Supabase CLI dev stack uses ports 54321–54324. This compose uses 3000 and
9000. The two stacks can run side by side, but you'll point the **frontend**
at one or the other via `VITE_SUPABASE_URL` in `frontend/.env.local`.

## Nomad + Vault deployment

This path is **scaffolding** — the jobspecs and policies are in place, but
running them requires:

1. A Nomad cluster (≥ 1.7 for native workload identity to Vault).
2. A Vault server with KV v2 enabled at `secret/`.
3. The two host volumes declared on at least one Nomad client:
   - `postgres-data`
   - `authentik-db-data`
4. An image registry that hosts the built app image; update the `image`
   field in `nomad/app.nomad.hcl` accordingly.

### Order of operations

```sh
# 1. Vault setup
cd deploy/vault
vault policy write webapp-supabase  policies/webapp-supabase.hcl
vault policy write webapp-authentik policies/webapp-authentik.hcl
# Then populate the four KV paths — see deploy/vault/README.md for the
# exact fields and example openssl-generated values.

# 2. Configure Nomad-to-Vault workload identity binding (one time, per cluster)
# See deploy/vault/README.md "Nomad ↔ Vault integration" section.

# 3. Build and push the app image (CI does this in practice)
docker build -f deploy/Dockerfile.app \
  --build-arg VITE_SUPABASE_URL=https://webapp.example.com \
  --build-arg VITE_SUPABASE_PUBLISHABLE_KEY=<your-anon-jwt> \
  -t ghcr.io/your-org/webapp-data-security:latest .
docker push ghcr.io/your-org/webapp-data-security:latest

# 4. Submit the jobs (order matters for first deploy: data first)
nomad job run deploy/nomad/supabase.nomad.hcl
nomad job run deploy/nomad/authentik.nomad.hcl
nomad job run deploy/nomad/app.nomad.hcl
```

The `supabase.nomad.hcl` job uses `artifact {}` blocks to pull migrations from
a Git URL. **Update those URLs** to point at your repo before applying. For
production, prefer baking migrations into an immutable migrator image and
referencing that image instead of an artifact.

### What's not handled here

- **TLS termination.** All examples assume an upstream load balancer
  (Traefik, Caddy, etc.) handles TLS and forwards plaintext to Nomad.
- **Backup / restore.** The host volumes for Postgres data have no backup
  story in this repo. Use whatever's appropriate for your environment
  (pg_dump cronjob, volume snapshots, etc.).
- **Centralized logging.** Containers log to stdout; gather from there.

## Security notes

- The committed `.env.example` includes **Supabase's published demo JWTs**.
  These are safe for local development — `JWT_SECRET` is well-known — but
  **must be regenerated** for any shared deployment. The `vault/README.md`
  documents how.
- `admin_row_count` (in `supabase/migrations/20260520120100_helpers.sql`) is
  a teaching-only RPC that returns un-RLS-filtered row totals to any
  authenticated user. **Remove it or scope it per-organization before any
  real deployment** — it's an information leak in production.
- The `enforce_classroom_org_integrity` trigger is `SECURITY DEFINER`. If
  you fork the schema, audit this trigger for assumptions about caller
  privilege.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `db` healthy but `auth` exits with `API_EXTERNAL_URL missing` | `.env` missing or `SITE_URL` unset |
| `migrator` fails with `relation "auth.users" does not exist` | `auth` healthcheck passed too early; GoTrue's migrations not done. Re-run; or increase `start_period` on auth's healthcheck. |
| PostgREST returns `permission denied for table X` | Default privileges weren't applied before migrations ran. Check `postgres-init.sh` was executed (volume mount + executable bit). |
| SSO flow lands on `Bad gateway` | GoTrue and Authentik can't reach each other. Verify both have started and that `GOTRUE_EXTERNAL_KEYCLOAK_URL` points at the Authentik service hostname inside the Docker network (not `localhost`). |
