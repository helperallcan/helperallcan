import { getStatusLabel } from '@/lib/moderation';

export function StatusBadge({ value, label }: { value?: string | null; label?: string }) {
  return <span className={`status status-${value ?? 'none'}`}>{label ?? getStatusLabel(value)}</span>;
}
