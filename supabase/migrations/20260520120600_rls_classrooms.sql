-- RLS policies: classrooms.
--
-- The instructor SELECT policy is intentionally strict: ONLY classrooms
-- where the instructor is the assigned teacher (instructor_id = auth.uid()).
-- site_instructors membership is the gate for INSERTing new classrooms,
-- not what they currently teach.
--
-- The cross-org integrity invariant (course.organization_id =
-- site.organization_id) is enforced by the trigger in migration
-- 20260520120000_schema.sql, not duplicated in policies — policies handle
-- authorization, the trigger handles data validity.

create policy classrooms_select_administrator on public.classrooms
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy classrooms_select_supervisor on public.classrooms
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy classrooms_select_instructor on public.classrooms
  for select to authenticated
  using (
    public.active_role_is('instructor')
    and instructor_id = auth.uid()
  );

create policy classrooms_select_student on public.classrooms
  for select to authenticated
  using (
    public.active_role_is('student')
    and id in (
      select public.user_enrolled_classroom_ids()
    )
  );

create policy classrooms_insert_supervisor on public.classrooms
  for insert to authenticated
  with check (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy classrooms_insert_instructor on public.classrooms
  for insert to authenticated
  with check (
    public.active_role_is('instructor')
    and instructor_id = auth.uid()
    and site_id in (
      select site_id from public.site_instructors where user_id = auth.uid()
    )
  );

create policy classrooms_insert_administrator on public.classrooms
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy classrooms_update_supervisor on public.classrooms
  for update to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  )
  with check (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

-- Instructor UPDATE: can edit their own classrooms but cannot reassign to
-- a different instructor (WITH CHECK keeps instructor_id pinned to self).
create policy classrooms_update_instructor on public.classrooms
  for update to authenticated
  using (
    public.active_role_is('instructor')
    and instructor_id = auth.uid()
  )
  with check (
    public.active_role_is('instructor')
    and instructor_id = auth.uid()
  );

create policy classrooms_update_administrator on public.classrooms
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy classrooms_delete_supervisor on public.classrooms
  for delete to authenticated
  using (
    public.active_role_is('supervisor')
    and site_id in (
      select public.user_supervised_site_ids()
    )
  );

create policy classrooms_delete_administrator on public.classrooms
  for delete to authenticated
  using (public.active_role_is('administrator'));
