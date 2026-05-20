import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { useNavigate } from 'react-router-dom';
import { useAuth, type ActiveRole } from '../auth/AuthProvider';
import { useMemberships } from '../hooks/useMemberships';
import { useSwitchActiveRole } from '../hooks/useSwitchActiveRole';
import { useToast } from './ToastProvider';

const ROLE_LABEL: Record<ActiveRole, string> = {
  administrator: 'Administrator',
  supervisor: 'Supervisor',
  instructor: 'Instructor',
  student: 'Student',
};

const ROLE_PATH: Record<ActiveRole, string> = {
  administrator: '/admin',
  supervisor: '/supervisor',
  instructor: '/instructor',
  student: '/student',
};

export default function RoleSwitcher() {
  const { activeRole } = useAuth();
  const navigate = useNavigate();
  const { data: memberships, isLoading } = useMemberships();
  const switchRole = useSwitchActiveRole();
  const toast = useToast();

  if (isLoading || !memberships) {
    return <span className="text-sm text-slate-500">Loading roles…</span>;
  }

  async function handleSelect(role: ActiveRole) {
    if (role === activeRole) {
      navigate(ROLE_PATH[role]);
      return;
    }
    try {
      await switchRole.mutateAsync(role);
      navigate(ROLE_PATH[role]);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      toast.show({
        tone: 'error',
        title: `Could not switch to ${ROLE_LABEL[role]}`,
        description: message,
      });
    }
  }

  const current = activeRole ? ROLE_LABEL[activeRole] : 'No role';

  return (
    <DropdownMenu.Root>
      <DropdownMenu.Trigger asChild>
        <button
          className="inline-flex items-center gap-2 rounded-md border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-900 hover:bg-slate-50"
          disabled={switchRole.isPending}
        >
          <span className="text-slate-500">Active role:</span>
          <span>{switchRole.isPending ? 'Switching…' : current}</span>
          <span aria-hidden className="text-slate-400">▾</span>
        </button>
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content
          align="end"
          sideOffset={6}
          className="min-w-[14rem] rounded-md border border-slate-200 bg-white p-1 shadow-lg"
        >
          <DropdownMenu.Label className="px-2 py-1.5 text-xs uppercase tracking-wide text-slate-500">
            Your memberships
          </DropdownMenu.Label>
          {memberships.map((role) => (
            <DropdownMenu.Item
              key={role}
              onSelect={() => handleSelect(role)}
              className="cursor-pointer rounded-sm px-2 py-1.5 text-sm text-slate-900 outline-none data-[highlighted]:bg-slate-100"
            >
              <span className="flex items-center justify-between gap-4">
                {ROLE_LABEL[role]}
                {role === activeRole && (
                  <span className="text-xs text-slate-500">active</span>
                )}
              </span>
            </DropdownMenu.Item>
          ))}
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  );
}
