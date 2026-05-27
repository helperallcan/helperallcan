# Helper

Helper 是一个本地生活互助、技能服务、找答案、找东西和找资源的平台。第一版 MVP 包含 Flutter 用户端、Next.js Admin 后台，以及 Supabase PostgreSQL / Realtime / Storage 后端。

## 项目结构

```text
.
├── apps
│   ├── mobile          # Flutter 用户端 App
│   └── admin           # Next.js Admin 后台
├── docs                # 架构和后续扩展说明
└── supabase
    ├── migrations      # 数据库 schema、RLS、函数、Storage policy
    └── seed.sql        # 初始分类数据
```

## 环境变量

复制对应示例文件并填入 Supabase 项目信息：

```text
apps/mobile/.env.example
apps/admin/.env.example
```

Flutter 端使用 `--dart-define` 注入：

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Admin 后台：

```powershell
cd apps/admin
npm install
npm run dev
```

## Supabase 初始化

在 Supabase SQL editor 或 CLI 中按顺序执行：

1. `supabase/migrations/202605190001_initial_schema.sql`
2. `supabase/migrations/202605190002_rls_policies.sql`
3. `supabase/seed.sql`

Storage 会创建：

- `task-images`
- `completion-proofs`
- `avatars`

## 检查命令

Task 1 已补齐 CI 和本地检查说明，详见 `docs/checks.md`。

常用入口：

```powershell
npm run check:admin
npm run check:mobile
npm run check:supabase
```

## MVP 已覆盖

- 用户注册/登录、资料页、身份选择
- 首页四入口：我要找帮手、我要找答案、我要找东西、我要做帮手
- 发布任务、图片上传、分类、地点、预算、加急
- 任务列表、筛选、详情
- 帮手报价、发布者选择帮手
- 基础聊天和 Realtime 消息
- 完成确认、评价、举报、通知表结构
- Admin 用户、帮手、任务、举报、分类、加急、认证申请、付款预留页面
- PostgreSQL schema、RLS、安全函数、Storage policies

## 后续预留

- Payment gateway：接入 `payments` 表和服务端 webhook
- AI 问答：将“我要找答案”任务类型接入 AI 回答和人工帮手混合流程
- 地图定位：为 `tasks` / `helper_profiles` 增加坐标字段或 PostGIS
- 推送通知：把 `notifications` 表接入 FCM/APNs
- 商家系统：扩展 `profiles.role = merchant` 与商家店铺表
