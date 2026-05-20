-- Helpers used by every RLS policy and the invalid-view demo panes.
--
-- Both functions are SECURITY DEFINER so they bypass RLS on the tables they
-- read (otherwise active_role_is would recurse through the memberships
-- policy, and admin_row_count couldn't measure what an unfiltered query sees).
-- An explicit empty search_path defends against schema-hijacking; every
-- referenced table is fully qualified below.

-- =========================================================================
-- active_role_is(role_name)
--
-- Returns true when BOTH:
--   1. the JWT's app_metadata.active_role matches the given role_name, AND
--   2. the calling user actually holds that role in public.memberships.
--
-- The double check is intentional: even if the RPC that writes app_metadata
-- had a bug, a forged active_role claim alone wouldn't satisfy policies
-- without a real membership row.
-- =========================================================================

create function public.active_role_is(role_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (auth.jwt() -> 'app_metadata' ->> 'active_role') = role_name
    and exists (
      select 1
      from public.memberships m
      join public.roles r on r.id = m.role_id
      where m.user_id = auth.uid()
        and r.name = role_name
    );
$$;

revoke all on function public.active_role_is(text) from public;
grant execute on function public.active_role_is(text) to authenticated;

-- =========================================================================
-- admin_row_count(table_name)
--
-- Returns the total row count for the named table, ignoring RLS. The
-- frontend's "invalid view" panes call this to show learners the gap
-- between what their current role sees and what would be visible without
-- RLS — making silent SELECT denials pedagogically visible.
--
-- Whitelisting the table_name argument is mandatory: SECURITY DEFINER +
-- dynamic SQL = a SQL injection target without it.
-- =========================================================================

create function public.admin_row_count(table_name text)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result  bigint;
begin
  if table_name not in (
    'organizations', 'users', 'sites', 'site_supervisors', 'site_instructors',
    'courses', 'classrooms', 'enrollments', 'memberships', 'roles'
  ) then
    raise exception 'admin_row_count: table % is not in the whitelist', table_name
      using errcode = 'invalid_parameter_value';
  end if;

  execute format('select count(*) from public.%I', table_name) into result;
  return result;
end;
$$;

revoke all on function public.admin_row_count(text) from public;
grant execute on function public.admin_row_count(text) to authenticated;

-- =========================================================================
-- user_supervised_site_ids()
--
-- Breaks an RLS recursion cycle. Any policy that filters by "sites this user
-- supervises" needs to subquery site_supervisors — but the policy on
-- site_supervisors *itself* filters by "sites this user supervises", which
-- means it would subquery site_supervisors again. Postgres detects the
-- infinite recursion and aborts the query.
--
-- SECURITY DEFINER lets this function read site_supervisors *without*
-- triggering its RLS policies, breaking the loop. Used in every policy
-- where the natural expression would be "site_id in (select site_id from
-- site_supervisors where user_id = auth.uid())".
-- =========================================================================

create function public.user_supervised_site_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select site_id from public.site_supervisors where user_id = auth.uid();
$$;

revoke all on function public.user_supervised_site_ids() from public;
grant execute on function public.user_supervised_site_ids() to authenticated;

-- =========================================================================
-- user_taught_classroom_ids()
--
-- The instructor-side counterpart to user_supervised_site_ids().
-- Breaks the classrooms ↔ enrollments cycle: the enrollments policy needs
-- to know "classrooms I teach", but reading classrooms triggers a policy
-- that reads enrollments back. SECURITY DEFINER short-circuits the loop.
-- =========================================================================

create function public.user_taught_classroom_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.classrooms where instructor_id = auth.uid();
$$;

revoke all on function public.user_taught_classroom_ids() from public;
grant execute on function public.user_taught_classroom_ids() to authenticated;

-- =========================================================================
-- user_enrolled_classroom_ids()
--
-- The student-side counterpart. Used by classrooms_select_student so the
-- policy can answer "classrooms I'm enrolled in" without reading
-- enrollments (which would re-enter classrooms via cross-policy lookups).
-- =========================================================================

create function public.user_enrolled_classroom_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select classroom_id from public.enrollments where student_id = auth.uid();
$$;

revoke all on function public.user_enrolled_classroom_ids() from public;
grant execute on function public.user_enrolled_classroom_ids() to authenticated;
