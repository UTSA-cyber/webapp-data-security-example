import DataCard from '../components/DataCard';
import {
  useClassrooms,
  useCourses,
  useEnrollments,
  useSites,
  useUsers,
} from '../hooks/useResources';

export default function SupervisorPage() {
  const sites = useSites();
  const classrooms = useClassrooms();
  const courses = useCourses();
  const enrollments = useEnrollments();
  const users = useUsers();

  return (
    <section className="space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Supervisor view</h1>
        <p className="mt-1 text-sm text-slate-600">
          Per RLS: supervisors see the sites they supervise plus all classrooms, instructors,
          and enrollments that descend from those sites. Courses are visible org-wide.
        </p>
      </header>

      <DataCard
        title="Sites I supervise"
        count={sites.data?.length}
        isLoading={sites.isLoading}
        error={sites.error as Error | null}
      >
        <ul className="divide-y divide-slate-100">
          {sites.data?.map((s) => (
            <li key={s.id} className="py-2">
              <div className="font-medium">{s.name}</div>
              <div className="text-sm text-slate-500">
                {s.address ?? 'no address'} · {asScalarName(s.organization)}
              </div>
            </li>
          ))}
        </ul>
      </DataCard>

      <DataCard
        title="Courses in my org"
        count={courses.data?.length}
        isLoading={courses.isLoading}
        error={courses.error as Error | null}
      >
        <ul className="divide-y divide-slate-100">
          {courses.data?.map((c) => (
            <li key={c.id} className="py-2 text-sm">
              <span className="font-medium">{c.course_number}</span>{' '}
              <span className="text-slate-500">— {c.description}</span>
            </li>
          ))}
        </ul>
      </DataCard>

      <DataCard
        title="Classrooms at my sites"
        count={classrooms.data?.length}
        isLoading={classrooms.isLoading}
        error={classrooms.error as Error | null}
      >
        <ul className="divide-y divide-slate-100">
          {classrooms.data?.map((c) => (
            <li key={c.id} className="py-2">
              <div className="font-medium">{c.name}</div>
              <div className="text-sm text-slate-500">
                Instructor: {asScalarName(c.instructor, 'full_name')} · Site: {asScalarName(c.site)}
              </div>
            </li>
          ))}
        </ul>
      </DataCard>

      <DataCard
        title="Enrollments at my sites"
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

      <DataCard
        title="Users I can see"
        count={users.data?.length}
        isLoading={users.isLoading}
        error={users.error as Error | null}
        subtitle="Co-supervisors, instructors at my sites, and enrolled students"
      >
        <ul className="divide-y divide-slate-100">
          {users.data?.map((u) => (
            <li key={u.id} className="py-2 text-sm">
              {u.full_name}
            </li>
          ))}
        </ul>
      </DataCard>
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
