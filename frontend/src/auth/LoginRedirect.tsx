import { Navigate } from 'react-router-dom';
import LoginPage from '../pages/LoginPage';
import { useAuth } from './AuthProvider';

// If an authenticated user lands on /login, send them home instead of
// re-rendering the form.
export default function LoginRedirect() {
  const { session, loading } = useAuth();
  if (loading) return null;
  if (session) return <Navigate to="/" replace />;
  return <LoginPage />;
}
