import { StatusBadge } from '@/components/status-badge';
import { getStatusLabel } from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { updateTaskStatusAction } from '../actions';

export default async function UrgentPage() {
  const { data: tasks } = await adminSupabase
    .from('tasks')
    .select('id, title, status, location_text, urgent_fee, created_at, creator:creator_id(display_name)')
    .eq('is_urgent', true)
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>加急任务</h1>
          <p>查看和管理加急曝光任务，后续可接入加急发布费。</p>
        </div>
      </div>

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>任务</th>
              <th>地点</th>
              <th>加急费</th>
              <th>状态</th>
              <th>操作</th>
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
                  </td>
                  <td>{task.location_text}</td>
                  <td>RM {task.urgent_fee ?? 0}</td>
                  <td>
                    <StatusBadge value={task.status} />
                  </td>
                  <td>
                    <form className="actions" action={updateTaskStatusAction}>
                      <input type="hidden" name="taskId" value={task.id} />
                      <select name="status" defaultValue={task.status}>
                        {(['open', 'hidden', 'rejected'] as const).map((status) => (
                          <option key={status} value={status}>
                            {getStatusLabel(status)}
                          </option>
                        ))}
                      </select>
                      <textarea name="moderationNote" placeholder="备注" rows={2} />
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
