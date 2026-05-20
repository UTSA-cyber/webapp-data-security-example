-- RLS policies: users, roles, memberships.
--
-- Patterns introduced here that the per-table migrations below reuse:
--   * Every policy is "TO authenticated" — anon users see nothing.
--   * Per-role policies are OR'd by Postgres, so a row is visible if ANY
--     matching policy passes (e.g. self carve-out OR admin OR role-scoped).
--   * SELECT policies for non-admin roles are gated by active_role_is(), so
--     a multi-role user only sees data appropriate to their currently
--     active hat.

-- =========================================================================
-- users
-- =========================================================================

-- Self carve-out: every authenticated user can read their own row, regardless
-- of active_role. Without this, the app can't show "logged in as Jane."
create policy users_select_self on public.users
  for select to authenticated
  using (id = auth.uid());

create policy users_select_administrator on public.users
  for select to authenticated
  using (public.active_role_is('administrator'));

-- Supervisor sees users connected to sites they supervise:
-- co-supervisors, instructors at those sites, and students enrolled in
-- classrooms at those sites.
create policy users_select_supervisor on public.users
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and id in (
      select ss.user_id
      from public.site_supervisors ss
      where ss.site_id in (
        select public.user_supervised_site_ids()
      )
      union
      select si.user_id
      from public.site_instructors si
      where si.site_id in (
        select public.user_supervised_site_ids()
      )
      union
      select e.student_id
      from public.enrollments e
      join public.classrooms c on c.id = e.classroom_id
      where c.site_id in (
        select public.user_supervised_site_ids()
      )
    )
  );

-- Instructor sees the students currently enrolled in their classrooms.
create policy users_select_instructor on public.users
  for select to authenticated
  using (
    public.active_role_is('instructor')
    and id in (
      select e.student_id
      from public.enrollments e
      join public.classrooms c on c.id = e.classroom_id
      where c.instructor_id = auth.uid()
    )
  );

-- Self UPDATE carve-out. WITH CHECK keeps the user from rewriting their own
-- id (which would also rewrite their auth linkage).
create policy users_update_self on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy users_update_administrator on public.users
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy users_insert_administrator on public.users
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy users_delete_administrator on public.users
  for delete to authenticated
  using (public.active_role_is('administrator'));

-- =========================================================================
-- roles
--
-- Static reference data. Every authenticated user can read all four rows;
-- mutations are blocked entirely (no INSERT/UPDATE/DELETE policies = no
-- writes possible under RLS).
-- =========================================================================

create policy roles_select on public.roles
  for select to authenticated
  using (true);

-- =========================================================================
-- memberships
--
-- Sensitive: knowing who holds which roles is part of the security surface.
-- Users see their own rows; admins see all; nobody else sees anything.
-- Only admins can mutate.
-- =========================================================================

create policy memberships_select_self on public.memberships
  for select to authenticated
  using (user_id = auth.uid());

create policy memberships_select_administrator on public.memberships
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy memberships_insert_administrator on public.memberships
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy memberships_update_administrator on public.memberships
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy memberships_delete_administrator on public.memberships
  for delete to authenticated
  using (public.active_role_is('administrator'));
