# Helper MVP 架构

## 模块

- Flutter App：普通用户、帮手、商家入口共用同一个客户端。
- Supabase：Auth、PostgreSQL、Realtime、Storage、RLS。
- Next.js Admin：只允许 `profiles.role = admin` 的账号访问，敏感操作使用服务端 service role client 并写入 `admin_logs`。

## 任务生命周期

```text
open -> offered -> assigned -> in_progress -> completed
                       └────── cancelled
```

第一版将 `assigned` 视为已经选择帮手，聊天基于任务和帮手生成 `conversations`。

## 关键安全边界

- 客户端只使用 Supabase anon key。
- Admin service role key 只存在 Next.js 服务端环境变量。
- 用户只能更新自己的 `profiles`。
- 发布者才能更新自己的任务和接受报价。
- 帮手只能为开放任务报价。
- 聊天消息只允许任务发布者和被选/报价帮手访问。
- 举报、封禁、任务审核和认证审核必须通过 Admin 后台，并记录 `admin_logs`。

## 可扩展点

- 地图：为任务增加 `latitude` / `longitude` 或 PostGIS geography。
- 支付：`payments.provider_payload` 保存 gateway webhook 原始摘要，避免丢审计线索。
- AI：`tasks.task_type = answer` 可先进入 AI 草答，再转人工帮手。
- 商家：后续新增 `merchant_profiles`、店铺、套餐、广告曝光位。
- 内容审核：当前有客户端 validation 和数据库关键词拦截，正式上线建议接入模型审核与人工队列。
