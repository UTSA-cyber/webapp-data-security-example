import { useAuth } from '../auth/AuthProvider';
import StudentView from '../views/StudentView';
import InstructorView from '../views/InstructorView';
import SupervisorView from '../views/SupervisorView';
import AdministratorView from '../views/AdministratorView';

// The single landing page after login. What's rendered is purely a function
// of the user's active role — there are no per-role URLs. Switching roles
// via the dropdown re-renders this page with the matching view. That visual
// in-place swap is the demonstration: role determines view, not URL.
export default function Dashboard() {
  const { activeRole } = useAuth();

  switch (activeRole) {
    case 'administrator':
      return <AdministratorView />;
    case 'supervisor':
      return <SupervisorView />;
    case 'instructor':
      return <InstructorView />;
    case 'student':
      return <StudentView />;
    default:
      return <NoRoleAssigned />;
  }
}

function NoRoleAssigned() {
  return (
    <section className="rounded-lg border border-slate-200 bg-white p-6">
      <h1 className="text-xl font-semibold">No role assigned</h1>
      <p className="mt-2 text-sm text-slate-600">
        Your account has no role membership yet. An administrator needs to assign you one
        before you can see any data.
      </p>
    </section>
  );
}
