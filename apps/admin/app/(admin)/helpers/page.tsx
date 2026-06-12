import { StatusBadge } from '@/components/status-badge';
import { getStatusLabel, verificationStatusValues } from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { updateHelperVerificationAction } from '../actions';

export default async function HelpersPage() {
  const { data: helpers } = await adminSupabase
    .from('helper_profiles')
    .select(
      'id, user_id, headline, skills, service_areas, verification_status, completed_tasks, rating_average, profiles:user_id(display_name, phone, city)'
    )
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>所有帮手</h1>
          <p>查看技能、服务地区、评分和认证状态，也可以直接处理认证。</p>
        </div>
      </div>

      <section className="panel">
        <table>
          <thead>
            <tr>
              <th>帮手</th>
              <th>技能</th>
              <th>服务地区</th>
              <th>评分</th>
              <th>认证</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {(helpers ?? []).map((helper) => {
              const profile = Array.isArray(helper.profiles) ? helper.profiles[0] : helper.profiles;
              const verificationDefault =
                helper.verification_status === 'rejected' ? 'rejected' : 'approved';

              return (
                <tr key={helper.id}>
                  <td>
                    <strong>{profile?.display_name ?? helper.user_id}</strong>
                    <div className="muted">{helper.headline || profile?.phone}</div>
                  </td>
                  <td>{(helper.skills ?? []).join('，') || '-'}</td>
                  <td>{(helper.service_areas ?? []).join('，') || profile?.city || '-'}</td>
                  <td>
                    {helper.rating_average} / 5
                    <div className="muted">{helper.completed_tasks} 单完成</div>
                  </td>
                  <td>
                    <StatusBadge value={helper.verification_status} />
                  </td>
                  <td>
                    <form className="actions" action={updateHelperVerificationAction}>
                      <input type="hidden" name="userId" value={helper.user_id} />
                      <select name="status" defaultValue={verificationDefault}>
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
          </tbody>
        </table>
      </section>
    </>
  );
}
