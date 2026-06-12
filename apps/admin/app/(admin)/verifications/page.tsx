import { StatusBadge } from '@/components/status-badge';
import { getStatusLabel, verificationStatusValues } from '@/lib/moderation';
import { adminSupabase } from '@/lib/supabase/admin';

import { updateHelperVerificationAction } from '../actions';

export default async function VerificationsPage() {
  const { data: helpers } = await adminSupabase
    .from('helper_profiles')
    .select('id, user_id, headline, skills, service_areas, verification_status, verification_note, created_at, profiles:user_id(display_name, phone)')
    .in('verification_status', ['pending', 'none', 'rejected'])
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>认证帮手申请</h1>
          <p>第一版预留实名认证和认证会员流程。</p>
        </div>
      </div>

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
            {(helpers ?? []).map((helper) => {
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
          </tbody>
        </table>
      </section>
    </>
  );
}
