import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';

const ROLE_PATH: Record<string, string> = {
  administrator: '/admin',
  supervisor: '/supervisor',
  instructor: '/instructor',
  student: '/student',
};

export default function HomePage() {
  const { user, activeRole } = useAuth();
  const path = activeRole ? ROLE_PATH[activeRole] : null;

  return (
    <section className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Welcome, {user?.email}</h1>
        <p className="mt-2 text-slate-600">
          This app demonstrates how role-based access is enforced by Postgres row-level
          security, not by the frontend. Use the role switcher above to play as a different
          role; the JWT changes and every query you see below is re-filtered by the database.
        </p>
      </div>

      <div className="rounded-lg border border-slate-200 bg-white p-5">
        <p className="text-sm text-slate-500">Currently active role</p>
        <p className="mt-1 text-xl font-medium capitalize">{activeRole ?? 'none assigned'}</p>
        {path && (
          <Link to={path} className="mt-3 inline-block text-sm text-slate-900 underline">
            Go to your {activeRole} view →
          </Link>
        )}
      </div>

      <div className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
        <p className="font-medium">Try this:</p>
        <p className="mt-1">
          Click any role in the top navigation. If you don't hold that role's membership,
          the page will load but every list will be empty — Postgres RLS filtered them out.
          Use the role switcher to actually adopt a role you have.
        </p>
      </div>
    </section>
  );
}
