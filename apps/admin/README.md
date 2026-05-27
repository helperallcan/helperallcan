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
