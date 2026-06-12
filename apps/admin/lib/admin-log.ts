import { adminSupabase } from './supabase/admin';

export async function writeAdminLog(input: {
  adminId: string;
  action: string;
  entityType: string;
  entityId?: string | null;
  details?: Record<string, unknown>;
}) {
  const { error } = await adminSupabase.from('admin_logs').insert({
    admin_id: input.adminId,
    action: input.action,
    entity_type: input.entityType,
    entity_id: input.entityId ?? null,
    details: input.details ?? {}
  });

  if (error) {
    throw new Error(`Failed to write admin log: ${error.message}`);
  }
}
