-- Seed data: 1 organization, 2 sites, 1 shared course, 3 demo users + extras.
--
-- Topology (matches CLAUDE.md):
--   User 1 — administrator (global)
--   User 2 — supervisor of Site A, instructor of Classroom A1 at Site A,
--            student enrolled in Classroom B1 at Site B. Holds all three
--            non-admin memberships; exercises the role switcher.
--   User 3 — instructor of Classroom B1 at Site B. Single role.
--   Users 4-6 — additional students for non-trivial enrollment lists.
--
-- All seeded users authenticate with the same password: "Demo123!password".
-- The whole seed runs as one DO block because the Supabase seed runner
-- doesn't preserve helper-function definitions across statements.

do $seed$
declare
  pw_hash text := crypt('Demo123!password', gen_salt('bf'));
  instance constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
begin
  -- =========================================================================
  -- auth.users + public.users
  -- =========================================================================

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values
    (instance, '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
     'admin@example.test',      pw_hash, now(),
     '{"provider":"email","providers":["email"],"active_role":"administrator"}'::jsonb,
     '{}'::jsonb, now(), now(), '', '', '', ''),
    (instance, '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
     'multi@example.test',      pw_hash, now(),
     '{"provider":"email","providers":["email"],"active_role":"student"}'::jsonb,
     '{}'::jsonb, now(), now(), '', '', '', ''),
    (instance, '33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated',
     'instructor@example.test', pw_hash, now(),
     '{"provider":"email","providers":["email"],"active_role":"instructor"}'::jsonb,
     '{}'::jsonb, now(), now(), '', '', '', ''),
    (instance, '44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated',
     'student1@example.test',   pw_hash, now(),
     '{"provider":"email","providers":["email"],"active_role":"student"}'::jsonb,
     '{}'::jsonb, now(), now(), '', '', '', ''),
    (instance, '55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated',
     'student2@example.test',   pw_hash, now(),
     '{"provider":"email","providers":["email"],"active_role":"student"}'::jsonb,
     '{}'::jsonb, now(), now(), '', '', '', ''),
    (instance, '66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated',
     'student3@example.test',   pw_hash, now(),
     '{"provider":"email","providers":["email"],"active_role":"student"}'::jsonb,
     '{}'::jsonb, now(), now(), '', '', '', '');

  insert into public.users (id, full_name) values
    ('11111111-1111-1111-1111-111111111111', 'Alice Administrator'),
    ('22222222-2222-2222-2222-222222222222', 'Morgan Multi-Role'),
    ('33333333-3333-3333-3333-333333333333', 'Ivan Instructor'),
    ('44444444-4444-4444-4444-444444444444', 'Sam Student'),
    ('55555555-5555-5555-5555-555555555555', 'Sara Student'),
    ('66666666-6666-6666-6666-666666666666', 'Sandy Student');

  -- =========================================================================
  -- Memberships (1=administrator, 2=supervisor, 3=instructor, 4=student)
  -- =========================================================================

  insert into public.memberships (user_id, role_id) values
    ('11111111-1111-1111-1111-111111111111', 1),
    ('22222222-2222-2222-2222-222222222222', 2),
    ('22222222-2222-2222-2222-222222222222', 3),
    ('22222222-2222-2222-2222-222222222222', 4),
    ('33333333-3333-3333-3333-333333333333', 3),
    ('44444444-4444-4444-4444-444444444444', 4),
    ('55555555-5555-5555-5555-555555555555', 4),
    ('66666666-6666-6666-6666-666666666666', 4);

  -- =========================================================================
  -- Organization, sites, course
  -- =========================================================================

  insert into public.organizations (id, name) values
    ('a0000000-0000-0000-0000-00000000a000', 'Example University');

  insert into public.sites (id, organization_id, name, address) values
    ('a0000000-0000-0000-0000-00000000aa00', 'a0000000-0000-0000-0000-00000000a000', 'Site A', '100 Campus Way'),
    ('a0000000-0000-0000-0000-00000000bb00', 'a0000000-0000-0000-0000-00000000a000', 'Site B', '200 College Drive');

  insert into public.courses (id, organization_id, course_number, description) values
    ('a0000000-0000-0000-0000-0000000c0001', 'a0000000-0000-0000-0000-00000000a000', 'TEST 101',
     'Introduction to RLS — a shared course offered at both sites');

  -- =========================================================================
  -- Site/role assignments
  -- =========================================================================

  insert into public.site_supervisors (user_id, site_id) values
    ('22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-00000000aa00');

  insert into public.site_instructors (user_id, site_id) values
    ('22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-00000000aa00'),
    ('33333333-3333-3333-3333-333333333333', 'a0000000-0000-0000-0000-00000000bb00');

  -- =========================================================================
  -- Classrooms — A1 (Site A, Multi-user) and B1 (Site B, Ivan)
  -- =========================================================================

  insert into public.classrooms (id, site_id, course_id, instructor_id, name) values
    ('c1aac1aa-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-00000000aa00',
     'a0000000-0000-0000-0000-0000000c0001',
     '22222222-2222-2222-2222-222222222222',
     'TEST 101 — Site A, Section 1'),
    ('c1bbc1bb-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-00000000bb00',
     'a0000000-0000-0000-0000-0000000c0001',
     '33333333-3333-3333-3333-333333333333',
     'TEST 101 — Site B, Section 1');

  -- =========================================================================
  -- Enrollments. Multi-user enrolls as a STUDENT in B1 — proves the
  -- multi-role topology (instructor at A, student at B).
  -- =========================================================================

  insert into public.enrollments (student_id, classroom_id) values
    ('22222222-2222-2222-2222-222222222222', 'c1bbc1bb-0000-0000-0000-000000000001'),
    ('44444444-4444-4444-4444-444444444444', 'c1aac1aa-0000-0000-0000-000000000001'),
    ('44444444-4444-4444-4444-444444444444', 'c1bbc1bb-0000-0000-0000-000000000001'),
    ('55555555-5555-5555-5555-555555555555', 'c1aac1aa-0000-0000-0000-000000000001'),
    ('55555555-5555-5555-5555-555555555555', 'c1bbc1bb-0000-0000-0000-000000000001'),
    ('66666666-6666-6666-6666-666666666666', 'c1aac1aa-0000-0000-0000-000000000001');
end
$seed$;
