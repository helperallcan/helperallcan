import { z } from 'zod';

export const taskStatusValues = ['open', 'hidden', 'rejected', 'cancelled', 'completed'] as const;
export const taskFilterStatusValues = [
  'all',
  'open',
  'offered',
  'assigned',
  'in_progress',
  'completed',
  'hidden',
  'rejected',
  'cancelled'
] as const;
export const reportStatusValues = ['open', 'reviewing', 'resolved', 'rejected'] as const;
export const reportFilterStatusValues = ['all', ...reportStatusValues] as const;
export const verificationStatusValues = ['approved', 'rejected'] as const;
export const verificationFilterStatusValues = [
  'all',
  'pending',
  'none',
  'rejected',
  'approved'
] as const;
export const userFilterStatusValues = ['all', 'active', 'blocked', 'admin'] as const;
export const reportEnforcementValues = ['hide_task', 'reject_task', 'ban_user', 'resolve_only'] as const;

export type TaskStatusValue = (typeof taskStatusValues)[number];
export type TaskFilterStatusValue = (typeof taskFilterStatusValues)[number];
export type ReportStatusValue = (typeof reportStatusValues)[number];
export type ReportFilterStatusValue = (typeof reportFilterStatusValues)[number];
export type VerificationStatusValue = (typeof verificationStatusValues)[number];
export type VerificationFilterStatusValue = (typeof verificationFilterStatusValues)[number];
export type UserFilterStatusValue = (typeof userFilterStatusValues)[number];
export type ReportEnforcementValue = (typeof reportEnforcementValues)[number];

const uuid = z.string().uuid();

const optionalText = (max: number) =>
  z.preprocess(
    (value) => {
      if (typeof value !== 'string') return undefined;
      const trimmed = value.trim();
      return trimmed.length === 0 ? undefined : trimmed;
    },
    z.string().max(max).optional()
  );

const optionalUuid = z.preprocess(
  (value) => {
    if (typeof value !== 'string') return undefined;
    const trimmed = value.trim();
    return trimmed.length === 0 ? undefined : trimmed;
  },
  uuid.optional()
);

export const taskStatusSchema = z.object({
  taskId: uuid,
  status: z.enum(taskStatusValues),
  moderationNote: optionalText(500)
});

export const banUserSchema = z.object({
  userId: uuid,
  reason: z.string().trim().min(2).max(300)
});

export const reportSchema = z.object({
  reportId: uuid,
  status: z.enum(reportStatusValues),
  resolution: optionalText(800)
});

export const reportEnforcementSchema = z.object({
  reportId: uuid,
  enforcement: z.enum(reportEnforcementValues),
  reason: optionalText(300),
  resolution: optionalText(800)
});

export const categorySchema = z.object({
  categoryId: optionalUuid,
  parentId: optionalUuid,
  taskType: z.preprocess(
    (value) => (typeof value === 'string' && value.trim() ? value.trim() : undefined),
    z.enum(['help', 'answer', 'find_item', 'resource']).optional()
  ),
  name: z.string().trim().min(2).max(80),
  slug: z
    .string()
    .trim()
    .toLowerCase()
    .min(2)
    .max(80)
    .regex(/^[a-z0-9-]+$/, 'Slug can only contain lowercase letters, numbers, and hyphens.'),
  description: optionalText(300),
  sortOrder: z.coerce.number().int().default(0)
});

export const verificationSchema = z.object({
  userId: uuid,
  status: z.enum(verificationStatusValues),
  note: optionalText(500)
});

const statusLabels: Record<string, string> = {
  active: '正常',
  admin: '管理员',
  approved: '已通过',
  assigned: '已选择帮手',
  blocked: '已封禁',
  cancelled: '已取消',
  completed: '已完成',
  failed: '失败',
  hidden: '已隐藏',
  in_progress: '进行中',
  none: '未申请',
  offered: '已有报价',
  open: '公开',
  paid: '已付款',
  pending: '待审核',
  rejected: '已拒绝',
  resolved: '已解决',
  reviewing: '处理中'
};

const reportTargetLabels: Record<string, string> = {
  user: '用户',
  task: '任务',
  offer: '报价',
  message: '消息',
  review: '评价'
};

const reportStatusLabels: Record<ReportStatusValue, string> = {
  open: '待处理',
  reviewing: '处理中',
  resolved: '已解决',
  rejected: '已关闭'
};

const enforcementLabels: Record<ReportEnforcementValue, string> = {
  hide_task: '隐藏任务并解决',
  reject_task: '拒绝任务并解决',
  ban_user: '封禁用户并解决',
  resolve_only: '仅标记解决'
};

export function getStatusLabel(value?: string | null) {
  return statusLabels[value ?? 'none'] ?? value ?? 'none';
}

export function getReportTargetLabel(value?: string | null) {
  return reportTargetLabels[value ?? ''] ?? value ?? '-';
}

export function getReportStatusLabel(value?: string | null) {
  return reportStatusLabels[value as ReportStatusValue] ?? getStatusLabel(value);
}

export function getReportEnforcementLabel(value: ReportEnforcementValue) {
  return enforcementLabels[value];
}

export function canApplyReportEnforcement(targetType: string, enforcement: ReportEnforcementValue) {
  if (enforcement === 'resolve_only') return true;
  if (enforcement === 'hide_task' || enforcement === 'reject_task') return targetType === 'task';
  if (enforcement === 'ban_user') return targetType === 'user';
  return false;
}

export function isOpenReviewStatus(status?: string | null) {
  return status === 'open' || status === 'reviewing' || status === 'pending';
}
