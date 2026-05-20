-- Per-role RLS visibility and denial tests.
--
-- Set up a controlled fixture (1 org, 2 sites, 2 classrooms, 4 users with
-- the same multi-role topology as the seed) and then, for each role, switch
-- the JWT and assert what the role sees vs. what's denied.
--
-- This is the load-bearing security test. Any policy regression — a missing
-- gate, an OR where there should be an AND — should produce a row count
-- mismatch here long before it makes it to production.

begin;

create extension if not exists pgtap with schema extensions;

-- =========================================================================
-- Clear seed data so the test runs against a known minimal fixture. The
-- enclosing transaction rolls back at the end, so seed data is restored
-- for subsequent tests / app use. Order respects FK constraints.
-- =========================================================================

delete from public.enrollments;
delete from public.classrooms;
delete from public.courses;
delete from public.site_instructors;
delete from public.site_supervisors;
delete from public.sites;
delete from public.organizations;
delete from public.memberships;
delete from public.users;
delete from auth.users;

-- =========================================================================
-- Fixture: 1 org, 2 sites, 1 course, 2 classrooms, 4 users.
-- Inserted as the migration role, so RLS is bypassed during setup.
-- =========================================================================

-- Stable UUIDs make the test output readable in failure messages.
-- Test UUIDs use a 'd' prefix to avoid collision with seed data (which uses
-- a/c/numeric prefixes). Tests must not depend on seed because supabase test
-- db runs against the live DB without resetting it.
\set org_id      '\'dd000000-0000-0000-0000-0000000000a1\''
\set site_a_id   '\'dd000000-0000-0000-0000-0000000000aa\''
\set site_b_id   '\'dd000000-0000-0000-0000-0000000000bb\''
\set course_id   '\'dd000000-0000-0000-0000-0000000000c1\''
\set room_a1_id  '\'dd000000-0000-0000-0000-00000000a1c1\''
\set room_b1_id  '\'dd000000-0000-0000-0000-00000000b1c1\''
\set u_admin     '\'dd111111-1111-1111-1111-111111111111\''
\set u_multi     '\'dd222222-2222-2222-2222-222222222222\''
\set u_instr     '\'dd333333-3333-3333-3333-333333333333\''
\set u_student   '\'dd444444-4444-4444-4444-444444444444\''

-- auth.users rows so auth.uid() resolves to a real user
insert into auth.users (id, instance_id, email, raw_app_meta_data, aud, role)
values
  (:u_admin::uuid,   '00000000-0000-0000-0000-000000000000'::uuid, 'admin@test',   '{"active_role":"administrator"}'::jsonb, 'authenticated', 'authenticated'),
  (:u_multi::uuid,   '00000000-0000-0000-0000-000000000000'::uuid, 'multi@test',   '{"active_role":"supervisor"}'::jsonb,    'authenticated', 'authenticated'),
  (:u_instr::uuid,   '00000000-0000-0000-0000-000000000000'::uuid, 'instr@test',   '{"active_role":"instructor"}'::jsonb,    'authenticated', 'authenticated'),
  (:u_student::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'student@test', '{"active_role":"student"}'::jsonb,       'authenticated', 'authenticated');

insert into public.users (id, full_name) values
  (:u_admin::uuid,   'Admin'),
  (:u_multi::uuid,   'Multi Role'),
  (:u_instr::uuid,   'Site B Instructor'),
  (:u_student::uuid, 'Extra Student');

insert into public.memberships (user_id, role_id) values
  (:u_admin::uuid,   1),  -- administrator
  (:u_multi::uuid,   2),  -- supervisor
  (:u_multi::uuid,   3),  -- instructor
  (:u_multi::uuid,   4),  -- student
  (:u_instr::uuid,   3),  -- instructor
  (:u_student::uuid, 4);  -- student

insert into public.organizations (id, name) values
  (:org_id::uuid, 'Test Org');

insert into public.sites (id, organization_id, name) values
  (:site_a_id::uuid, :org_id::uuid, 'Site A'),
  (:site_b_id::uuid, :org_id::uuid, 'Site B');

insert into public.site_supervisors (user_id, site_id) values
  (:u_multi::uuid, :site_a_id::uuid);

insert into public.site_instructors (user_id, site_id) values
  (:u_multi::uuid, :site_a_id::uuid),
  (:u_instr::uuid, :site_b_id::uuid);

insert into public.courses (id, organization_id, course_number, description) values
  (:course_id::uuid, :org_id::uuid, 'TEST 101', 'A shared course offered at both sites');

