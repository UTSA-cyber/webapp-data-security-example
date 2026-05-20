-- Core schema for the data security example.
-- RLS is intentionally NOT enabled here; that happens in a later migration
-- alongside policies, so the data shape can be reviewed independently.

-- =========================================================================
-- Reference tables
-- =========================================================================

create table public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now()
);

create table public.users (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null,
  created_at  timestamptz not null default now()
);

create table public.roles (
  id    smallint primary key,
  name  text not null unique
);

insert into public.roles (id, name) values
  (1, 'administrator'),
  (2, 'supervisor'),
  (3, 'instructor'),
  (4, 'student');

create table public.memberships (
  user_id     uuid not null references public.users (id) on delete cascade,
  role_id     smallint not null references public.roles (id),
  created_at  timestamptz not null default now(),
  primary key (user_id, role_id)
);

-- =========================================================================
-- Sites + people-at-sites joins
-- =========================================================================

create table public.sites (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  name             text not null,
  address          text,
  created_at       timestamptz not null default now()
);

create table public.site_supervisors (
  user_id     uuid not null references public.users (id) on delete cascade,
  site_id     uuid not null references public.sites (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, site_id)
);

create table public.site_instructors (
  user_id     uuid not null references public.users (id) on delete cascade,
  site_id     uuid not null references public.sites (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, site_id)
);

-- =========================================================================
-- Courses (org-scoped) and classrooms (the runtime instance of a course)
-- =========================================================================

create table public.courses (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  course_number    text not null,
  description      text,
  created_at       timestamptz not null default now(),
  unique (organization_id, course_number)
);

create table public.classrooms (
  id             uuid primary key default gen_random_uuid(),
  site_id        uuid not null references public.sites (id) on delete restrict,
  course_id      uuid not null references public.courses (id) on delete restrict,
  instructor_id  uuid not null references public.users (id) on delete restrict,
  name           text,
  created_at     timestamptz not null default now()
);

create table public.enrollments (
  student_id    uuid not null references public.users (id) on delete cascade,
  classroom_id  uuid not null references public.classrooms (id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (student_id, classroom_id)
);

-- =========================================================================
-- Cross-org integrity: a classroom's course and site must share an org.
-- Why a trigger and not a CHECK: the constraint spans two parent rows, so it
-- can't be expressed in a single-row CHECK without denormalizing organization_id
-- onto classrooms. Trigger keeps the invariant honest at write time.
-- =========================================================================

create function public.enforce_classroom_org_integrity()
returns trigger
language plpgsql
as $$
declare
  site_org  uuid;
  course_org uuid;
begin
  select organization_id into site_org   from public.sites   where id = new.site_id;
  select organization_id into course_org from public.courses where id = new.course_id;

  if site_org is distinct from course_org then
    raise exception
      'classroom % rejected: site (org %) and course (org %) belong to different organizations',
      new.id, site_org, course_org
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger classrooms_org_integrity
  before insert or update of site_id, course_id on public.classrooms
  for each row execute function public.enforce_classroom_org_integrity();

-- =========================================================================
-- Indexes to support RLS traversals.
-- Composite PKs cover the user_id-prefix lookups for free; the indexes below
-- are the reverse-direction lookups RLS subqueries need.
-- =========================================================================

create index sites_organization_id_idx       on public.sites (organization_id);
create index courses_organization_id_idx     on public.courses (organization_id);
create index site_supervisors_site_id_idx    on public.site_supervisors (site_id);
create index site_instructors_site_id_idx    on public.site_instructors (site_id);
create index classrooms_site_id_idx          on public.classrooms (site_id);
create index classrooms_course_id_idx        on public.classrooms (course_id);
create index classrooms_instructor_id_idx    on public.classrooms (instructor_id);
create index enrollments_classroom_id_idx    on public.enrollments (classroom_id);
