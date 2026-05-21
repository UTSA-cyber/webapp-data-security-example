import type { ReactNode } from 'react';

interface Props {
  title: string;
  subtitle?: string;
  count?: number;
  isLoading?: boolean;
  error?: Error | null;
  emptyHint?: string;
  children: ReactNode;
}

export default function DataCard({
  title,
  subtitle,
  count,
  isLoading,
  error,
  emptyHint,
  children,
}: Props) {
  return (
    <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
      <header className="flex items-baseline justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold">{title}</h2>
          {subtitle && <p className="mt-0.5 text-sm text-slate-500">{subtitle}</p>}
        </div>
        {typeof count === 'number' && (
          <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">
            {count} {count === 1 ? 'row' : 'rows'}
          </span>
        )}
      </header>
      <div className="mt-4">
        {isLoading ? (
          <p className="text-sm text-slate-500">Loading…</p>
        ) : error ? (
          <p className="text-sm text-rose-900">Error: {error.message}</p>
        ) : count === 0 ? (
          <p className="text-sm text-slate-500">{emptyHint ?? 'No rows visible.'}</p>
        ) : (
          children
        )}
      </div>
    </section>
  );
}
