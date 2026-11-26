# 存档与云同步设计（灯泡方块）

> 目标：**关卡记录、金币、皮肤、设置都不丢**；本地始终有一份，登录后可手动上传/下载云端一份。

## 1. 本地存档

- 路径：`user://saves/<user_id>/slot_0.json`（Godot 用户目录下，平台相关）
  - 未登录：`user_id = local_guest`
  - 已登录：`user_id` = Supabase 账号 UUID
- 写入：`UserData.save()`（任何会改变进度的操作后立即调用；写入失败不弹窗、不打断游戏）
- 首次登录：如果账号下没有存档，会把 `local_guest` 的存档自动复制到账号目录（合并）；
  两边都有存档时弹一次选择（保留本地 / 使用账号存档）。

### 存档字段（version 2）

| 字段 | 含义 |
|---|---|
| `meta` | `{version, updated_at}`：存档版本 + 更新时间（登录自动同步用于判断新旧） |
| `coins` | 金币数量 |
| `purchases` | 购买记录列表：`{style, price, at}` |
| `records.infinite` | 常规挑战记录：`best_level`（已通关最高关，来自真实通关历史）、`clear_count`、`total_seconds` |
| `records.daily` | 每日挑战记录：`clear_count`、`cleared_days[]`（完成过的日期）、`total_seconds` |
| `infinite_level` / `infinite_seed` | 常规挑战当前关卡与关卡种子（断点续玩） |
| `best_infinite` | 兼容字段，始终等于 `records.infinite.best_level`；**首页不再展示** |
| `history` | 最近 20 局通关明细（模式、关卡、用时、时间戳） |
| `daily_claimed` / `daily_done_key` | 每日挑战奖励领取记录 / 当日完成日期键 |
| `owned_styles` / `selected_style` | 已购皮肤 / 当前皮肤 |
| `volume` / `music_on` / `fullscreen` / `window_size` | 设置 |
| `tutorial_done` | 是否看过玩法说明 |

> v1 → v2 迁移：旧存档没有 `records` 时，会从 `history` 重建常规/每日记录，
> 并**丢弃旧版 `best_infinite` 里的历史数字**（防止测试残留的「最高 77 关」之类脏数据），
> 改由真实通关历史推导；购买记录由已拥有皮肤推导。

## 2. 云端存档

- 存储：Supabase Postgres 表 `public.saves`
  - `user_id uuid primary key`（= `auth.uid()`）
  - `data jsonb`（与本地 `slot_0.json` 完全同构）
  - `updated_at timestamptz`
- 权限：RLS 只允许本人 select / insert / update（SQL 见 `docs/CLOUD_SAVE.sql`）
- 客户端：`scripts/cloud_save.gd`（autoload `CloudSave`），使用登录后的 `access_token` 调 PostgREST：
  - 上传：`POST {project}/rest/v1/saves?on_conflict=user_id`，`Prefer: resolution=merge-duplicates`
  - 下载：`GET {project}/rest/v1/saves?user_id=eq.<uuid>&select=data,updated_at`
- 入口：主菜单左上云图标 → 登录后出现「上传 ⌃ / 下载 ⌄」两个按钮
  - 上传：把**当前本地存档**整份覆盖到云端（上传前无需确认）
  - 下载：弹确认框「云端存档会覆盖本机当前进度」→ 确认后用云端数据覆盖本地并立即刷新界面
- **登录自动同步**：登录成功（且合并处理完）后自动拉一次云端存档：
  - 云端没有 → 把本地金币/购买/常规/每日记录上传；
  - 云端较新（比较 `meta.updated_at`）→ 用云端覆盖本地，记录全部恢复；
  - 本地较新 → 上传本地。
- **进度自动上传**：游戏内金币/关卡/记录/设置变化后约 4 秒防抖自动上传（仅登录状态）。
- 冲突策略：登录时按时间取较新；手动按钮仍可强制覆盖。

## 3. 登录方式

- Supabase Auth **手机号 + 密码**（不再使用匿名登录）。客户端把通过格式校验的手机号映射成内部邮箱
  `<11位手机号>@phone.local`，走 Supabase 邮箱/密码认证，用户侧只看到手机号：
  - 注册：`POST /auth/v1/signup {email: <手机号>@phone.local, password}`
  - 登录：`POST /auth/v1/token?grant_type=password {email: <手机号>@phone.local, password}`
  - 续登：`POST /auth/v1/token?grant_type=refresh_token {refresh_token}`
- 手机号校验：11 位、`1` 开头、第二位 3-9、全数字；支持 `+86`、空格、短横线，内部统一规范化。
- 密码：只校验长度 ≥6，原样交给 Supabase 服务端哈希与比对；错误密码由服务端拒绝（提示「手机号或密码不正确」）。
- 登录失败/断网：回退 `local_guest`，本地照常玩；每日挑战仍需联网（服务器时间）。
- **必须关闭 Confirm email**（内部映射邮箱收不到确认信），否则注册后无法登录。
- 防注入：手机号严格白名单校验后才拼固定后缀；客户端不拼接 SQL；云存档走 PostgREST JSON + RLS；
  `user_id` 来自 JWT 并做 URL 编码；secret/service_role key 不进入客户端。

## 4. 需要一次性配置（Supabase Dashboard）

1. Authentication → Providers → Email：保持启用（默认）。
2. Authentication → Providers → Email：关闭 **Confirm email**（或接受邮件验证流程）。
3. Authentication → Providers → Anonymous：**关闭**（本项目不再使用）。
4. SQL Editor：执行 `docs/CLOUD_SAVE.sql`。
5. 客户端配置（已有）：`auth_config.json` 里的项目 URL + anon/publishable key（非 secret key）。

## 5. 验收清单

- [ ] 邮箱注册 → 登录 → 云图标变绿
- [ ] 玩一关常规挑战后点上传 → 云端出现 `saves` 行
- [ ] 换一台设备/清本地存档后登录 → 点下载 → 金币/关卡/记录恢复
- [ ] 断网启动：本地模式可玩；云图标为斜杠云；不阻塞游戏
- [ ] 关闭匿名登录后：邮箱登录仍正常，旧匿名会话不会被使用
