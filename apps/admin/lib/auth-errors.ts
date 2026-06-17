const networkHints = ['fetch failed', 'failed to fetch', 'enotfound', 'networkerror', 'network request failed'];

export function getAuthLoginErrorMessage(error: unknown) {
  const message =
    error instanceof Error
      ? error.message
      : typeof error === 'string'
        ? error
        : '登录失败，请稍后再试。';
  const normalized = message.toLowerCase();

  if (networkHints.some((hint) => normalized.includes(hint))) {
    return '无法连接 Supabase 项目，请检查项目 URL 是否正确、项目是否暂停或网络是否可用。';
  }

  if (normalized.includes('invalid login credentials')) {
    return '邮箱或密码不正确。';
  }

  if (normalized.includes('email not confirmed')) {
    return '邮箱还没有完成验证，请先完成邮箱验证。';
  }

  return message;
}
