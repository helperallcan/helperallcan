# Supabase 后端

## 执行顺序

1. 运行 `migrations/202605190001_initial_schema.sql`
2. 运行 `migrations/202605190002_rls_policies.sql`
3. 按文件名顺序运行后续 `migrations/*.sql`
4. 运行 `seed.sql`

## Realtime

Migration 会把以下表加入 `supabase_realtime` publication：

- `tasks`
- `task_offers`
- `conversations`
- `messages`
- `notifications`

## 通知与推送预留

- `notifications` 保存站内通知和未读状态
- `messages.read_at` 保存聊天消息是否已读
- `push_tokens` 预留 Android / iOS / Web 推送 token，后续接入 FCM 或 APNs 时使用

## Storage

Migration 会创建三个 bucket：

- `task-images`：任务图片，公开读，用户只能写入自己目录
- `completion-proofs`：完成证明，登录用户可读，用户只能写入自己目录
- `avatars`：头像，公开读，用户只能管理自己目录

## Admin 账号

创建管理员账号后，将对应 profile 改为：

```sql
update public.profiles
set role = 'admin'
where id = '管理员 auth.users.id';
```
