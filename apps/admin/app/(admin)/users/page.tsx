import { StatusBadge } from '@/components/status-badge';
import { adminSupabase } from '@/lib/supabase/admin';

import { banUserAction, unbanUserAction } from '../actions';

export default async function UsersPage() {
  const { data: users } = await adminSupabase
    .from('profiles')
    .select(
      'id, display_name, phone, role, city, district, rating_average, rating_count, is_blocked, blocked_reason, created_at'
    )
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>所有用户</h1>
          <p>查看用户身份、地区和封禁状态。</p>
        </div>
      </div>

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>用户</th>
              <th>身份</th>
              <th>地点</th>
              <th>评分</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {(users ?? []).map((user) => (
              <tr key={user.id}>
                <td>
                  <strong>{user.display_name}</strong>
                  <div className="muted">{user.phone || user.id}</div>
                </td>
                <td>{user.role}</td>
                <td>{[user.city, user.district].filter(Boolean).join(' / ') || '-'}</td>
                <td>
                  {user.rating_average} / 5
                  <div className="muted">{user.rating_count} 条评价</div>
                </td>
                <td>
                  <StatusBadge value={user.is_blocked ? 'blocked' : 'active'} />
                  {user.blocked_reason ? <div className="muted">{user.blocked_reason}</div> : null}
                </td>
                <td>
                  {user.is_blocked ? (
                    <form action={unbanUserAction}>
                      <input type="hidden" name="userId" value={user.id} />
                      <button className="button secondary" type="submit">
                        解封
                      </button>
                    </form>
                  ) : (
                    <form className="actions" action={banUserAction}>
                      <input type="hidden" name="userId" value={user.id} />
                      <textarea name="reason" placeholder="封禁原因" required rows={2} />
                      <button className="button danger" type="submit">
                        封禁
                      </button>
                    </form>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}
