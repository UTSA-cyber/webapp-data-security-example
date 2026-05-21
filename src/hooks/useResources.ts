import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/AuthProvider';

// Each hook keys its cache by (resource, user.id, activeRole) so that
// switching roles serves a fresh cache slot. AuthProvider already invalidates
// all queries on session change, so this scoping is belt-and-suspenders for
// future code that might rely on caching across role-switches.
function useRoleScopedKey(resource: string, extra: unknown[] = []) {
  const { user, activeRole } = useAuth();
  return [resource, user?.id, activeRole, ...extra] as const;
}

export function useOrganizations() {
  return useQuery({
    queryKey: useRoleScopedKey('organizations'),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('organizations')
        .select('id, name')
        .order('name');
      if (error) throw error;
      return data;
    },
  });
}

export function useSites() {
  return useQuery({
    queryKey: useRoleScopedKey('sites'),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('sites')
        .select('id, name, address, organization:organizations(name)')
        .order('name');
      if (error) throw error;
      return data;
    },
  });
}

export function useCourses() {
  return useQuery({
    queryKey: useRoleScopedKey('courses'),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('courses')
        .select('id, course_number, description, organization:organizations(name)')
        .order('course_number');
      if (error) throw error;
      return data;
    },
  });
}

export function useClassrooms() {
  return useQuery({
    queryKey: useRoleScopedKey('classrooms'),
    queryFn: async () => {
      // !instructor_id disambiguates: from classrooms there are two paths
      // to users (direct via instructor_id, and M2M through enrollments
      // which PostgREST detects as a junction table from its composite PK).
      const { data, error } = await supabase
        .from('classrooms')
        .select(`
          id,
          name,
          course:courses(course_number),
          site:sites(name),
          instructor:users!instructor_id(full_name)
        `)
        .order('name');
      if (error) throw error;
      return data;
    },
  });
}

export function useEnrollments() {
  return useQuery({
    queryKey: useRoleScopedKey('enrollments'),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('enrollments')
        .select(`
          student_id,
          classroom_id,
          student:users(full_name),
          classroom:classrooms(name)
        `);
      if (error) throw error;
      return data;
    },
  });
}

export function useUsers() {
  return useQuery({
    queryKey: useRoleScopedKey('users'),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('users')
        .select('id, full_name')
        .order('full_name');
      if (error) throw error;
      return data;
    },
  });
}

// admin_row_count powers the invalid-view diff. It's a SECURITY DEFINER RPC
// that ignores RLS, so the count it returns is the "would be visible to an
// administrator" number — the upper bound the user's view is being filtered
// from.
export function useAdminRowCount(table: string) {
  return useQuery({
    queryKey: useRoleScopedKey('admin_row_count', [table]),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_row_count', { table_name: table });
      if (error) throw error;
      return data as number;
    },
  });
}
