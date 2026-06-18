# Helper Admin 后台

## 运行

```powershell
npm install
npm run dev
```

## 环境变量

复制 `.env.example` 为 `.env.local`，填写：

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

后台登录账号必须存在于 Supabase Auth，并且 `public.profiles.role = 'admin'`。

## 登录排查

先确认 `.env.local` 里的三个值都来自同一个 Supabase 项目：

- `NEXT_PUBLIC_SUPABASE_URL`: Supabase Project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Supabase API Settings 的 anon public key
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase API Settings 的 service_role secret key

检查后台连接：

```powershell
npm run admin:check
```

把已经注册过的用户升级为管理员：

```powershell
npm run admin:promote -- admin@example.com
```

如果 `admin:check` 提示项目域名查不到，请先确认 Supabase 项目没有暂停、删除，且 Project URL 没有填错。
