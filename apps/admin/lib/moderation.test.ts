import assert from 'node:assert/strict';
import test from 'node:test';

import {
  banUserSchema,
  canApplyReportEnforcement,
  categorySchema,
  getReportStatusLabel,
  getReportTargetLabel,
  getStatusLabel,
  isOpenReviewStatus,
  reportEnforcementSchema,
  reportSchema,
  taskStatusSchema
} from './moderation.ts';

test('taskStatusSchema trims optional moderation notes', () => {
  const input = taskStatusSchema.parse({
    taskId: '00000000-0000-0000-0000-000000000001',
    status: 'hidden',
    moderationNote: '  违规任务  '
  });

  assert.equal(input.moderationNote, '违规任务');
});

test('banUserSchema requires a meaningful reason', () => {
  assert.throws(() =>
    banUserSchema.parse({
      userId: '00000000-0000-0000-0000-000000000001',
      reason: ' '
    })
  );
});

test('report enforcement only allows matching target actions', () => {
  assert.equal(canApplyReportEnforcement('task', 'hide_task'), true);
  assert.equal(canApplyReportEnforcement('task', 'ban_user'), false);
  assert.equal(canApplyReportEnforcement('user', 'ban_user'), true);
  assert.equal(canApplyReportEnforcement('message', 'resolve_only'), true);
});

test('reportEnforcementSchema normalizes optional text', () => {
  const input = reportEnforcementSchema.parse({
    reportId: '00000000-0000-0000-0000-000000000001',
    enforcement: 'resolve_only',
    reason: '',
    resolution: '  已提醒用户  '
  });

  assert.equal(input.reason, undefined);
  assert.equal(input.resolution, '已提醒用户');
});

test('reportSchema accepts open reports for the admin review queue', () => {
  const input = reportSchema.parse({
    reportId: '00000000-0000-0000-0000-000000000001',
    status: 'open',
    resolution: ''
  });
  assert.equal(input.status, 'open');
  assert.equal(input.resolution, undefined);
});

test('categorySchema normalizes slug and optional ids', () => {
  const input = categorySchema.parse({
    categoryId: '',
    parentId: '',
    taskType: 'help',
    name: '  本地维修  ',
    slug: ' Local-Repair ',
    description: '',
    sortOrder: '3'
  });

  assert.equal(input.categoryId, undefined);
  assert.equal(input.name, '本地维修');
  assert.equal(input.slug, 'local-repair');
  assert.equal(input.description, undefined);
  assert.equal(input.sortOrder, 3);
});

test('labels use Chinese copy with safe fallbacks', () => {
  assert.equal(getStatusLabel('reviewing'), '处理中');
  assert.equal(getStatusLabel('custom'), 'custom');
  assert.equal(getReportStatusLabel('open'), '待处理');
  assert.equal(getReportStatusLabel('rejected'), '已关闭');
  assert.equal(getReportTargetLabel('task'), '任务');
  assert.equal(getReportTargetLabel('unknown'), 'unknown');
});

test('review queue treats open, reviewing, and pending items as active work', () => {
  assert.equal(isOpenReviewStatus('open'), true);
  assert.equal(isOpenReviewStatus('reviewing'), true);
  assert.equal(isOpenReviewStatus('pending'), true);
  assert.equal(isOpenReviewStatus('resolved'), false);
});
