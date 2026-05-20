import { useMutation } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';
import type { ActiveRole } from '../auth/AuthProvider';

// Two-step role switch: RPC validates membership and writes the JWT claim,
// then refreshSession pulls a new token. AuthProvider.onAuthStateChange
// fires after the refresh and invalidates all queries — fetches under the
// new role's RLS happen automatically from there.
export function useSwitchActiveRole() {
  return useMutation({
    mutationFn: async (roleName: ActiveRole) => {
      const { error: rpcError } = await supabase.rpc('switch_active_role', {
        role_name: roleName,
      });
      if (rpcError) throw rpcError;

      const { error: refreshError } = await supabase.auth.refreshSession();
      if (refreshError) throw refreshError;
    },
  });
}
