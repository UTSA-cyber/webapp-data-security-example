# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

**Phase 1 complete (frontend scaffold).** Vite + React 19 + TypeScript + Tailwind v4 + Radix primitives + React Router + ESLint/Prettier + Supabase CLI are installed and configured. The dev server boots and serves a placeholder shell with stub pages for each role.

**Phase 2 (data layer with RLS) is the current focus** — schema migrations, RLS policies, the role-switching RPC, pgTAP tests, and seed data have not been written yet.

This file records **decisions already made** with the user. Future Claude sessions should treat these as locked unless the user revisits them.

## Project intent

An educational web app demonstrating **role-based data access enforced at the database layer** via Postgres row-level security (RLS), exposed through self-hosted Supabase. The pedagogical point: authorization lives in the database, not in app code, so a misbehaving frontend cannot read data the role isn't entitled to.

The "Invalid Views" in the spec exist specifically to demonstrate this — a student-role pane that *tries* to query teacher classrooms must visibly fail because Postgres RLS denies it, not because the UI hid the button.

## Pedagogical principles (do not erode these during implementation)

1. **RLS is the security boundary, not the UI.** Never filter sensitive data in JavaScript "to be safe." If a query returns rows it shouldn't, the bug is in an RLS policy, not the frontend. Fix it there.
2. **Invalid views must fail visibly.** SELECT denials are silent in Postgres (RLS returns zero rows, no error). To make the denial pedagogically visible, ship a `debug.row_visibility_diff(table_name)` SECURITY DEFINER RPC that returns the row count an administrator would see for the same query. The invalid-view panes display *"You see 0 rows. Administrator sees N. RLS filtered the other N."* INSERT/UPDATE/DELETE denials throw real Postgres errors — those go straight to toast.
3. **The token decides access.** Role switching must re-issue the JWT (see below). UI-side role filters are forbidden — they fake the security model.
4. **Keep the code path short.** Component → Supabase client → Postgres → RLS → result. Avoid intermediate abstractions that obscure where the denial happens.

## Roles, memberships, and access model

Four roles: `student`, `instructor`, `supervisor`, `administrator`. Role assignment is via `Memberships` (users ↔ roles), and **multi-role users are real**: a user can be an instructor in one classroom and a student in another at a different site. RLS policies must be written against the membership relation and the user's currently-active role, never assuming a single role per user.

Per-role SELECT visibility:

- **student** — only courses they're enrolled in (via `enrollments`)
- **instructor** — **only** classrooms where `classrooms.instructor_id = auth.uid()`. Not the broader "everything at sites I'm a member of" reading. `site_instructors` membership is the *gate for INSERTing* new classrooms (where they can teach), not what they currently teach.
- **supervisor** — sites they appear in via `site_supervisors`, plus the classrooms, instructors, courses, and enrollments that descend from those sites and their parent organizations
- **administrator** — **global** (not scoped to any organization). One admin can read/write any organization.

Default role on signup is `student`. New role memberships are admin-assigned only.

### Active-role JWT claim (load-bearing design)

A user with multiple memberships needs to demonstrate each role's view in turn. Mechanism:

- Store `active_role` in `app_metadata` (admin-controlled, not user-editable directly).
- When the user clicks "view as instructor," call a Supabase RPC that **validates the membership** and updates `app_metadata.active_role`.
- The frontend calls `supabase.auth.refreshSession()` — the new JWT carries the new claim.
- RLS policies read `(auth.jwt() -> 'app_metadata' ->> 'active_role')` to scope queries.

This is the load-bearing teaching moment: the token determines what the database returns. Do not implement a "current role" piece of React state that filters queries client-side — that would invalidate the lesson.

## Data model (planned tables)

```
organizations  (1) ─── (N)  sites  (1) ─── (N)  classrooms  (N) ─── (1)  courses
                              │                      │                       │
                              ├─ site_supervisors    ├─ instructor_id ─→ users    (organization scopes courses)
                              │  (N↔N users)         │
                              ├─ site_instructors    └─ enrollments ─→ users  [students]
                              │  (N↔N users)
```

Tables: `organizations`, `users`, `roles`, `memberships`, `sites`, `site_supervisors`, `site_instructors`, `courses`, `classrooms`, `enrollments`.

**Cross-org integrity invariant.** A classroom's `course.organization_id` must equal its `site.organization_id`. Enforced via INSERT/UPDATE trigger on `classrooms`. You can't run an Org A course at an Org B site.

