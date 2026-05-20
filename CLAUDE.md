# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

Pre-implementation. The artifacts present are `INFORMATION.md` (original spec) and this file. There is no source tree, no package manifests, no Docker/Nomad files, no SQL yet. Do not invent commands or paths — read the directory before claiming anything exists.

This file records **decisions already made** with the user. Future Claude sessions should treat these as locked unless the user revisits them.

## Project intent

An educational web app demonstrating **role-based data access enforced at the database layer** via Postgres row-level security (RLS), exposed through self-hosted Supabase. The pedagogical point: authorization lives in the database, not in app code, so a misbehaving frontend cannot read data the role isn't entitled to.

The "Invalid Views" in the spec exist specifically to demonstrate this — a student-role pane that *tries* to query teacher classrooms must visibly fail because Postgres RLS denies it, not because the UI hid the button.

## Pedagogical principles (do not erode these during implementation)

1. **RLS is the security boundary, not the UI.** Never filter sensitive data in JavaScript "to be safe." If a query returns rows it shouldn't, the bug is in an RLS policy, not the frontend. Fix it there.
2. **Invalid views must fail visibly.** When a query is denied, surface an empty result *and* a toast carrying the RLS error. Silent empty states defeat the lesson.
3. **The token decides access.** Role switching must re-issue the JWT (see below). UI-side role filters are forbidden — they fake the security model.
4. **Keep the code path short.** Component → Supabase client → Postgres → RLS → result. Avoid intermediate abstractions that obscure where the denial happens.

## Roles, memberships, and access model

Four roles: `student`, `instructor`, `supervisor`, `administrator`. Role assignment is via `Memberships` (users ↔ roles), and **multi-role users are real**: a user can be an instructor in one classroom and a student in another at a different site. RLS policies must be written against the membership relation and the user's currently-active role, never assuming a single role per user.

Per-role visibility:

- **student** — only courses they're enrolled in (via `Enrollments`)
- **instructor** — only classrooms they teach (via `Classrooms.instructor_id` or join)
- **supervisor** — only sites assigned to them via a `site_supervisors` join, plus the classrooms and instructors that descend from those sites
- **administrator** — everything

Default role on signup is `student`. New roles beyond that are assigned by an administrator.

### Active-role JWT claim (load-bearing design)

A user with multiple memberships needs to demonstrate each role's view in turn. Mechanism:

- Store `active_role` in `app_metadata` (admin-controlled, not user-editable directly).
- When the user clicks "view as instructor," call a Supabase RPC that **validates the membership** and updates `app_metadata.active_role`.
- The frontend calls `supabase.auth.refreshSession()` — the new JWT carries the new claim.
- RLS policies read `(auth.jwt() -> 'app_metadata' ->> 'active_role')` to scope queries.

This is the load-bearing teaching moment: the token determines what the database returns. Do not implement a "current role" piece of React state that filters queries client-side — that would invalidate the lesson.

## Data model (planned tables)

`users`, `roles`, `memberships`, `courses`, `classrooms` (site + course + instructor), `enrollments` (student ↔ classroom), `sites`, `site_supervisors` (supervisor ↔ site).

The supervisor → site → classroom → instructor/enrollment chain is the load-bearing relationship for RLS — supervisor policies traverse it.

## Tech stack (locked)

- **Database / middleware:** Self-hosted Supabase stack (Postgres + GoTrue + PostgREST + Realtime + Storage + Studio) via Supabase's official docker-compose, deployed as a Nomad job. No Supabase Cloud.
- **Frontend:** TypeScript + React + Vite + Radix UI + Tailwind CSS.
- **Data fetching:** TanStack Query wrapping the Supabase JS client. Each role's view uses `useQuery` with role-scoped query keys; mutations invalidate the relevant keys. Pattern: thin custom hooks per resource (`useCourses`, `useClassrooms`, etc.) so the Supabase call site stays grep-able.
- **Migrations:** Supabase CLI (`supabase/migrations/*.sql`). RLS policies live in migrations, not in app code.
- **Testing (RLS):** pgTAP. For each role, assert which rows are visible and which queries are denied. RLS bugs are silent and dangerous — these tests are not optional.

These are constraints, not suggestions. Do not substitute (no Next.js, no separate ORM bypassing PostgREST, no alternate UI library).

## Authentication

- **Self-hosted Authentik** as the SSO IdP, running as a separate Nomad job.
- **Two coexisting auth paths:**
  - Email/password via Supabase Auth (GoTrue) — used by the seeded demo users.
  - SSO via Authentik (OIDC) federated into GoTrue — available as a separate "Sign in with SSO" flow for new users.
- Demo users do **not** go through Authentik. Keeping the seed surface narrow; the lesson is RLS, not federation plumbing.

## Deployment

- **docker-compose** for local development (all services).
- **Nomad jobs** for deployment (app, Supabase stack, Authentik).
- **Vault** for secrets, integrated with Nomad via workload identity.
- **No Consul.** Nomad ≥ 1.3 has native service discovery; KV/cross-DC features aren't needed at this scope.

## Seed data

Three demo users to exercise the role switcher:

- **User 1** — administrator. Sees everything.
- **User 2** — supervisor of Site A, instructor of Classroom A1 (Site A), student in Classroom B1 (Site B). Exercises all three non-admin roles via the switcher.
- **User 3** — instructor of Classroom B1. Single role.

Plus Site A and Site B, at least one course/classroom each, and a handful of other students so list views aren't trivially empty.

## Working style

The spec's closing line is **"Ask questions till you reach clarity."** When requirements are ambiguous, ask — don't guess. Keep the implementation **simple and elegant**; this is a teaching artifact, so clarity of the RLS policies and the role boundary matters more than feature breadth.
