'use server';

import { revalidatePath } from 'next/cache';

import { writeAdminLog } from '@/lib/admin-log';
import { requireAdmin, type AdminProfile } from '@/lib/auth';
import {
  banUserSchema,
  canApplyReportEnforcement,
  categorySchema,
  getReportEnforcementLabel,
  getStatusLabel,
  reportEnforcementSchema,
  reportSchema,
  taskStatusSchema,
  verificationSchema,
  type ReportStatusValue,
  type ReportEnforcementValue,
  type TaskStatusValue
} from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

type MutationResult<T = unknown> = PromiseLike<{
  data: T | null;
  error: { message: string } | null;
}>;

type ReportRow = {
  id: string;
  reporter_id: string;
  target_type: string;
  target_id: string;
  reason: string;
};

type TaskRow = {
  id: string;
  creator_id: string;
  title: string;
  status: string;
};

type ProfileRow = {
  id: string;
  display_name: string | null;
  role: string;
};

async function assertMutation<T>(request: MutationResult<T>, fallback: string) {
  const { data, error } = await request;
  if (error) {
    throw new Error(`${fallback}: ${error.message}`);
  }
  return data;
}

async function notifyUser(input: {
  userId: string;
  type?: 'task' | 'report' | 'system';
  title: string;
  body: string;
  data?: Record<string, unknown>;
}) {
  await assertMutation(
    adminSupabase.from('notifications').insert({
      user_id: input.userId,
      notification_type: input.type ?? 'system',
      title: input.title,
      body: input.body,
      data: input.data ?? {}
    }),
    '通知创建失败'
  );
}

async function fetchTask(taskId: string) {
  const task = await assertMutation<TaskRow>(
    adminSupabase
      .from('tasks')
      .select('id, creator_id, title, status')
      .eq('id', taskId)
      .single(),
    '任务不存在'
  );

  if (!task) {
    throw new Error('任务不存在');
  }
  return task;
}

async function fetchReport(reportId: string): Promise<ReportRow> {
  const report = await assertMutation<ReportRow>(
    adminSupabase
      .from('reports')
      .select('id, reporter_id, target_type, target_id, reason')
      .eq('id', reportId)
      .single(),
    '举报不存在'
  );

  if (!report) {
    throw new Error('举报不存在');
  }
  return report;
}

async function ensureUserCanBeBlocked(admin: AdminProfile, userId: string) {
  if (userId === admin.id) {
    throw new Error('不能封禁当前管理员账号');
  }

  const profile = await assertMutation<ProfileRow>(
    adminSupabase.from('profiles').select('id, display_name, role').eq('id', userId).single(),
    '用户不存在'
  );

  if (!profile) {
    throw new Error('用户不存在');
  }
  if (profile.role === 'admin') {
    throw new Error('不能封禁管理员账号');
  }

  return profile;
}

async function setTaskStatus(input: {
  admin: AdminProfile;
  taskId: string;
  status: TaskStatusValue;
  moderationNote?: string;
  logAction?: string;
}) {
  const task = await fetchTask(input.taskId);
  const now = new Date().toISOString();
  const closedByModeration = ['hidden', 'rejected', 'cancelled'].includes(input.status);
  const payload: Record<string, unknown> = {
    status: input.status,
    moderation_note: input.moderationNote ?? null
  };

  if (closedByModeration) {
    payload.assigned_helper_id = null;
    payload.selected_offer_id = null;
  }
  if (input.status === 'cancelled') {
    payload.cancelled_at = now;
    payload.cancellation_reason = input.moderationNote ?? '管理员取消任务';
  }
  if (input.status === 'completed') {
    payload.completed_at = now;
  }
  if (input.status === 'open') {
    payload.cancelled_at = null;
    payload.cancellation_reason = null;
  }

  if (closedByModeration) {
    await assertMutation(
      adminSupabase
        .from('task_offers')
        .update({ status: 'rejected' })
        .eq('task_id', input.taskId)
        .in('status', ['pending', 'accepted']),
      '报价状态同步失败'
    );

    await assertMutation(
      adminSupabase.from('conversations').update({ status: 'closed' }).eq('task_id', input.taskId),
      '聊天状态同步失败'
    );
  }

  await assertMutation(
    adminSupabase.from('tasks').update(payload).eq('id', input.taskId),
    '任务状态更新失败'
  );

  await notifyUser({
    userId: task.creator_id,
    type: 'task',
    title: `任务状态已更新：${getStatusLabel(input.status)}`,
    body: input.moderationNote ?? `管理员已将任务「${task.title}」更新为${getStatusLabel(input.status)}。`,
    data: { task_id: input.taskId, status: input.status }
  });

  await writeAdminLog({
    adminId: input.admin.id,
    action: input.logAction ?? 'task.status.update',
    entityType: 'task',
    entityId: input.taskId,
    details: {
      previousStatus: task.status,
      status: input.status,
      moderationNote: input.moderationNote ?? null
    }
  });
}

