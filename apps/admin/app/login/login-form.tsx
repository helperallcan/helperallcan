'use client';

import { useActionState } from 'react';

import { loginAction } from './actions';

export function LoginForm({ error }: { error?: string }) {
  const [state, formAction, pending] = useActionState(loginAction, {
    error
  });

  return (
    <form className="login-card" action={formAction}>
      <h1>Helper Admin</h1>
      <p>请使用管理员账号登录后台。</p>
      {state.error ? <p className="error">{state.error}</p> : null}
      <label className="field">
        邮箱
        <input name="email" type="email" required />
      </label>
      <label className="field">
        密码
        <input name="password" type="password" required minLength={6} />
      </label>
      <div style={{ marginTop: 18 }}>
        <button className="button" type="submit" disabled={pending}>
          {pending ? '登录中...' : '登录后台'}
        </button>
      </div>
    </form>
  );
}
