import DataCard from '../components/DataCard';
import InvalidViewPane from '../components/InvalidViewPane';
import { useClassrooms, useEnrollments, useSites } from '../hooks/useResources';

export default function InstructorPage() {
  const classrooms = useClassrooms();
  const enrollments = useEnrollments();
  const sites = useSites();

  return (
    <section className="space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Instructor view</h1>
        <p className="mt-1 text-sm text-slate-600">
          Per RLS: instructors see classrooms where they are the assigned teacher, and the enrollments in those classrooms.
        </p>
      </header>

      <DataCard
        title="Classrooms I teach"
        count={classrooms.data?.length}
        isLoading={classrooms.isLoading}
        error={classrooms.error as Error | null}
        emptyHint="No classrooms visible. If unexpected, switch active role to 'instructor'."
      >
        <ul className="divide-y divide-slate-100">
          {classrooms.data?.map((c) => (
            <li key={c.id} className="py-2">
              <div className="font-medium">{c.name}</div>
              <div className="text-sm text-slate-500">
                Site: {asScalarName(c.site)} · Course: {asScalarName(c.course, 'course_number')}
              </div>
            </li>
          ))}
        </ul>
      </DataCard>

      <DataCard
        title="Students in my classrooms"
        count={enrollments.data?.length}
        isLoading={enrollments.isLoading}
        error={enrollments.error as Error | null}
      >
        <ul className="divide-y divide-slate-100">
          {enrollments.data?.map((e) => (
            <li key={`${e.student_id}-${e.classroom_id}`} className="flex justify-between py-2 text-sm">
              <span>{asScalarName(e.student, 'full_name')}</span>
              <span className="text-slate-500">{asScalarName(e.classroom)}</span>
            </li>
          ))}
        </ul>
      </DataCard>

      <InvalidViewPane
        title="Attempting to read sites"
        description="Instructors have no SELECT policy on sites. This is the explicit demonstration from the spec: the database returns zero rows, no error — RLS just silently filters."
        table="sites"
        userCount={sites.data?.length}
      />
    </section>
  );
}

function asScalarName(
  rel: Record<string, unknown> | Record<string, unknown>[] | null,
  field: 'name' | 'full_name' | 'course_number' = 'name',
) {
  if (!rel) return '—';
  const r = Array.isArray(rel) ? rel[0] : rel;
  return (r?.[field] as string | undefined) ?? '—';
}