insert into public.classrooms (id, site_id, course_id, instructor_id, name) values
  (:room_a1_id::uuid, :site_a_id::uuid, :course_id::uuid, :u_multi::uuid, 'Room A1'),
  (:room_b1_id::uuid, :site_b_id::uuid, :course_id::uuid, :u_instr::uuid, 'Room B1');

insert into public.enrollments (student_id, classroom_id) values
  (:u_multi::uuid,   :room_b1_id::uuid),  -- multi-user is a student in B1
  (:u_student::uuid, :room_a1_id::uuid),
  (:u_student::uuid, :room_b1_id::uuid);

-- =========================================================================
-- Helper: switch the simulated session to a (user, active_role) pair.
-- Sets the JWT claims that auth.uid() / auth.jwt() read, and switches the
-- DB role to authenticated so RLS engages exactly as it would for a real
-- PostgREST request.
-- =========================================================================

create or replace function _test_authenticate_as(_user_id uuid, _active_role text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', _user_id::text,
      'role', 'authenticated',
      'app_metadata', json_build_object('active_role', _active_role)
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

select plan(32);

-- =========================================================================
-- Administrator (user 1) — sees everything
-- =========================================================================

select _test_authenticate_as(:u_admin::uuid, 'administrator');

select results_eq('select count(*)::int from public.organizations',     'values (1)', 'admin sees 1 organization');
select results_eq('select count(*)::int from public.users',             'values (4)', 'admin sees all 4 users');
select results_eq('select count(*)::int from public.sites',             'values (2)', 'admin sees both sites');
select results_eq('select count(*)::int from public.courses',           'values (1)', 'admin sees the course');
select results_eq('select count(*)::int from public.classrooms',        'values (2)', 'admin sees both classrooms');
select results_eq('select count(*)::int from public.enrollments',       'values (3)', 'admin sees all 3 enrollments');
select results_eq('select count(*)::int from public.memberships',       'values (6)', 'admin sees all 6 memberships');
select results_eq('select count(*)::int from public.site_supervisors',  'values (1)', 'admin sees the supervisor assignment');
select results_eq('select count(*)::int from public.site_instructors',  'values (2)', 'admin sees both instructor assignments');

-- =========================================================================
-- Supervisor (user 2 wearing supervisor hat) — only Site A and its descendants
-- =========================================================================

reset role;
select _test_authenticate_as(:u_multi::uuid, 'supervisor');

select results_eq('select count(*)::int from public.organizations', 'values (1)',
  'supervisor sees the org they supervise');
select results_eq('select count(*)::int from public.sites',         'values (1)',
  'supervisor sees only Site A (not Site B)');
select results_eq('select count(*)::int from public.classrooms',    'values (1)',
  'supervisor sees only Classroom A1 (not B1)');
select results_eq('select count(*)::int from public.enrollments',   'values (1)',
  'supervisor sees only the A1 enrollment, not the B1 ones');
select results_eq('select count(*)::int from public.courses',       'values (1)',
  'supervisor sees the org-level course');

-- The exact site visible should be Site A
select results_eq('select name from public.sites', $$ values ('Site A'::text) $$,
  'supervisor sees Site A by name (not Site B)');

-- =========================================================================
-- Instructor (user 2 wearing instructor hat) — ONLY classrooms they teach
-- (Classroom A1). The "invalid view": sites is empty.
-- =========================================================================

reset role;
select _test_authenticate_as(:u_multi::uuid, 'instructor');

select results_eq('select count(*)::int from public.classrooms', 'values (1)',
  'instructor sees only the classroom they teach (A1)');
select results_eq('select name from public.classrooms', $$ values ('Room A1'::text) $$,
  'instructor sees Classroom A1 specifically, not B1');

-- The invalid view: sites returns 0 rows for instructor
select results_eq('select count(*)::int from public.sites', 'values (0)',
  'INVALID VIEW: instructor sees zero sites (RLS-filtered)');

-- But admin_row_count tells the truth — used by the UI to show the gap
select results_eq('select public.admin_row_count(''sites'')::int', 'values (2)',
  'admin_row_count reveals 2 sites exist (invalid-view diff is 2)');

-- Enrollments visible to the instructor: enrollments in classroom A1 only
-- (multi-user as instructor of A1 sees enrolled students). B1 enrollment of
-- themselves as student is NOT visible while wearing instructor hat.
select results_eq('select count(*)::int from public.enrollments', 'values (1)',
  'instructor sees enrollments in their own classroom only');

-- Courses visible: the course of A1 (which is the one course)
select results_eq('select count(*)::int from public.courses', 'values (1)',
  'instructor sees the course of their classroom');

-- =========================================================================
-- Student (user 2 wearing student hat) — only Classroom B1 (where enrolled)
-- =========================================================================

reset role;
select _test_authenticate_as(:u_multi::uuid, 'student');

select results_eq('select count(*)::int from public.classrooms', 'values (1)',
  'student sees only the classroom they''re enrolled in (B1)');
select results_eq('select name from public.classrooms', $$ values ('Room B1'::text) $$,
  'student sees Classroom B1 specifically');

select results_eq('select count(*)::int from public.sites', 'values (0)',
  'student sees zero sites');

select results_eq('select count(*)::int from public.enrollments', 'values (1)',
  'student sees only their own enrollment');

select results_eq('select count(*)::int from public.courses', 'values (1)',
  'student sees the course they''re enrolled in');

-- =========================================================================
-- Cross-role isolation: even with multiple memberships, the active_role
-- claim determines what's visible. Switching back to instructor must show
-- the instructor-view, not a union.
-- =========================================================================

reset role;
select _test_authenticate_as(:u_multi::uuid, 'instructor');

select results_eq(
  'select id::text from public.classrooms',
  $$ values ('dd000000-0000-0000-0000-00000000a1c1'::text) $$,
  'switching back to instructor returns A1 only, never B1');

-- =========================================================================
-- Active-role mismatch: a user without a 'supervisor' membership cannot
-- read supervisor-scoped data even by lying about active_role.
-- =========================================================================

reset role;
select _test_authenticate_as(:u_instr::uuid, 'supervisor');  -- user 3 has no supervisor membership

select results_eq('select count(*)::int from public.sites', 'values (0)',
  'forged active_role=supervisor without membership returns 0 sites (defense in depth holds)');

-- =========================================================================
-- Mutation denials — INSERT/UPDATE/DELETE policies actually throw errors
-- =========================================================================

reset role;
select _test_authenticate_as(:u_student::uuid, 'student');

-- Student attempting to INSERT a site: blocked. No INSERT policy matches
-- and RLS denies with a real error (vs SELECT which is silent).
select throws_ok(
  $$ insert into public.sites (organization_id, name) values ('dd000000-0000-0000-0000-0000000000a1'::uuid, 'Rogue Site') $$,
  'new row violates row-level security policy for table "sites"',
  'student cannot INSERT into sites');

reset role;
select _test_authenticate_as(:u_instr::uuid, 'instructor');

-- Instructor attempting to INSERT a site: also blocked
select throws_ok(
  $$ insert into public.sites (organization_id, name) values ('dd000000-0000-0000-0000-0000000000a1'::uuid, 'Rogue Site') $$,
  'new row violates row-level security policy for table "sites"',
  'instructor cannot INSERT into sites');

-- Multi-user, wearing the instructor hat, teaches A1 — NOT B1. UPDATE on
-- B1 must be RLS-filtered to 0 rows. No error, just no effect.
reset role;
select _test_authenticate_as(:u_multi::uuid, 'instructor');
update public.classrooms set name = 'hacked' where id = 'dd000000-0000-0000-0000-00000000b1c1'::uuid;
reset role;
select is(
  (select name from public.classrooms where id = 'dd000000-0000-0000-0000-00000000b1c1'::uuid),
  'Room B1'::text,
  'instructor UPDATE on someone else''s classroom has no effect (USING filtered to 0 rows)');

-- =========================================================================
-- Cross-org integrity trigger fires on INSERT
-- (already reset to migration role above for the no-effect check)
-- =========================================================================

-- Create a second org and a course in it; then try to put it at Site A (org 1)
insert into public.organizations (id, name) values
  ('dd000000-0000-0000-0000-0000000000a2'::uuid, 'Other Org');
insert into public.courses (id, organization_id, course_number) values
  ('dd000000-0000-0000-0000-0000000000c2'::uuid, 'dd000000-0000-0000-0000-0000000000a2'::uuid, 'OTHER 999');

select throws_like(
  $$ insert into public.classrooms (site_id, course_id, instructor_id)
     values (
       'dd000000-0000-0000-0000-0000000000aa'::uuid,
       'dd000000-0000-0000-0000-0000000000c2'::uuid,
       'dd222222-2222-2222-2222-222222222222'::uuid
     ) $$,
  '%belong to different organizations%',
  'cross-org classroom INSERT is rejected by the integrity trigger');

select * from finish();
rollback;
