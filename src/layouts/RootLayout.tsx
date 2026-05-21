import { Link, Outlet } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import RoleSwitcher from '../components/RoleSwitcher';

export default function RootLayout() {
  const { user, signOut } = useAuth();

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-6 px-6 py-3">
          <Link to="/" className="text-base font-semibold whitespace-nowrap">
            Data Security Example
          </Link>
          <div className="flex items-center gap-3">
            <RoleSwitcher />
            <div className="hidden text-xs text-slate-500 sm:block">{user?.email}</div>
            <button
              type="button"
              onClick={signOut}
              className="text-sm text-slate-600 hover:text-slate-900 hover:underline"
            >
              Sign out
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-6 py-8">
        <Outlet />
      </main>
    </div>
  );
}
