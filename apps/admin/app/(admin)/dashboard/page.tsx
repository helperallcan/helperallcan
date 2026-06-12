import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';
import { adminSupabase } from '@/lib/supabase/admin';

export default async function DashboardPage() {
  const [
    usersResult,
    helpersResult,
    openTasksResult,
    urgentTasksResult,
    reportsResult,
    pendingVerificationsResult,
    paymentsResult
  ] = await Promise.all([
    adminSupabase.from('profiles').select('*', { count: 'exact', head: true }),
    adminSupabase.from('helper_profiles').select('*', { count: 'exact', head: true }),
    adminSupabase
      .from('tasks')
      .select('*', { count: 'exact', head: true })
      .in('status', ['open', 'offered', 'assigned']),
    adminSupabase
      .from('tasks')
      .select('*', { count: 'exact', head: true })
      .eq('is_urgent', true)
      .in('status', ['open', 'offered']),
    adminSupabase
      .from('reports')
      .select('*', { count: 'exact', head: true })
      .in('status', ['open', 'reviewing']),
    adminSupabase
      .from('helper_profiles')
      .select('*', { count: 'exact', head: true })
      .eq('verification_status', 'pending'),
    adminSupabase.from('payments').select('*', { count: 'exact', head: true })
  ]);

  const users = usersResult.count ?? 0;
  const helpers = helpersResult.count ?? 0;
  const openTasks = openTasksResult.count ?? 0;
  const urgentTasks = urgentTasksResult.count ?? 0;
  const reports = reportsResult.count ?? 0;
  const pendingVerifications = pendingVerificationsResult.count ?? 0;
  const payments = paymentsResult.count ?? 0;

  const { data: latestTasks } = await adminSupabase
    .from('tasks')
    .select('id, title, status, is_urgent, created_at')
    .order('created_at', { ascending: false })
    .limit(6);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>平台数据</h1>
          <p>核心运营指标和最新任务。</p>
        </div>
      </div>

      <section className="stats">
        <StatCard label="用户" value={users} />
        <StatCard label="帮手" value={helpers} />
        <StatCard label="进行中任务" value={openTasks} />
        <StatCard label="加急任务" value={urgentTasks} />
        <StatCard label="待处理举报" value={reports} />
        <StatCard label="认证申请" value={pendingVerifications} />
        <StatCard label="付款记录" value={payments} hint="预留接口" />
      </section>

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>最新任务</th>
              <th>状态</th>
              <th>加急</th>
              <th>创建时间</th>
            </tr>
          </thead>
          <tbody>
            {(latestTasks ?? []).map((task) => (
              <tr key={task.id}>
                <td>{task.title}</td>
                <td>
                  <StatusBadge value={task.status} />
                </td>
                <td>{task.is_urgent ? '是' : '否'}</td>
                <td>{new Date(task.created_at).toLocaleString('zh-CN')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}
