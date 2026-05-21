import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';
import { useAuth, type ActiveRole } from '../auth/AuthProvider';

interface MembershipRow {
  role_id: number;
  roles: { name: ActiveRole } | { name: ActiveRole }[] | null;
}

export function useMemberships() {
  const { user } = useAuth();

  return useQuery({
    queryKey: ['memberships', user?.id],
    enabled: !!user,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('memberships')
        .select('role_id, roles(name)')
        .eq('user_id', user!.id)
        .order('role_id');
      if (error) throw error;
      const rows = (data ?? []) as MembershipRow[];
      // Supabase returns the joined relation as either a single object or an
      // array depending on FK cardinality detection; normalize to a flat list
      // of role names.
      return rows
        .map((r) => {
          const rel = r.roles;
          if (!rel) return null;
          return Array.isArray(rel) ? rel[0]?.name : rel.name;
        })
        .filter((name): name is ActiveRole => !!name);
    },
  });
}
