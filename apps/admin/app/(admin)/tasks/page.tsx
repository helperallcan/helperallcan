import { FilterTabs } from '@/components/filter-tabs';
import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';
import {
  getStatusLabel,
  taskFilterStatusValues,
  taskStatusValues,
  type TaskFilterStatusValue
} from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { updateTaskStatusAction } from '../actions';

type TasksPageProps = {
  searchParams?: Promise<{ status?: string | string[] }>;
};

type TaskListStatus = Exclude<TaskFilterStatusValue, 'all'>;

function resolveTaskStatus(status?: string | string[]): TaskFilterStatusValue {
  const value = Array.isArray(status) ? status[0] : status;
  return taskFilterStatusValues.includes(value as TaskFilterStatusValue)
    ? (value as TaskFilterStatusValue)
    : 'all';
}

function countTasks(status: TaskListStatus) {
  return adminSupabase.from('tasks').select('*', { count: 'exact', head: true }).eq('status', status);
}

export default async function TasksPage({ searchParams }: TasksPageProps) {
  const params = await searchParams;
  const activeStatus = resolveTaskStatus(params?.status);
  const tasksQuery = adminSupabase
    .from('tasks')
    .select(
      'id, title, description, status, task_type, is_urgent, location_text, budget_min, budget_max, moderation_note, created_at, creator:creator_id(display_name)'
    )
    .order('created_at', { ascending: false });
  const scopedTasksQuery =
    activeStatus === 'all' ? tasksQuery.limit(120) : tasksQuery.eq('status', activeStatus).limit(120);
  const [
    totalResult,
    openResult,
    offeredResult,
    assignedResult,
    inProgressResult,
    completedResult,
    hiddenResult,
    rejectedResult,
    cancelledResult,
    tasksResult
  ] = await Promise.all([
    adminSupabase.from('tasks').select('*', { count: 'exact', head: true }),
    countTasks('open'),
    countTasks('offered'),
    countTasks('assigned'),
    countTasks('in_progress'),
    countTasks('completed'),
    countTasks('hidden'),
    countTasks('rejected'),
    countTasks('cancelled'),
    scopedTasksQuery
  ]);

  const counts = {
    total: totalResult.count ?? 0,
    open: openResult.count ?? 0,
    offered: offeredResult.count ?? 0,
    assigned: assignedResult.count ?? 0,
    in_progress: inProgressResult.count ?? 0,
    completed: completedResult.count ?? 0,
    hidden: hiddenResult.count ?? 0,
    rejected: rejectedResult.count ?? 0,
    cancelled: cancelledResult.count ?? 0
  };
  const tasks = tasksResult.data ?? [];

  return (
    <>
      <div className="page-head">
        <div>
          <h1>所有任务</h1>
          <p>审核任务、隐藏违规内容、管理任务状态。</p>
        </div>
      </div>

      <section className="stats">
        <StatCard label="全部任务" value={counts.total} />
        <StatCard label="待接单" value={counts.open} />
        <StatCard label="已有报价" value={counts.offered} />
        <StatCard label="进行中" value={counts.assigned + counts.in_progress} />
        <StatCard label="审核处理" value={counts.hidden + counts.rejected} hint="隐藏/拒绝" />
      </section>

      <FilterTabs
        tabs={[
          { label: '全部', href: '/tasks', count: counts.total, active: activeStatus === 'all' },
          { label: '待接单', href: '/tasks?status=open', count: counts.open, active: activeStatus === 'open' },
          {
            label: '已有报价',
            href: '/tasks?status=offered',
            count: counts.offered,
            active: activeStatus === 'offered'
          },
          {
            label: '已选帮手',
            href: '/tasks?status=assigned',
            count: counts.assigned,
            active: activeStatus === 'assigned'
          },
          {
            label: '进行中',
            href: '/tasks?status=in_progress',
            count: counts.in_progress,
            active: activeStatus === 'in_progress'
          },
          {
            label: '已完成',
            href: '/tasks?status=completed',
            count: counts.completed,
            active: activeStatus === 'completed'
          },
          {
            label: '已隐藏',
            href: '/tasks?status=hidden',
            count: counts.hidden,
            active: activeStatus === 'hidden'
          },
          {
            label: '已拒绝',
            href: '/tasks?status=rejected',
            count: counts.rejected,
            active: activeStatus === 'rejected'
          },
          {
            label: '已取消',
            href: '/tasks?status=cancelled',
            count: counts.cancelled,
            active: activeStatus === 'cancelled'
          }
        ]}
      />

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>任务</th>
              <th>类型</th>
              <th>地点/预算</th>
              <th>状态</th>
              <th>审核操作</th>
            </tr>
          </thead>
          <tbody>
            {tasks.map((task) => {
              const creator = Array.isArray(task.creator) ? task.creator[0] : task.creator;
              return (
                <tr key={task.id}>
                  <td>
                    <strong>{task.title}</strong>
                    <div className="muted">{creator?.display_name ?? '未知用户'}</div>
                    <div>{task.description}</div>
                  </td>
                  <td>
                    {task.task_type}
                    {task.is_urgent ? <div className="status status-open">加急</div> : null}
                  </td>
                  <td>
                    {task.location_text}
                    <div className="muted">
                      RM {task.budget_min ?? '-'} / {task.budget_max ?? '-'}
                    </div>
                  </td>
                  <td>
                    <StatusBadge value={task.status} />
                    {task.moderation_note ? <div className="muted">{task.moderation_note}</div> : null}
                  </td>
                  <td>
                    <form className="actions" action={updateTaskStatusAction}>
                      <input type="hidden" name="taskId" value={task.id} />
                      <select name="status" defaultValue={task.status}>
                        {taskStatusValues.map((status) => (
                          <option key={status} value={status}>
                            {getStatusLabel(status)}
                          </option>
                        ))}
                      </select>
                      <textarea name="moderationNote" placeholder="审核备注" rows={2} />
                      <button className="button" type="submit">
                        保存
                      </button>
                    </form>
                  </td>
                </tr>
              );
            })}
            {tasks.length === 0 ? (
              <tr>
                <td className="empty-row" colSpan={5}>
                  当前没有{activeStatus === 'all' ? '' : getStatusLabel(activeStatus)}任务。
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </section>
    </>
  );
}
