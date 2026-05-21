import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { useAuth, type ActiveRole } from '../auth/AuthProvider';
import { useMemberships } from '../hooks/useMemberships';
import { useSwitchActiveRole } from '../hooks/useSwitchActiveRole';
import { useToast } from './ToastProvider';

const ALL_ROLES: ActiveRole[] = ['administrator', 'supervisor', 'instructor', 'student'];

const ROLE_LABEL: Record<ActiveRole, string> = {
  administrator: 'Administrator',
  supervisor: 'Supervisor',
  instructor: 'Instructor',
  student: 'Student',
};

export default function RoleSwitcher() {
  const { activeRole } = useAuth();
  const { data: memberships, isLoading } = useMemberships();
  const switchRole = useSwitchActiveRole();
  const toast = useToast();

  if (isLoading || !memberships) {
    return <span className="text-sm text-slate-500">Loading roles…</span>;
  }

  const heldRoles = new Set(memberships);

  async function handleSelect(role: ActiveRole) {
    if (role === activeRole) return;
    try {
      await switchRole.mutateAsync(role);
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
          className="min-w-[16rem] rounded-md border border-slate-200 bg-white p-1 shadow-lg"
        >
          <DropdownMenu.Label className="px-2 py-1.5 text-xs uppercase tracking-wide text-slate-500">
            Roles
          </DropdownMenu.Label>
          {ALL_ROLES.map((role) => {
            const isHeld = heldRoles.has(role);
            const isActive = role === activeRole;
            return (
              <DropdownMenu.Item
                key={role}
                disabled={!isHeld}
                onSelect={() => isHeld && handleSelect(role)}
                className={`rounded-sm px-2 py-1.5 text-sm outline-none ${
                  isHeld
                    ? 'cursor-pointer text-slate-900 data-[highlighted]:bg-slate-100'
                    : 'cursor-not-allowed text-slate-400'
                }`}
              >
                <span className="flex items-center justify-between gap-4">
                  <span>{ROLE_LABEL[role]}</span>
                  {isActive ? (
                    <span className="text-xs text-emerald-700">active</span>
                  ) : !isHeld ? (
                    <span className="text-xs italic text-slate-400">no access</span>
                  ) : null}
                </span>
              </DropdownMenu.Item>
            );
          })}
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  );
}
