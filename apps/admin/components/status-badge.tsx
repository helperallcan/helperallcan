import { getStatusLabel } from '@/lib/moderation';

export function StatusBadge({ value }: { value?: string | null }) {
  return <span className={`status status-${value ?? 'none'}`}>{getStatusLabel(value)}</span>;
}
