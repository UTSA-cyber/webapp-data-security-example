import { useAdminRowCount } from '../hooks/useResources';

interface Props {
  title: string;
  description: string;
  table: string;
  userCount: number | undefined;
}

// SELECT denials in Postgres RLS are silent — they return empty rows, not
// errors. This component surfaces the silence by comparing the row count
// the current role sees to the count an administrator would see for the
// same query. The gap is the pedagogical evidence that the database
// filtered the result.
export default function InvalidViewPane({ title, description, table, userCount }: Props) {
  const { data: adminCount, isLoading, error } = useAdminRowCount(table);
  const userN = userCount ?? 0;
  const adminN = adminCount ?? 0;
  const hidden = Math.max(adminN - userN, 0);

  return (
    <section className="rounded-lg border-2 border-dashed border-rose-300 bg-rose-50 p-5">
      <header className="flex items-baseline justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-rose-900">{title}</h2>
          <p className="mt-0.5 text-sm text-rose-800">{description}</p>
        </div>
        <span className="rounded-full bg-rose-200 px-2 py-0.5 text-xs font-medium text-rose-900">
          invalid view
        </span>
      </header>
      <div className="mt-4 space-y-2 text-sm">
        {isLoading ? (
          <p className="text-rose-800">Measuring…</p>
        ) : error ? (
          <p className="text-rose-900">Error measuring admin row count: {error.message}</p>
        ) : (
          <>
            <p>
              <span className="text-rose-800">You see </span>
              <span className="font-mono font-semibold text-rose-900">{userN}</span>
              <span className="text-rose-800"> row{userN === 1 ? '' : 's'}.</span>
            </p>
            <p>
              <span className="text-rose-800">An administrator sees </span>
              <span className="font-mono font-semibold text-rose-900">{adminN}</span>
              <span className="text-rose-800"> row{adminN === 1 ? '' : 's'} in <code>{table}</code>.</span>
            </p>
            {hidden > 0 ? (
              <p className="mt-2 rounded bg-rose-200/60 px-3 py-2 text-rose-900">
                <strong className="font-mono">{hidden}</strong> row{hidden === 1 ? ' was' : 's were'}{' '}
                filtered out by Postgres row-level security. The frontend made the same query
                an administrator would have — the database is what made the difference.
              </p>
            ) : (
              <p className="mt-2 text-rose-800">
                No rows are being hidden right now. Switch to a role without access to{' '}
                <code>{table}</code> to see the gap.
              </p>
            )}
          </>
        )}
      </div>
    </section>
  );
}