**Auto-assign on site creation.** An INSERT trigger on `sites` adds the creating user to `site_supervisors` for the new row. Without this, a supervisor would lose visibility of the site they just created.

**Load-bearing traversals.** The supervisor → site → classroom → enrollment/instructor chain is what supervisor RLS policies walk; the student → enrollment → classroom → course chain is what student policies walk. Both must be indexed (FKs alone are insufficient — see migration `001_schema.sql`).

## Tech stack (locked)

- **Database / middleware:** Self-hosted Supabase stack (Postgres + GoTrue + PostgREST + Realtime + Storage + Studio) via Supabase's official docker-compose, deployed as a Nomad job. No Supabase Cloud.
- **Frontend:** TypeScript + React + Vite + Radix UI + Tailwind CSS.
- **Data fetching:** TanStack Query wrapping the Supabase JS client. Each role's view uses `useQuery` with role-scoped query keys; mutations invalidate the relevant keys. Pattern: thin custom hooks per resource (`useCourses`, `useClassrooms`, etc.) so the Supabase call site stays grep-able.
- **Migrations:** Supabase CLI (`supabase/migrations/*.sql`). RLS policies live in migrations, not in app code.
- **Testing (RLS):** pgTAP. For each role, assert which rows are visible and which queries are denied. RLS bugs are silent and dangerous — these tests are not optional.

These are constraints, not suggestions. Do not substitute (no Next.js, no separate ORM bypassing PostgREST, no alternate UI library).

## Mutation policy matrix (locked)

`*` means INSERT, UPDATE, and DELETE. "self only" on UPDATE means the user's own row (id = auth.uid()) with `WITH CHECK` preventing identity-changing updates.

| Table / Op | Administrator | Supervisor | Instructor | Student |
|---|---|---|---|---|
| `organizations` * | ✅ all | ❌ | ❌ | ❌ |
| `users` INSERT / DELETE | ✅ | ❌ | ❌ | ❌ |
| `users` UPDATE | ✅ all | self only | self only | self only |
| `roles` * | ✅ all | ❌ | ❌ | ❌ |
| `memberships` * | ✅ all | ❌ | ❌ | ❌ |
| `sites` INSERT | ✅ | ✅ *(creator auto-added to `site_supervisors` via trigger)* | ❌ | ❌ |
| `sites` UPDATE | ✅ | own supervised sites | ❌ | ❌ |
| `sites` DELETE | ✅ | ❌ *(admin-only — destructive)* | ❌ | ❌ |
| `site_supervisors` * | ✅ | own supervised sites *(supervisors may add co-supervisors)* | ❌ | ❌ |
| `site_instructors` * | ✅ | own supervised sites | ❌ | ❌ |
| `courses` * | ✅ all | own organizations *(via "supervises ≥ 1 site in this org")* | ❌ | ❌ |
| `classrooms` INSERT | ✅ | site ∈ own supervised sites + course in same org | site ∈ own `site_instructors` rows + `instructor_id = me` + course in same org | ❌ |
| `classrooms` UPDATE | ✅ | site ∈ own supervised sites | `instructor_id = me` | ❌ |
| `classrooms` DELETE | ✅ | site ∈ own supervised sites | ❌ | ❌ |
| `enrollments` * | ✅ | classroom.site ∈ own sites | classroom_id ∈ own classrooms | ❌ |

The helper `active_role_is(role)` gates every policy and double-checks the membership (defense in depth — even a tampered JWT claim doesn't pass without an actual membership row).

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

One organization, two sites, three demo users:

- **Organization** — "Example University" (single org; suffices to exercise the org → site → classroom chain).
- **Site A** and **Site B**, both under the organization.
- **Courses** — at least one course at the org level (e.g. "MATH 101"), shared between sites.
- **User 1** — administrator (global). Sees everything.
- **User 2** — `site_supervisors` of Site A + `site_instructors` of Site A + instructor of Classroom A1 (at Site A) + enrolled as student in Classroom B1 (at Site B). Exercises supervisor / instructor / student via the switcher.
- **User 3** — `site_instructors` of Site B + instructor of Classroom B1. Single role.
- A handful of additional student users enrolled in both classrooms so list views aren't trivially small.

This topology satisfies the "instructor of one classroom can be a student of another at a different site under a different instructor" constraint while keeping the seed surface small.

## Working style

The spec's closing line is **"Ask questions till you reach clarity."** When requirements are ambiguous, ask — don't guess. Keep the implementation **simple and elegant**; this is a teaching artifact, so clarity of the RLS policies and the role boundary matters more than feature breadth.
