import { FilterTabs } from '@/components/filter-tabs';
import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';
import {
  getStatusLabel,
  verificationFilterStatusValues,
  verificationStatusValues,
  type VerificationFilterStatusValue
} from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { updateHelperVerificationAction } from '../actions';

type VerificationsPageProps = {
  searchParams?: Promise<{ status?: string | string[] }>;
};

type HelperVerificationStatus = Exclude<VerificationFilterStatusValue, 'all'>;

function resolveVerificationStatus(status?: string | string[]): VerificationFilterStatusValue {
  const value = Array.isArray(status) ? status[0] : status;
  return verificationFilterStatusValues.includes(value as VerificationFilterStatusValue)
    ? (value as VerificationFilterStatusValue)
    : 'pending';
}

function countHelpers(status: HelperVerificationStatus) {
  return adminSupabase
    .from('helper_profiles')
    .select('*', { count: 'exact', head: true })
    .eq('verification_status', status);
}

export default async function VerificationsPage({ searchParams }: VerificationsPageProps) {
  const params = await searchParams;
  const activeStatus = resolveVerificationStatus(params?.status);
  const helpersQuery = adminSupabase
    .from('helper_profiles')
    .select('id, user_id, headline, skills, service_areas, verification_status, verification_note, created_at, profiles:user_id(display_name, phone)')
    .order('created_at', { ascending: false });
  const scopedHelpersQuery =
    activeStatus === 'all'
      ? helpersQuery.limit(100)
      : helpersQuery.eq('verification_status', activeStatus).limit(100);
  const [pendingResult, noneResult, rejectedResult, approvedResult, helpersResult] = await Promise.all([
    countHelpers('pending'),
    countHelpers('none'),
    countHelpers('rejected'),
    countHelpers('approved'),
    scopedHelpersQuery
  ]);

  const counts = {
    pending: pendingResult.count ?? 0,
    none: noneResult.count ?? 0,
    rejected: rejectedResult.count ?? 0,
    approved: approvedResult.count ?? 0
  };
  const totalHelpers = counts.pending + counts.none + counts.rejected + counts.approved;
  const helpers = helpersResult.data ?? [];

  return (
    <>
      <div className="page-head">
        <div>
          <h1>认证帮手申请</h1>
          <p>第一版预留实名认证和认证会员流程。</p>
        </div>
      </div>

      <section className="stats">
        <StatCard label="待审核" value={counts.pending} hint="需要处理" />
        <StatCard label="未申请" value={counts.none} />
        <StatCard label="已拒绝" value={counts.rejected} />
        <StatCard label="已通过" value={counts.approved} />
      </section>

      <FilterTabs
        tabs={[
          { label: '待审核', href: '/verifications', count: counts.pending, active: activeStatus === 'pending' },
          {
            label: '未申请',
            href: '/verifications?status=none',
            count: counts.none,
            active: activeStatus === 'none'
          },
          {
            label: '已拒绝',
            href: '/verifications?status=rejected',
            count: counts.rejected,
            active: activeStatus === 'rejected'
          },
          {
            label: '已通过',
            href: '/verifications?status=approved',
            count: counts.approved,
            active: activeStatus === 'approved'
          },
          {
            label: '全部',
            href: '/verifications?status=all',
            count: totalHelpers,
            active: activeStatus === 'all'
          }
        ]}
      />

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>帮手</th>
              <th>资料</th>
              <th>认证状态</th>
              <th>审核</th>
            </tr>
          </thead>
          <tbody>
            {helpers.map((helper) => {
              const profile = Array.isArray(helper.profiles) ? helper.profiles[0] : helper.profiles;
              return (
                <tr key={helper.id}>
                  <td>
                    <strong>{profile?.display_name ?? helper.user_id}</strong>
                    <div className="muted">{profile?.phone ?? helper.user_id}</div>
                  </td>
                  <td>
                    <div>{helper.headline || '-'}</div>
                    <div className="muted">{(helper.skills ?? []).join('，')}</div>
                    <div className="muted">{(helper.service_areas ?? []).join('，')}</div>
                  </td>
                  <td>
                    <StatusBadge value={helper.verification_status} />
                    {helper.verification_note ? (
                      <div className="muted">{helper.verification_note}</div>
                    ) : null}
                  </td>
                  <td>
                    <form className="actions" action={updateHelperVerificationAction}>
                      <input type="hidden" name="userId" value={helper.user_id} />
                      <select name="status" defaultValue="approved">
                        {verificationStatusValues.map((status) => (
                          <option key={status} value={status}>
                            {getStatusLabel(status)}
                          </option>
                        ))}
                      </select>
                      <textarea name="note" placeholder="审核备注" rows={2} />
                      <button className="button" type="submit">
                        保存
                      </button>
                    </form>
                  </td>
                </tr>
              );
            })}
            {helpers.length === 0 ? (
              <tr>
                <td className="empty-row" colSpan={4}>
                  当前没有{activeStatus === 'all' ? '' : getStatusLabel(activeStatus)}认证记录。
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </section>
    </>
  );
}