async function setUserBlocked(input: {
  admin: AdminProfile;
  userId: string;
  blocked: boolean;
  reason?: string;
  logAction?: string;
}) {
  if (input.blocked) {
    await ensureUserCanBeBlocked(input.admin, input.userId);
  }

  await assertMutation(
    adminSupabase
      .from('profiles')
      .update({
        is_blocked: input.blocked,
        blocked_reason: input.blocked ? input.reason : null,
        blocked_at: input.blocked ? new Date().toISOString() : null
      })
      .eq('id', input.userId),
    input.blocked ? '用户封禁失败' : '用户解封失败'
  );

  await notifyUser({
    userId: input.userId,
    type: 'system',
    title: input.blocked ? '账号已被封禁' : '账号已解除封禁',
    body: input.blocked
      ? `你的账号因「${input.reason ?? '平台审核'}」被封禁。`
      : '你的账号已恢复正常使用。',
    data: { user_id: input.userId, blocked: input.blocked }
  });

  await writeAdminLog({
    adminId: input.admin.id,
    action: input.logAction ?? (input.blocked ? 'user.ban' : 'user.unban'),
    entityType: 'user',
    entityId: input.userId,
    details: { reason: input.reason ?? null, blocked: input.blocked }
  });
}

async function updateReportStatus(input: {
  admin: AdminProfile;
  reportId: string;
  status: ReportStatusValue;
  resolution?: string;
  logAction?: string;
}) {
  const report = await fetchReport(input.reportId);

  await assertMutation(
    adminSupabase
      .from('reports')
      .update({
        status: input.status,
        resolution: input.resolution ?? null,
        admin_id: input.admin.id
      })
      .eq('id', input.reportId),
    '举报状态更新失败'
  );

  if (input.status === 'resolved' || input.status === 'rejected') {
    await notifyUser({
      userId: report.reporter_id,
      type: 'report',
      title: input.status === 'resolved' ? '举报已处理' : '举报已关闭',
      body: input.resolution ?? '管理员已经处理你的举报。',
      data: { report_id: input.reportId, status: input.status }
    });
  }

  await writeAdminLog({
    adminId: input.admin.id,
    action: input.logAction ?? 'report.update',
    entityType: 'report',
    entityId: input.reportId,
    details: {
      status: input.status,
      resolution: input.resolution ?? null,
      targetType: report.target_type,
      targetId: report.target_id
    }
  });

  return report;
}

export async function updateTaskStatusAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = taskStatusSchema.parse({
    taskId: formData.get('taskId'),
    status: formData.get('status'),
    moderationNote: formData.get('moderationNote')
  });

  await setTaskStatus({
    admin,
    taskId: input.taskId,
    status: input.status,
    moderationNote: input.moderationNote
  });

  revalidatePath('/tasks');
  revalidatePath('/urgent');
  revalidatePath('/dashboard');
}

export async function banUserAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = banUserSchema.parse({
    userId: formData.get('userId'),
    reason: formData.get('reason')
  });

  await setUserBlocked({
    admin,
    userId: input.userId,
    blocked: true,
    reason: input.reason
  });

  revalidatePath('/users');
  revalidatePath('/dashboard');
}

export async function unbanUserAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = banUserSchema.pick({ userId: true }).parse({
    userId: formData.get('userId')
  });

  await setUserBlocked({
    admin,
    userId: input.userId,
    blocked: false
  });

  revalidatePath('/users');
  revalidatePath('/dashboard');
}

export async function updateReportAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = reportSchema.parse({
    reportId: formData.get('reportId'),
    status: formData.get('status'),
    resolution: formData.get('resolution')
  });

  await updateReportStatus({
    admin,
    reportId: input.reportId,
    status: input.status,
    resolution: input.resolution
  });

  revalidatePath('/reports');
  revalidatePath('/dashboard');
}

