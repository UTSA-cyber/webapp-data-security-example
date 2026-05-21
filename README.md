# webapp-data-security-example

An educational web application demonstrating **role-based data access enforced at the
database layer** via PostgreSQL row-level security, exposed through self-hosted Supabase.

The premise: a misbehaving frontend cannot read data the role isn't entitled to,
because authorization lives in the database — not in TypeScript. Every query the
React app makes is filtered by RLS before PostgREST hands the result back. The UI
does no filtering of its own.

## The lesson, in one screen

After signing in, the role switcher in the header swaps the user's active role
in place. The same React component, hitting the same Supabase endpoint, displays
different data because the JWT carries a different `active_role` claim.

The "invalid view" panes make the security boundary visible. When a student
tries to query `sites`, RLS silently returns `[]` — no error, just empty. The
pane shows the gap explicitly:

> You see **0** rows.
> An administrator sees **2** rows in `sites`.
> **2** rows were filtered out by Postgres row-level security.

That last number comes from a SECURITY DEFINER RPC (`public.admin_row_count`)
that bypasses RLS. Comparing it to the user's count makes the silent denial
*audible* — pedagogically the whole point.

## Architecture at a glance

```
┌──────────────┐    JWT (Authorization: Bearer …)
│ React + Vite │───────────────────────────────────────┐
│  (frontend/) │                                       │
└──────────────┘                                       ▼
       │                                       ┌─────────────┐
       │  nginx in app container               │  GoTrue     │
       │  proxies /auth/v1 → GoTrue            │  (auth)     │
       │  proxies /rest/v1 → PostgREST         └──────┬──────┘
       │                                              │
       │                                       ┌──────▼──────┐
       └──────────────────────────────────────►│  PostgREST  │
                                               │  (rest/v1)  │
                                               └──────┬──────┘
                                                      │  SET ROLE based on JWT claim
                                                      ▼
                              ┌──────────────────────────────────────────┐
                              │              PostgreSQL                  │
                              │  - 10 tables (organizations, users,      │
                              │    sites, classrooms, enrollments, …)    │
                              │  - RLS policies on every table           │
                              │  - active_role_is() gates every policy   │
                              │  - admin_row_count() powers the diff UI  │
                              └──────────────────────────────────────────┘
```

A **single Dashboard route** renders whichever role view matches `active_role`.
There are no per-role URLs; the role switcher updates the JWT, the auth state
changes, every cached query invalidates, and the view swaps in place.

## Quick start

Two ways to run it. Both end up at <http://localhost:3000> (or 54323 for the CLI
dev stack's Studio).

### Option A: Supabase CLI dev stack (fastest)

Requires Docker.

```sh
# Database
npx supabase start
npx supabase db reset    # applies migrations + seed
npx supabase test db     # 64 pgTAP assertions

# Frontend
cd frontend
npm install
npm run dev              # http://localhost:5173
```

### Option B: Production-shaped Docker Compose

Mirrors what the Nomad jobs deploy. Includes Authentik for the SSO flow.

```sh
cd deploy
cp .env.example .env     # defaults work for local dev as-is
docker compose up -d --build
# App at http://localhost:3000, Authentik at http://localhost:9000
```

See [`deploy/README.md`](deploy/README.md) for the Authentik SSO walkthrough and
the Nomad + Vault deployment path.

## Demo accounts

Password for every seeded account: **`Demo123!password`**

| Email | Memberships | What to look for |
|---|---|---|
| `admin@example.test` | administrator | Global read access — sees everything |
| `multi@example.test` | supervisor + instructor + student | The role switcher comes alive; switch between hats and watch the same dashboard rewrite itself |
| `instructor@example.test` | instructor only | Open the role switcher: Administrator / Supervisor / Student are greyed with "no access" |
| `student1@example.test` | student only | The invalid-view panes show the gap most dramatically (0 sites visible vs 2 globally) |

## Try this

1. Sign in as `instructor@example.test`. Open the role switcher dropdown. The
   three roles you don't have are greyed out with "no access" — that's the
   security model rendered as UI.
2. Sign in as `student1@example.test`. Scroll to the invalid-view panes. You
   see 0 rows in `sites`. An administrator sees 2. RLS hid them.
3. Sign in as `multi@example.test`. Switch to **Instructor**. You see
   *one* classroom (the one you teach). Switch to **Student**. The view
   changes; now you see a *different* classroom (the one you're enrolled
   in at another site). Same dashboard, same component, different RLS
   verdict.

## Repository layout

```
/                       Top-level docs, deploy artifacts, Supabase config
├── frontend/           The entire React + Vite application
│   └── src/{auth,components,hooks,layouts,lib,pages,views}/
├── supabase/           Database — kept at root for the Supabase CLI
│   ├── migrations/     9 SQL migrations: schema, helpers, RLS, RPC
│   ├── seed.sql
│   └── tests/database/ pgTAP — 64 assertions
├── deploy/             docker-compose, Dockerfile, Nomad, Vault, blueprints
├── CLAUDE.md           Project decisions, data model, mutation matrix
└── INFORMATION.md      Original spec
```

Frontend commands run from `frontend/`. Database commands run from root.
Docker builds run from root with `-f deploy/Dockerfile.app .` so the context
sees both `frontend/` and `deploy/`.

## Tech stack

- **Database / middleware:** PostgreSQL + Supabase (GoTrue + PostgREST), self-hosted
- **Frontend:** TypeScript · React 19 · Vite · TanStack Query · Radix UI · Tailwind CSS v4
- **Auth:** GoTrue for email/password, federated to Authentik for SSO
- **Tests:** pgTAP for RLS (the load-bearing tests of this project)
- **Deployment:** Docker Compose for local; Nomad + Vault for clusters

## Pedagogical principles

These are written down in [`CLAUDE.md`](CLAUDE.md) and shape every design
decision in the repo:

1. **RLS is the security boundary, not the UI.** Never filter sensitive data
   in JavaScript "to be safe." Fix it in the policy.
2. **Invalid views must fail visibly.** SELECT denials are silent in Postgres.
   Surface them with the `admin_row_count` diff or learners won't see the
   lesson.
3. **The token decides access.** Role switching re-issues the JWT. UI-side
   role state would fake the security model.
4. **Keep the code path short.** Component → Supabase client → Postgres → RLS
   → result. No abstractions that obscure where the denial happens.

## What's intentionally *not* here

- **Production-grade `admin_row_count`.** It's a teaching RPC. It leaks
  global row totals to any authenticated user. Remove or scope per-org
  before a real deployment.
- **Mutation demos in the UI.** The RLS policies cover INSERT/UPDATE/DELETE
  for every role; pgTAP tests cover key denials. The frontend doesn't
  expose mutation buttons — read denial is the visible half of the lesson.
- **CI/CD.** Run `npm run lint`, `npm run build`, and `npx supabase test db`
  by hand.

## Further reading

- [`CLAUDE.md`](CLAUDE.md) — Locked design decisions, mutation policy matrix,
  data model diagram, seed data topology
- [`deploy/README.md`](deploy/README.md) — Compose and Nomad walkthroughs,
  troubleshooting, security caveats
- [`deploy/vault/README.md`](deploy/vault/README.md) — Vault KV layout,
  Nomad ↔ Vault workload identity binding
- [`INFORMATION.md`](INFORMATION.md) — The original spec this project was
  built against
