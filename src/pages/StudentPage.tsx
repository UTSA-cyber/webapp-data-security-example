import DataCard from '../components/DataCard';
import InvalidViewPane from '../components/InvalidViewPane';
import { useClassrooms, useCourses, useEnrollments, useSites } from '../hooks/useResources';

export default function StudentPage() {
  const courses = useCourses();
  const classrooms = useClassrooms();
  const enrollments = useEnrollments();
  const sites = useSites();

  return (
    <section className="space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Student view</h1>
        <p className="mt-1 text-sm text-slate-600">
          Per RLS: students see only the courses, classrooms, and enrollments tied to their own enrolled rows.
        </p>
      </header>

      <DataCard
        title="My courses"
        count={courses.data?.length}
        isLoading={courses.isLoading}
        error={courses.error as Error | null}
        emptyHint="No courses visible. If this is unexpected, your active role might not be 'student'."
      >
        <ul className="divide-y divide-slate-100">
          {courses.data?.map((c) => (
            <li key={c.id} className="py-2">
              <div className="font-medium">{c.course_number}</div>
              <div className="text-sm text-slate-500">{c.description}</div>
            </li>
          ))}
        </ul>
      </DataCard>

      <DataCard
        title="My classrooms"
        count={classrooms.data?.length}
        isLoading={classrooms.isLoading}
        error={classrooms.error as Error | null}
      >
        <ul className="divide-y divide-slate-100">
          {classrooms.data?.map((c) => (
            <li key={c.id} className="flex justify-between py-2">
              <div>
                <div className="font-medium">{c.name}</div>
                <div className="text-sm text-slate-500">
                  Instructor: {asScalarName(c.instructor)} · Site: {asScalarName(c.site)}
                </div>
              </div>
            </li>
          ))}
        </ul>
      </DataCard>

      <DataCard
        title="My enrollments"
        count={enrollments.data?.length}
        isLoading={enrollments.isLoading}
        error={enrollments.error as Error | null}
      >
        <ul className="divide-y divide-slate-100">
          {enrollments.data?.map((e) => (
            <li key={`${e.student_id}-${e.classroom_id}`} className="py-2 text-sm">
              {asScalarName(e.classroom)}
            </li>
          ))}
        </ul>
      </DataCard>

      <InvalidViewPane
        title="Attempting to read classrooms across all teachers"
        description="A student should not see classrooms they aren't enrolled in. The query the frontend ran asks Postgres for ALL classrooms; RLS filtered the response."
        table="classrooms"
        userCount={classrooms.data?.length}
      />

      <InvalidViewPane
        title="Attempting to read sites"
        description="Students have no SELECT policy on sites — the database returns nothing."
        table="sites"
        userCount={sites.data?.length}
      />
    </section>
  );
}

function asScalarName(rel: { name?: string; full_name?: string } | { name?: string; full_name?: string }[] | null) {
  if (!rel) return '—';
  const r = Array.isArray(rel) ? rel[0] : rel;
  return r?.name ?? r?.full_name ?? '—';
}
