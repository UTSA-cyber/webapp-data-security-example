import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session, User } from '@supabase/supabase-js';
import { useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';

export type ActiveRole = 'administrator' | 'supervisor' | 'instructor' | 'student';

interface AuthContextValue {
  session: Session | null;
  user: User | null;
  activeRole: ActiveRole | null;
  loading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const queryClient = useQueryClient();

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });

    const { data } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      // Login, logout, AND role switch all flow through here. Every query
      // depends on the JWT's active_role, so invalidate everything when
      // the session changes — TanStack Query will refetch under the new token.
      queryClient.invalidateQueries();
    });

    return () => data.subscription.unsubscribe();
  }, [queryClient]);

  const user = session?.user ?? null;
  const activeRole = (user?.app_metadata?.active_role ?? null) as ActiveRole | null;

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider value={{ session, user, activeRole, loading, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return ctx;
}
