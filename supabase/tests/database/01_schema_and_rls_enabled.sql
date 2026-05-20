-- Structural pgTAP assertions: tables exist, RLS is enabled on every table,
-- helper functions are present. These tests don't simulate a JWT — they
-- catch the most common silent regression: a future migration that adds a
-- table and forgets to ENABLE ROW LEVEL SECURITY on it.

begin;

create extension if not exists pgtap with schema extensions;

select plan(32);

-- =========================================================================
-- Tables exist
-- =========================================================================

select has_table('public', 'organizations',     'organizations table exists');
select has_table('public', 'users',             'users table exists');
select has_table('public', 'roles',             'roles table exists');
select has_table('public', 'memberships',       'memberships table exists');
select has_table('public', 'sites',             'sites table exists');
select has_table('public', 'site_supervisors',  'site_supervisors table exists');
select has_table('public', 'site_instructors',  'site_instructors table exists');
select has_table('public', 'courses',           'courses table exists');
select has_table('public', 'classrooms',        'classrooms table exists');
select has_table('public', 'enrollments',       'enrollments table exists');

-- =========================================================================
-- RLS is enabled on every table
-- =========================================================================

select ok(
  (select relrowsecurity from pg_class where oid = 'public.organizations'::regclass),
  'RLS enabled on organizations'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.users'::regclass),
  'RLS enabled on users'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.roles'::regclass),
  'RLS enabled on roles'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.memberships'::regclass),
  'RLS enabled on memberships'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.sites'::regclass),
  'RLS enabled on sites'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.site_supervisors'::regclass),
  'RLS enabled on site_supervisors'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.site_instructors'::regclass),
  'RLS enabled on site_instructors'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.courses'::regclass),
  'RLS enabled on courses'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.classrooms'::regclass),
  'RLS enabled on classrooms'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.enrollments'::regclass),
  'RLS enabled on enrollments'
);

-- =========================================================================
-- Roles reference data is seeded with exactly the four expected roles
-- =========================================================================

select results_eq(
  'select name from public.roles order by id',
  $$ values ('administrator'::text), ('supervisor'::text), ('instructor'::text), ('student'::text) $$,
  'roles table contains administrator, supervisor, instructor, student'
);

-- =========================================================================
-- Helper functions exist with expected signatures
-- =========================================================================

select has_function('public', 'active_role_is',      array['text'], 'active_role_is(text) exists');
select has_function('public', 'admin_row_count',     array['text'], 'admin_row_count(text) exists');
select has_function('public', 'switch_active_role',  array['text'], 'switch_active_role(text) exists');

select function_returns('public', 'active_role_is',     array['text'], 'boolean',
                        'active_role_is returns boolean');
select function_returns('public', 'admin_row_count',    array['text'], 'bigint',
                        'admin_row_count returns bigint');
select function_returns('public', 'switch_active_role', array['text'], 'void',
                        'switch_active_role returns void');

-- SECURITY DEFINER on the three helpers — critical, since they bypass RLS
select is(
  (select prosecdef from pg_proc where proname = 'active_role_is' and pronamespace = 'public'::regnamespace),
  true,
  'active_role_is is SECURITY DEFINER'
);
select is(
  (select prosecdef from pg_proc where proname = 'admin_row_count' and pronamespace = 'public'::regnamespace),
  true,
  'admin_row_count is SECURITY DEFINER'
);
select is(
  (select prosecdef from pg_proc where proname = 'switch_active_role' and pronamespace = 'public'::regnamespace),
  true,
  'switch_active_role is SECURITY DEFINER'
);

-- =========================================================================
-- The cross-org integrity trigger and the auto-assign-supervisor trigger exist
-- =========================================================================

select has_trigger('public', 'classrooms', 'classrooms_org_integrity',
                   'classroom cross-org integrity trigger exists');
select has_trigger('public', 'sites', 'sites_auto_assign_supervisor',
                   'auto-assign-supervisor trigger exists');

select * from finish();
rollback;
