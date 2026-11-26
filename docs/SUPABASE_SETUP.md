# Supabase 接入步骤（灯泡方块 · 手机号登录 + 云存档）

> 登录方式：**手机号 + 密码**。不需要短信服务商：客户端把通过格式校验的手机号映射成内部标识
> `<11位手机号>@phone.local`，走 Supabase Email/Password 认证；用户看到的输入是手机号。
> 只要 **项目 URL + anon/publishable key**，不需要额外的 URL 或 API。

## 0. 准备

- 已建 Supabase 项目，记下：`Project URL`（`https://xxx.supabase.co`）
- `Project Settings → API Keys` 里的 **Publishable key**（`sb_publishable_...`）或旧版 **anon** key（`eyJ...`）
- 不要使用 `sb_secret_` / `service_role`（服务端密钥，不能进客户端）

## 1. 认证设置

1. `Authentication → Providers → Email` → 保持 **Enable**（内部映射邮箱需要它）；
2. `Authentication → Providers → Email` → **关闭 Confirm email**（必须；因为内部映射邮箱收不到确认信）；
3. `Authentication → Providers → Anonymous` → **关闭**（本项目不使用匿名登录）；
4. 不需要配置 SMS / Phone provider。

## 2. 建云存档表

打开 `SQL Editor`，执行项目里的 `docs/CLOUD_SAVE.sql`（建 `public.saves` 表 + RLS 策略）：

```sql
create table if not exists public.saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.saves enable row level security;
-- 策略：只能 select / insert / update 自己那一行（完整 SQL 见文件）
```

## 3. 客户端配置

任选其一：

**环境变量**：
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=<publishable 或 anon key>
```

**本地配置文件**（推荐，不进仓库）：
把游戏用户目录下的 `auth_config.json` 写成：
```json
{
  "url": "https://xxx.supabase.co",
  "publishable_key": "sb_publishable_..."
}
```

> 已配置的机器：`%APPDATA%\Godot\app_userdata\灯泡方块\auth_config.json`

## 4. 登录行为

- 注册：手机号 + 密码（≥6 位）→ 直接登录（Confirm email 关闭的前提下）；
- 登录：手机号 + 密码 → 云图标变绿；
- 手机号会先校验：中国大陆 11 位、`1` 开头、第二位 3-9、全数字；支持 `+86`、空格、短横线，内部统一规范化；
- 密码错误：提示「手机号或密码不正确」（由 Supabase 校验，客户端不做旁路判断）；
- 启动续登：用 refresh_token 静默续登，失败自动回退本地模式，不卡启动；
- 首次登录账号下无存档：自动把 `local_guest` 本地存档复制到账号目录；
- 两边都有：弹一次选择（保留本地 / 使用账号存档）。

## 5. 云存档上传 / 下载

- 入口：主菜单左上云图标 → 已登录后出现两个按钮：
  - **上传**（☁⌃）：把当前本地整份存档写到云端（覆盖该账号云端记录）
  - **下载**（☁⌄）：确认后把云端存档覆盖到本地，并立即刷新金币/关卡/记录
- 失败提示保持简短（“请先登录 / 网络不可用 / 云端还没有存档”），不展示后端地址或密钥。

## 6. SQL 注入 / 越权防护

客户端不直接拼 SQL，全部走 Supabase 官方接口，关键防线：

1. **输入白名单**：手机号只允许 `+86` / 空格 / 短横线 / 11 位数字，其余字符直接拒绝；
   密码只限制长度，原样交给 Supabase Auth（由服务端哈希与校验），客户端不保存明文密码。
2. **内部标识固定后缀**：`<11位数字>@phone.local`，校验后不可能包含引号、`@`、空白等注入字符。
3. **不拼 SQL**：注册/登录用 GoTrue 的 JSON 请求体；云存档走 PostgREST 的 JSON body；
   没有任何字符串被拼进 SQL 语句。
4. **行级安全（RLS）**：`public.saves` 开启 RLS，策略 `auth.uid() = user_id`，
   即使拿到 anon key 也只能读写自己那一行；越权请求由数据库拒绝。
5. **用户 ID 来自 JWT**：`user_id` 由 Supabase 签发并校验为 UUID，查询参数再做 `uri_encode`。
6. **密钥隔离**：客户端只有 publishable/anon key；secret/service_role key 只放服务端，绝不进客户端。

## 7. 常见问题

| 现象 | 处理 |
|---|---|
| 注册后登录提示“账号需要验证” | 关闭 Confirm email（内部映射邮箱收不到确认信） |
| 登录提示手机号或密码不正确 | 检查手机号格式与密码；未注册先点注册 |
| 登录提示手机号格式不正确 | 使用 11 位大陆手机号，或带 `+86` 前缀 |
| 上传提示登录已过期 | 退出后重新登录（refresh token 失效） |
| 上传提示云端保存失败 | 确认已执行 `docs/CLOUD_SAVE.sql`，且 RLS 策略存在 |
| 下载提示云端还没有存档 | 先在本机点一次上传 |
| 云图标斜杠 | 未登录/本地模式；普通挑战不受影响，每日挑战需要联网时间服务 |

## 8. 验收清单

- [ ] 手机号注册 → 登录成功（云图标变绿）
- [ ] 错误手机号（如 128… / 10 位 / 带字母）被拦截
- [ ] 错误密码提示「手机号或密码不正确」
- [ ] 常规挑战玩一关 → 上传 → Supabase 表 `saves` 出现一行
- [ ] 点下载 → 金币/关卡/常规记录/每日记录与本机一致
- [ ] 关闭匿名登录后：手机号登录/云存档不受影响
