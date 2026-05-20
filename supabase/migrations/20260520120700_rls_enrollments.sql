-- RLS policies: enrollments.
--
-- Students see their own enrollments. Instructors see enrollments in
-- classrooms they teach. Supervisors see enrollments across sites they
-- supervise. Mutations follow the same scoping per role.

create policy enrollments_select_student on public.enrollments
  for select to authenticated
  using (
    public.active_role_is('student')
    and student_id = auth.uid()
  );

create policy enrollments_select_instructor on public.enrollments
  for select to authenticated
  using (
    public.active_role_is('instructor')
    and classroom_id in (
      select public.user_taught_classroom_ids()
    )
  );

create policy enrollments_select_supervisor on public.enrollments
  for select to authenticated
  using (
    public.active_role_is('supervisor')
    and classroom_id in (
      select c.id
      from public.classrooms c
      where c.site_id in (
        select public.user_supervised_site_ids()
      )
    )
  );

create policy enrollments_select_administrator on public.enrollments
  for select to authenticated
  using (public.active_role_is('administrator'));

create policy enrollments_insert_instructor on public.enrollments
  for insert to authenticated
  with check (
    public.active_role_is('instructor')
    and classroom_id in (
      select public.user_taught_classroom_ids()
    )
  );

create policy enrollments_insert_supervisor on public.enrollments
  for insert to authenticated
  with check (
    public.active_role_is('supervisor')
    and classroom_id in (
      select c.id
      from public.classrooms c
      where c.site_id in (
        select public.user_supervised_site_ids()
      )
    )
  );

create policy enrollments_insert_administrator on public.enrollments
  for insert to authenticated
  with check (public.active_role_is('administrator'));

create policy enrollments_update_instructor on public.enrollments
  for update to authenticated
  using (
    public.active_role_is('instructor')
    and classroom_id in (
      select public.user_taught_classroom_ids()
    )
  )
  with check (
    public.active_role_is('instructor')
    and classroom_id in (
      select public.user_taught_classroom_ids()
    )
  );

create policy enrollments_update_supervisor on public.enrollments
  for update to authenticated
  using (
    public.active_role_is('supervisor')
    and classroom_id in (
      select c.id
      from public.classrooms c
      where c.site_id in (
        select public.user_supervised_site_ids()
      )
    )
  )
  with check (
    public.active_role_is('supervisor')
    and classroom_id in (
      select c.id
      from public.classrooms c
      where c.site_id in (
        select public.user_supervised_site_ids()
      )
    )
  );

create policy enrollments_update_administrator on public.enrollments
  for update to authenticated
  using (public.active_role_is('administrator'))
  with check (public.active_role_is('administrator'));

create policy enrollments_delete_instructor on public.enrollments
  for delete to authenticated
  using (
    public.active_role_is('instructor')
    and classroom_id in (
      select public.user_taught_classroom_ids()
    )
  );

create policy enrollments_delete_supervisor on public.enrollments
  for delete to authenticated
  using (
    public.active_role_is('supervisor')
    and classroom_id in (
      select c.id
      from public.classrooms c
      where c.site_id in (
        select public.user_supervised_site_ids()
      )
    )
  );

create policy enrollments_delete_administrator on public.enrollments
  for delete to authenticated
  using (public.active_role_is('administrator'));