export async function applyReportEnforcementAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = reportEnforcementSchema.parse({
    reportId: formData.get('reportId'),
    enforcement: formData.get('enforcement'),
    reason: formData.get('reason'),
    resolution: formData.get('resolution')
  });
  const report = await fetchReport(input.reportId);

  if (!canApplyReportEnforcement(report.target_type, input.enforcement)) {
    throw new Error('这个举报目标不支持所选处理动作');
  }

  const resolution =
    input.resolution ?? `${getReportEnforcementLabel(input.enforcement as ReportEnforcementValue)}：${report.reason}`;

  if (input.enforcement === 'hide_task' || input.enforcement === 'reject_task') {
    await setTaskStatus({
      admin,
      taskId: report.target_id,
      status: input.enforcement === 'hide_task' ? 'hidden' : 'rejected',
      moderationNote: input.reason ?? resolution,
      logAction: `report.${input.enforcement}`
    });
  }

  if (input.enforcement === 'ban_user') {
    await setUserBlocked({
      admin,
      userId: report.target_id,
      blocked: true,
      reason: input.reason ?? report.reason,
      logAction: 'report.ban_user'
    });
  }

  await updateReportStatus({
    admin,
    reportId: input.reportId,
    status: 'resolved',
    resolution,
    logAction: 'report.enforcement.resolve'
  });

  await writeAdminLog({
    adminId: admin.id,
    action: 'report.enforcement.apply',
    entityType: 'report',
    entityId: input.reportId,
    details: {
      enforcement: input.enforcement,
      targetType: report.target_type,
      targetId: report.target_id,
      resolution
    }
  });

  revalidatePath('/reports');
  revalidatePath('/tasks');
  revalidatePath('/users');
  revalidatePath('/dashboard');
}

export async function saveCategoryAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = categorySchema.parse({
    categoryId: formData.get('categoryId'),
    parentId: formData.get('parentId'),
    taskType: formData.get('taskType'),
    name: formData.get('name'),
    slug: formData.get('slug'),
    description: formData.get('description'),
    sortOrder: formData.get('sortOrder') || 0
  });

  const payload = {
    parent_id: input.parentId ?? null,
    task_type: input.taskType ?? null,
    name: input.name,
    slug: input.slug,
    description: input.description ?? null,
    sort_order: input.sortOrder,
    is_active: true
  };

  if (input.categoryId) {
    await assertMutation(
      adminSupabase.from('categories').update(payload).eq('id', input.categoryId),
      '分类更新失败'
    );
  } else {
    await assertMutation(adminSupabase.from('categories').insert(payload), '分类创建失败');
  }

  await writeAdminLog({
    adminId: admin.id,
    action: input.categoryId ? 'category.update' : 'category.create',
    entityType: 'category',
    entityId: input.categoryId,
    details: payload
  });

  revalidatePath('/categories');
}

export async function updateHelperVerificationAction(formData: FormData) {
  const admin = await requireAdmin();
  const input = verificationSchema.parse({
    userId: formData.get('userId'),
    status: formData.get('status'),
    note: formData.get('note')
  });
  const profile = await assertMutation<ProfileRow>(
    adminSupabase.from('profiles').select('id, display_name, role').eq('id', input.userId).single(),
    '用户不存在'
  );

  if (!profile) {
    throw new Error('用户不存在');
  }
  const nextRole =
    input.status === 'approved' ? 'helper' : profile.role === 'helper' ? 'user' : profile.role;

  await assertMutation(
    adminSupabase
      .from('helper_profiles')
      .update({
        verification_status: input.status,
        verification_note: input.note ?? null
      })
      .eq('user_id', input.userId),
    '帮手认证状态更新失败'
  );

  await assertMutation(
    adminSupabase
      .from('profiles')
      .update({
        role: nextRole,
        verification_status: input.status
      })
      .eq('id', input.userId),
    '用户认证状态同步失败'
  );

  await notifyUser({
    userId: input.userId,
    type: 'system',
    title: input.status === 'approved' ? '认证帮手已通过' : '认证帮手未通过',
    body:
      input.note ??
      (input.status === 'approved'
        ? '你的帮手认证已经通过，可以继续接单。'
        : '你的帮手认证申请未通过，请完善资料后再申请。'),
    data: { user_id: input.userId, verification_status: input.status }
  });

  await writeAdminLog({
    adminId: admin.id,
    action: 'helper.verification.update',
    entityType: 'helper_profile',
    entityId: input.userId,
    details: input
  });

  revalidatePath('/verifications');
  revalidatePath('/helpers');
  revalidatePath('/users');
  revalidatePath('/dashboard');
}
