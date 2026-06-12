import { StatusBadge } from '@/components/status-badge';
import {
  canApplyReportEnforcement,
  getReportEnforcementLabel,
  getReportTargetLabel,
  getStatusLabel,
  reportEnforcementValues,
  reportStatusValues
} from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { applyReportEnforcementAction, updateReportAction } from '../actions';

export default async function ReportsPage() {
  const { data: reports } = await adminSupabase
    .from('reports')
    .select('id, target_type, target_id, reason, details, status, resolution, created_at, reporter:reporter_id(display_name)')
    .order('created_at', { ascending: false })
    .limit(120);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>举报处理</h1>
          <p>处理用户或任务举报，可直接隐藏任务、拒绝任务或封禁用户。</p>
        </div>
      </div>

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
            {(reports ?? []).map((report) => {
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
                    <StatusBadge value={report.status} />
                    {report.resolution ? <div className="muted">{report.resolution}</div> : null}
                  </td>
                  <td>
                    <form className="actions" action={updateReportAction}>
                      <input type="hidden" name="reportId" value={report.id} />
                      <select name="status" defaultValue={report.status}>
                        {reportStatusValues.map((status) => (
                          <option key={status} value={status}>
                            {getStatusLabel(status)}
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
          </tbody>
        </table>
      </section>
    </>
  );
}
