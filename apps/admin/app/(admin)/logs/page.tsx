import { adminSupabase } from '@/lib/supabase/admin';

export default async function LogsPage() {
  const { data: logs } = await adminSupabase
    .from('admin_logs')
    .select('id, action, entity_type, entity_id, details, created_at, admin:admin_id(display_name)')
    .order('created_at', { ascending: false })
    .limit(150);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>操作日志</h1>
          <p>查看后台审核、封禁、认证和分类管理记录。</p>
        </div>
      </div>

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>时间</th>
              <th>管理员</th>
              <th>操作</th>
              <th>对象</th>
              <th>详情</th>
            </tr>
          </thead>
          <tbody>
            {(logs ?? []).map((log) => {
              const admin = Array.isArray(log.admin) ? log.admin[0] : log.admin;

              return (
                <tr key={log.id}>
                  <td>{new Date(log.created_at).toLocaleString('zh-CN')}</td>
                  <td>{admin?.display_name ?? '系统'}</td>
                  <td>{log.action}</td>
                  <td>
                    {log.entity_type}
                    <div className="muted">{log.entity_id ?? '-'}</div>
                  </td>
                  <td>
                    <pre className="log-details">
                      {JSON.stringify(log.details ?? {}, null, 2)}
                    </pre>
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
