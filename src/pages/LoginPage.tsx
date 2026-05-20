import { useState, type FormEvent } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { supabase } from '../lib/supabase';

const DEMO_USERS = [
  { email: 'admin@example.test', label: 'Alice (admin)' },
  { email: 'multi@example.test', label: 'Morgan (supervisor + instructor + student)' },
  { email: 'instructor@example.test', label: 'Ivan (instructor)' },
  { email: 'student1@example.test', label: 'Sam (student)' },
];

const DEMO_PASSWORD = 'Demo123!password';

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState(DEMO_PASSWORD);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const redirectTo = (location.state as { from?: string } | null)?.from ?? '/';

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
    setSubmitting(false);
    if (authError) {
      setError(authError.message);
      return;
    }
    navigate(redirectTo, { replace: true });
  }

  return (
    <section className="mx-auto max-w-md">
      <h1 className="text-2xl font-semibold">Sign in</h1>
      <p className="mt-2 text-slate-600">
        Use one of the seeded demo accounts below, or type your own credentials. The password
        for every seeded user is <code className="rounded bg-slate-200 px-1">{DEMO_PASSWORD}</code>.
      </p>

      <form onSubmit={handleSubmit} className="mt-6 space-y-4">
        <label className="block">
          <span className="text-sm font-medium text-slate-700">Email</span>
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 shadow-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
          />
        </label>

        <label className="block">
          <span className="text-sm font-medium text-slate-700">Password</span>
          <input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 shadow-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
          />
        </label>

        {error && (
          <div className="rounded-md bg-rose-50 px-3 py-2 text-sm text-rose-900">{error}</div>
        )}

        <button
          type="submit"
          disabled={submitting}
          className="w-full rounded-md bg-slate-900 px-3 py-2 text-sm font-medium text-white hover:bg-slate-800 disabled:opacity-50"
        >
          {submitting ? 'Signing in…' : 'Sign in'}
        </button>
      </form>

      <div className="mt-8 border-t border-slate-200 pt-6">
        <p className="text-sm font-medium text-slate-700">Demo accounts</p>
        <ul className="mt-2 space-y-1">
          {DEMO_USERS.map((u) => (
            <li key={u.email}>
              <button
                type="button"
                onClick={() => setEmail(u.email)}
                className="text-left text-sm text-slate-600 hover:text-slate-900 hover:underline"
              >
                {u.email} — {u.label}
              </button>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
