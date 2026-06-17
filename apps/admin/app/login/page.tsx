import { LoginForm } from './login-form';

export default async function LoginPage({
  searchParams
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const errorMessages: Record<string, string> = {
    admin: '当前账号不是管理员。',
    config: '后台 Supabase 管理配置有问题，请检查项目 URL 和 service_role key。'
  };
  const error = params.error ? errorMessages[params.error] : undefined;

  return (
    <main className="login-page">
      <LoginForm error={error} />
    </main>
  );
}
