-- Enable RLS on every public table. Tables with RLS enabled but no policies
-- deny everything by default — which is exactly what we want as a baseline.
-- The per-table policy migrations that follow grant carefully scoped access
-- back to each role.

alter table public.organizations     enable row level security;
alter table public.users             enable row level security;
alter table public.roles             enable row level security;
alter table public.memberships       enable row level security;
alter table public.sites             enable row level security;
alter table public.site_supervisors  enable row level security;
alter table public.site_instructors  enable row level security;
alter table public.courses           enable row level security;
alter table public.classrooms        enable row level security;
alter table public.enrollments       enable row level security;

-- =========================================================================
-- Auto-assign creator as site supervisor.
--
-- When a supervisor INSERTs a sites row, this trigger adds them to
-- site_supervisors for that new site. Without this, the creator would
-- immediately lose visibility of the site they just created (their
-- supervisor policies all filter by site_supervisors membership).
--
-- Skipped when the inserting user has no auth.uid() (e.g. admin-created
-- sites via service_role during seeding) — in that case the seed script
-- adds supervisors explicitly.
-- =========================================================================

create function public.auto_assign_site_creator_as_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    insert into public.site_supervisors (user_id, site_id)
    values (auth.uid(), new.id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger sites_auto_assign_supervisor
  after insert on public.sites
  for each row execute function public.auto_assign_site_creator_as_supervisor();
