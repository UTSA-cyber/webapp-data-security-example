import { Navigate, useLocation } from 'react-router-dom';
import RootLayout from '../layouts/RootLayout';
import { useAuth } from './AuthProvider';

export default function ProtectedLayout() {
  const { session, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return <div className="p-8 text-slate-500">Loading…</div>;
  }
  if (!session) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }
  return <RootLayout />;
}
