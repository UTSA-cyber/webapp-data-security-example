-- RLS policies: courses.
--
-- Courses are organization-scoped. Supervisor reach is "any org I supervise
-- at least one site in" — the union of orgs across my site_supervisors rows.
-- Students see the courses for classrooms they're enrolled in; instructors
-- see courses they teach (via classrooms.instructor_id).

create policy courses_select_administrator on public.courses
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy courses_select_supervisor on public.courses
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and organization_id in (
      select s.organization_id
      from public.sites s
      join public.site_supervisors ss on ss.site_id = s.id
      where ss.user_id = auth.uid()
    )
  );

create policy courses_select_instructor on public.courses
  for select to authenticated
  using (
    public.active_role_is('instructor')
    and id in (
      select c.course_id
      from public.classrooms c
      where c.instructor_id = auth.uid()
    )
  );

create policy courses_select_student on public.courses
  for select to authenticated
  using (
    public.active_role_is('student')
    and id in (
      select c.course_id
      from public.classrooms c
      join public.enrollments e on e.classroom_id = c.id
      where e.student_id = auth.uid()
    )
  );

create policy courses_insert_supervisor on public.courses
  for insert to authenticated
  with check (
    public.active_role_is('supervisor')
    and organization_id in (
      select s.organization_id
      from public.sites s
      join public.site_supervisors ss on ss.site_id = s.id
      where ss.user_id = auth.uid()
    )
  );

create policy courses_insert_administrator on public.courses
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy courses_update_supervisor on public.courses
  for update to authenticated
  using (
    public.active_role_is('supervisor')
    and organization_id in (
      select s.organization_id
      from public.sites s
      join public.site_supervisors ss on ss.site_id = s.id
      where ss.user_id = auth.uid()
    )
  )
  with check (
    public.active_role_is('supervisor')
    and organization_id in (
      select s.organization_id
      from public.sites s
      join public.site_supervisors ss on ss.site_id = s.id
      where ss.user_id = auth.uid()
    )
  );

create policy courses_update_administrator on public.courses
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy courses_delete_supervisor on public.courses
  for delete to authenticated
  using (
    public.active_role_is('supervisor')
    and organization_id in (
      select s.organization_id
      from public.sites s
      join public.site_supervisors ss on ss.site_id = s.id
      where ss.user_id = auth.uid()
    )
  );

create policy courses_delete_administrator on public.courses
  for delete to authenticated
  using (public.active_role_is('administrator'));
