import { Link, NavLink, Outlet } from 'react-router-dom';

const navItem =
  'rounded-md px-3 py-1.5 text-sm font-medium transition-colors hover:bg-slate-200';
const navItemActive = 'bg-slate-900 text-white hover:bg-slate-900';

export default function RootLayout() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-3">
          <Link to="/" className="text-base font-semibold">
            Data Security Example
          </Link>
          <nav className="flex gap-1">
            <NavLink
              to="/student"
              className={({ isActive }) => `${navItem} ${isActive ? navItemActive : ''}`}
            >
              Student
            </NavLink>
            <NavLink
              to="/instructor"
              className={({ isActive }) => `${navItem} ${isActive ? navItemActive : ''}`}
            >
              Instructor
            </NavLink>
            <NavLink
              to="/supervisor"
              className={({ isActive }) => `${navItem} ${isActive ? navItemActive : ''}`}
            >
              Supervisor
            </NavLink>
            <NavLink
              to="/admin"
              className={({ isActive }) => `${navItem} ${isActive ? navItemActive : ''}`}
            >
              Admin
            </NavLink>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-6 py-8">
        <Outlet />
      </main>
    </div>
  );
}
