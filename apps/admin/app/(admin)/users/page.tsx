import { FilterTabs } from '@/components/filter-tabs';
import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';
import { userFilterStatusValues, type UserFilterStatusValue } from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { banUserAction, unbanUserAction } from '../actions';

type UsersPageProps = {
  searchParams?: Promise<{ status?: string | string[] }>;
};

function resolveUserStatus(status?: string | string[]): UserFilterStatusValue {
  const value = Array.isArray(status) ? status[0] : status;
  return userFilterStatusValues.includes(value as UserFilterStatusValue)
    ? (value as UserFilterStatusValue)
    : 'all';
}

export default async function UsersPage({ searchParams }: UsersPageProps) {
  const params = await searchParams;
  const activeStatus = resolveUserStatus(params?.status);
  const usersQuery = adminSupabase
    .from('profiles')
    .select(
      'id, display_name, phone, role, city, district, rating_average, rating_count, is_blocked, blocked_reason, created_at'
    )
    .order('created_at', { ascending: false });
  const scopedUsersQuery =
    activeStatus === 'blocked'
      ? usersQuery.eq('is_blocked', true).limit(100)
      : activeStatus === 'active'
        ? usersQuery.eq('is_blocked', false).limit(100)
        : activeStatus === 'admin'
          ? usersQuery.eq('role', 'admin').limit(100)
          : usersQuery.limit(100);
  const [totalResult, activeResult, blockedResult, adminResult, usersResult] = await Promise.all([
    adminSupabase.from('profiles').select('*', { count: 'exact', head: true }),
    adminSupabase.from('profiles').select('*', { count: 'exact', head: true }).eq('is_blocked', false),
    adminSupabase.from('profiles').select('*', { count: 'exact', head: true }).eq('is_blocked', true),
    adminSupabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'admin'),
    scopedUsersQuery
  ]);

  const counts = {
    total: totalResult.count ?? 0,
    active: activeResult.count ?? 0,
    blocked: blockedResult.count ?? 0,
    admin: adminResult.count ?? 0
  };
  const users = usersResult.data ?? [];

  return (
    <>
      <div className="page-head">
        <div>
          <h1>所有用户</h1>
          <p>查看用户身份、地区和封禁状态。</p>
        </div>
      </div>

      <section className="stats">
        <StatCard label="全部用户" value={counts.total} />
        <StatCard label="正常用户" value={counts.active} />
        <StatCard label="已封禁" value={counts.blocked} hint="需关注" />
        <StatCard label="管理员" value={counts.admin} />
      </section>

      <FilterTabs
        tabs={[
          { label: '全部', href: '/users', count: counts.total, active: activeStatus === 'all' },
          {
            label: '正常',
            href: '/users?status=active',
            count: counts.active,
            active: activeStatus === 'active'
          },
          {
            label: '已封禁',
            href: '/users?status=blocked',
            count: counts.blocked,
            active: activeStatus === 'blocked'
          },
          {
            label: '管理员',
            href: '/users?status=admin',
            count: counts.admin,
            active: activeStatus === 'admin'
          }
        ]}
      />

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
            {users.map((user) => (
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
            {users.length === 0 ? (
              <tr>
                <td className="empty-row" colSpan={6}>
                  当前没有符合筛选条件的用户。
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </section>
    </>
  );
}
