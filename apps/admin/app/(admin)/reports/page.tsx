import { FilterTabs } from '@/components/filter-tabs';
import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';
import {
  canApplyReportEnforcement,
  getReportEnforcementLabel,
  getReportStatusLabel,
  getReportTargetLabel,
  reportFilterStatusValues,
  reportEnforcementValues,
  reportStatusValues,
  type ReportFilterStatusValue,
  type ReportStatusValue
} from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { applyReportEnforcementAction, updateReportAction } from '../actions';

type ReportsPageProps = {
  searchParams?: Promise<{ status?: string | string[] }>;
};

function resolveReportStatus(status?: string | string[]): ReportFilterStatusValue {
  const value = Array.isArray(status) ? status[0] : status;
  return reportFilterStatusValues.includes(value as ReportFilterStatusValue)
    ? (value as ReportFilterStatusValue)
    : 'open';
}

function countReports(status: ReportStatusValue) {
  return adminSupabase.from('reports').select('*', { count: 'exact', head: true }).eq('status', status);
}

export default async function ReportsPage({ searchParams }: ReportsPageProps) {
  const params = await searchParams;
  const activeStatus = resolveReportStatus(params?.status);
  const reportsQuery = adminSupabase
    .from('reports')
    .select('id, target_type, target_id, reason, details, status, resolution, created_at, reporter:reporter_id(display_name)')
    .order('created_at', { ascending: false });
  const scopedReportsQuery =
    activeStatus === 'all' ? reportsQuery.limit(120) : reportsQuery.eq('status', activeStatus).limit(120);
  const [openResult, reviewingResult, resolvedResult, rejectedResult, reportsResult] = await Promise.all([
    countReports('open'),
    countReports('reviewing'),
    countReports('resolved'),
    countReports('rejected'),
    scopedReportsQuery
  ]);

  const counts = {
    open: openResult.count ?? 0,
    reviewing: reviewingResult.count ?? 0,
    resolved: resolvedResult.count ?? 0,
    rejected: rejectedResult.count ?? 0
  };
  const totalReports = counts.open + counts.reviewing + counts.resolved + counts.rejected;
  const reports = reportsResult.data ?? [];

  return (
    <>
      <div className="page-head">
        <div>
          <h1>举报处理</h1>
          <p>处理用户或任务举报，可直接隐藏任务、拒绝任务或封禁用户。</p>
        </div>
      </div>

      <section className="stats">
        <StatCard label="待处理" value={counts.open} hint="新举报" />
        <StatCard label="处理中" value={counts.reviewing} hint="已进入审核" />
        <StatCard label="已解决" value={counts.resolved} />
        <StatCard label="已关闭" value={counts.rejected} />
      </section>

      <FilterTabs
        tabs={[
          { label: '待处理', href: '/reports', count: counts.open, active: activeStatus === 'open' },
          {
            label: '处理中',
            href: '/reports?status=reviewing',
            count: counts.reviewing,
            active: activeStatus === 'reviewing'
          },
          {
            label: '已解决',
            href: '/reports?status=resolved',
            count: counts.resolved,
            active: activeStatus === 'resolved'
          },
          {
            label: '已关闭',
            href: '/reports?status=rejected',
            count: counts.rejected,
            active: activeStatus === 'rejected'
          },
          {
            label: '全部',
            href: '/reports?status=all',
            count: totalReports,
            active: activeStatus === 'all'
          }
        ]}
      />

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>举报</th>
              <th>目标</th>
              <th>状态</th>
              <th>处理</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report) => {
              const reporter = Array.isArray(report.reporter) ? report.reporter[0] : report.reporter;
              return (
                <tr key={report.id}>
                  <td>
                    <strong>{report.reason}</strong>
                    <div>{report.details || '-'}</div>
                    <div className="muted">
                      举报人：{reporter?.display_name ?? '未知'} ·{' '}
                      {new Date(report.created_at).toLocaleString('zh-CN')}
                    </div>
                  </td>
                  <td>
                    {getReportTargetLabel(report.target_type)}
                    <div className="muted">{report.target_id}</div>
                  </td>
                  <td>
                    <StatusBadge value={report.status} label={getReportStatusLabel(report.status)} />
                    {report.resolution ? <div className="muted">{report.resolution}</div> : null}
                  </td>
                  <td>
                    <form className="actions" action={updateReportAction}>
                      <input type="hidden" name="reportId" value={report.id} />
                      <select name="status" defaultValue={report.status}>
                        {reportStatusValues.map((status) => (
                          <option key={status} value={status}>
                            {getReportStatusLabel(status)}
                          </option>
                        ))}
                      </select>
                      <textarea name="resolution" placeholder="处理结果" rows={2} />
                      <button className="button" type="submit">
                        保存
                      </button>
                    </form>
                    <form className="actions compact-form" action={applyReportEnforcementAction}>
                      <input type="hidden" name="reportId" value={report.id} />
                      <select name="enforcement" defaultValue="resolve_only">
                        {reportEnforcementValues.map((enforcement) => (
                          <option
                            key={enforcement}
                            value={enforcement}
                            disabled={!canApplyReportEnforcement(report.target_type, enforcement)}
                          >
                            {getReportEnforcementLabel(enforcement)}
                          </option>
                        ))}
                      </select>
                      <input name="reason" placeholder="处理原因" />
                      <textarea name="resolution" placeholder="给举报人的处理结果" rows={2} />
                      <button className="button danger" type="submit">
                        执行处理
                      </button>
                    </form>
                  </td>
                </tr>
              );
            })}
            {reports.length === 0 ? (
              <tr>
                <td className="empty-row" colSpan={4}>
                  当前没有{activeStatus === 'all' ? '' : getReportStatusLabel(activeStatus)}举报。
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </section>
    </>
  );
}
