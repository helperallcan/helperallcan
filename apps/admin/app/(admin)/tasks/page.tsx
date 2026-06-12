import { StatusBadge } from '@/components/status-badge';
import { getStatusLabel, taskStatusValues } from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { updateTaskStatusAction } from '../actions';

export default async function TasksPage() {
  const { data: tasks } = await adminSupabase
    .from('tasks')
    .select(
      'id, title, description, status, task_type, is_urgent, location_text, budget_min, budget_max, moderation_note, created_at, creator:creator_id(display_name)'
    )
    .order('created_at', { ascending: false })
    .limit(120);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>所有任务</h1>
          <p>审核任务、隐藏违规内容、管理任务状态。</p>
        </div>
      </div>

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
            {(tasks ?? []).map((task) => {
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
          </tbody>
        </table>
      </section>
    </>
  );
}
