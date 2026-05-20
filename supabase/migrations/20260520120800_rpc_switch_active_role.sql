-- RPC: switch_active_role(role_name)
--
-- The load-bearing piece of the role-switcher UX. Validates the calling
-- user actually holds the requested role membership, then writes
-- active_role into auth.users.raw_app_meta_data (which surfaces in the
-- JWT's app_metadata after a token refresh).
--
-- Required call order from the frontend:
--   1. supabase.rpc('switch_active_role', { role_name: 'instructor' })
--   2. supabase.auth.refreshSession()  -- pulls the new JWT
--   3. re-fetch role-scoped queries (TanStack Query invalidation)
--
-- Defense in depth: even though active_role_is() also re-checks the
-- membership in every policy, validating here prevents a stale claim from
-- ever entering the JWT in the first place.

create function public.switch_active_role(role_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'switch_active_role: no authenticated user'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1
    from public.memberships m
    join public.roles r on r.id = m.role_id
    where m.user_id = auth.uid()
      and r.name = role_name
  ) then
    raise exception 'switch_active_role: user does not hold role %', role_name
      using errcode = 'insufficient_privilege';
  end if;

  update auth.users
  set raw_app_meta_data =
    coalesce(raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('active_role', role_name)
  where id = auth.uid();
end;
$$;

revoke all on function public.switch_active_role(text) from public;
grant execute on function public.switch_active_role(text) to authenticated;
