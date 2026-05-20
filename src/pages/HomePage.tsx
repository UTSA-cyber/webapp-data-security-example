export default function HomePage() {
  return (
    <section>
      <h1 className="text-2xl font-semibold">Welcome</h1>
      <p className="mt-2 text-slate-600">
        This app demonstrates how role-based access is enforced by Postgres RLS, not by the
        frontend. Pick a role from the nav to see what that role can read.
      </p>
    </section>
  );
}
