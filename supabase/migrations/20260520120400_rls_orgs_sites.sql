-- RLS policies: organizations, sites, site_supervisors, site_instructors.
--
-- Pedagogical note: the "sites" table is one of the two invalid-view targets
-- (instructor pane attempts to read it). The instructor and student roles
-- get NO SELECT policy here, so RLS returns zero rows for them — the
-- demonstration's silent-denial moment.

-- =========================================================================
-- organizations
--
-- Anyone transitively connected to an org (via site_supervisors,
-- site_instructors, or an enrolled classroom) can read the org row. The
-- org name is metadata; the sensitive scoping is at the site level below.
-- =========================================================================

create policy organizations_select_administrator on public.organizations
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy organizations_select_supervisor on public.organizations
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and id in (
      select s.organization_id
      from public.sites s
      join public.site_supervisors ss on ss.site_id = s.id
      where ss.user_id = auth.uid()
    )
  );

create policy organizations_select_instructor on public.organizations
  for select to authenticated
  using (
    public.active_role_is('instructor')
    and id in (
      select s.organization_id
      from public.sites s
      join public.site_instructors si on si.site_id = s.id
      where si.user_id = auth.uid()
    )
  );

create policy organizations_select_student on public.organizations
  for select to authenticated
  using (
    public.active_role_is('student')
    and id in (
      select s.organization_id
      from public.sites s
      join public.classrooms c on c.site_id = s.id
      join public.enrollments e on e.classroom_id = c.id
      where e.student_id = auth.uid()
    )
  );

create policy organizations_insert_administrator on public.organizations
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy organizations_update_administrator on public.organizations
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy organizations_delete_administrator on public.organizations
  for delete to authenticated
  using (public.active_role_is('administrator'));

-- =========================================================================
-- sites
--
-- The instructor "invalid view" lives here: there is intentionally NO
-- instructor SELECT policy. The trigger from migration 20260520120200
-- auto-assigns the supervisor creator into site_supervisors after INSERT.
-- =========================================================================

create policy sites_select_administrator on public.sites
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy sites_select_supervisor on public.sites
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and id in (
      select public.user_supervised_site_ids()
    )
  );

create policy sites_insert_supervisor on public.sites
  for insert to authenticated
  with check (public.active_role_is('supervisor'));

create policy sites_insert_administrator on public.sites
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy sites_update_supervisor on public.sites
  for update to authenticated
  using (
    public.active_role_is('supervisor')
    and id in (
      select public.user_supervised_site_ids()
    )
  )
  with check (
    public.active_role_is('supervisor')
    and id in (
      select public.user_supervised_site_ids()
    )
  );

create policy sites_update_administrator on public.sites
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy sites_delete_administrator on public.sites
  for delete to authenticated
  using (public.active_role_is('administrator'));

-- =========================================================================
-- site_supervisors
--
-- Supervisors can add and remove co-supervisors for sites they themselves
-- supervise (Q2-b decision). Self carve-out so any user can see their own
-- assignments — needed for the supervisor UI to know which sites are theirs.
-- =========================================================================

create policy site_supervisors_select_self on public.site_supervisors
  for select to authenticated
  using (user_id = auth.uid());

create policy site_supervisors_select_administrator on public.site_supervisors
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy site_supervisors_select_supervisor on public.site_supervisors
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy site_supervisors_insert_supervisor on public.site_supervisors
  for insert to authenticated
  with check (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy site_supervisors_insert_administrator on public.site_supervisors
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy site_supervisors_delete_supervisor on public.site_supervisors
  for delete to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy site_supervisors_delete_administrator on public.site_supervisors
  for delete to authenticated
  using (public.active_role_is('administrator'));

-- =========================================================================
-- site_instructors
--
-- Supervisors of a site manage its instructor roster. Self carve-out so an
-- instructor can see which sites they're assigned to (for their own UI).
-- =========================================================================

create policy site_instructors_select_self on public.site_instructors
  for select to authenticated
  using (user_id = auth.uid());

create policy site_instructors_select_administrator on public.site_instructors
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy site_instructors_select_supervisor on public.site_instructors
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy site_instructors_insert_supervisor on public.site_instructors
  for insert to authenticated
  with check (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy site_instructors_insert_administrator on public.site_instructors
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy site_instructors_delete_supervisor on public.site_instructors
  for delete to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy site_instructors_delete_administrator on public.site_instructors
  for delete to authenticated
  using (public.active_role_is('administrator'));
