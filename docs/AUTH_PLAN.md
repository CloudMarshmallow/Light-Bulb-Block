# 登录与存档方案（Supabase Auth）

> 原则：**单机 PVE 游戏不因登录服务不可用而不可玩**。登录只负责拿到稳定的 `user_id`，其余全部本地完成。

## 1. 边界

| 模块 | 职责 |
|---|---|
| Supabase Auth | 只负责登录并返回稳定的 `user_id`（UUID） |
| `scripts/auth.gd`（autoload `Auth`） | 登录状态机、session 持久化、离线回退 `local_guest`、登录后存档合并决策 |
| `scripts/auth_logic.gd` | 纯逻辑（路径 / user_id 校验 / 合并决策），可单测 |
| `scripts/user_data.gd`（autoload `UserData`） | 游戏数据读写，路径固定为 `user://saves/<user_id>/slot_0.json` |

## 2. 存档路径

```
user://saves/<user_id>/slot_0.json
```

- 已登录：`<user_id>` = Supabase Auth 返回的 UUID
- 本地临时身份：`<user_id>` = `local_guest`
- 该路径之外的任何文件都不参与玩家数据（`auth_session.json` 只存登录凭证）

## 3. 启动流程（永不阻塞）

```
游戏启动
 ├─ Auth._ready()
 │    ├─ 读配置（环境变量 SUPABASE_URL / SUPABASE_ANON_KEY → user://auth_config.json）
 │    ├─ 读 user://auth_session.json（有 refresh_token 则可续登）
 │    ├─ 未配置 / 无凭证 → state = guest，user_id = local_guest
 │    └─ 已配置 → 后台 HTTPRequest 尝试登录（8s 超时，不 await 阻塞主流程）
 ├─ UserData._ready() → 从 save_path() 读档（此时一定是合法 user_id，默认 local_guest）
 └─ 主菜单立刻可玩
```

登录成功后会 `state_changed` 通知：`UserData` 重新读账号存档，主菜单刷新登录图标；若需合并则弹一次选择框。

失败/超时/未配置：保持 `local_guest`，`last_error` 记录原因，界面显示「本地模式」，**不弹任何阻断式错误**。

## 4. 登录成功后的存档决策（一次性）

| 本地 `local_guest` 有存档 | 账号目录有存档 | 行为 |
|---|---|---|
| 有 | 无 | **自动合并到账号**（复制 `local_guest/slot_0.json` → `<user_id>/slot_0.json`） |
| 有 | 有 | 弹窗二选一：**保留本地**（用本地覆盖账号）或 **使用账号存档**（丢弃本地覆盖） |
| 无 | 有 | 直接加载账号存档 |
| 无 | 无 | 无操作（新账号新档） |

选择结果不可逆地点写入账号目录；`local_guest` 的旧文件保留作为本地备份（不主动删除）。

## 5. 配置 Supabase

1. 建 Supabase 项目：Authentication → Providers → Email 保持启用；匿名登录关闭（本项目已改为邮箱 + 密码登录）。
2. **密钥类型必须选对**（新版 Supabase API Keys）：
   - ✅ 客户端用：`sb_publishable_...`（Dashboard → Project Settings → API Keys → Publishable key），或旧版 `anon` key（`eyJ...`）
   - ❌ 绝不能用：`sb_secret_...`（Secret key，等同 service_role）、旧版 `service_role` key
   - 误用 secret key 时 Supabase 网关会返回 `401 UNAUTHORIZED_INVALID_API_KEY_TYPE`；本项目的 `Auth` 会在启动时直接拒绝这种配置（保持 `local_guest`，并显示错误提示）。
3. 任选其一配置：
   - 环境变量：`SUPABASE_URL`、`SUPABASE_ANON_KEY`（或 `SUPABASE_PUBLISHABLE_KEY`）
   - 或复制 `auth_config.example.json` 为 `user://auth_config.json`：
     ```json
     { "url": "https://xxxx.supabase.co", "publishable_key": "sb_publishable_..." }
     ```
4. 客户端使用的端点：
   - 无 session：`POST /auth/v1/signup` + `{"data":{},"gotrue_meta_security":{}}`（匿名注册）
   - 有 refresh_token：`POST /auth/v1/token?grant_type=refresh_token`
   - 请求头：`apikey: <publishable/anon key>`、`Content-Type: application/json`

> **安全提醒**：Secret key / service_role key 只能放服务端（Edge Function、脚本）。一旦贴到聊天、仓库或客户端，
> 应当立即到 Dashboard **Rotate / Revoke**。本项目不会把任何密钥写入仓库，配置只放 `user://auth_config.json` 或环境变量。

## 6. 安全与边界

- `user_id` 只允许 `[A-Za-z0-9_-]`（`AuthLogic.valid_user_id`），防止路径穿越；非法 id 一律回退 `local_guest`。
- 存档只在本地磁盘；不做云同步上传（本方案边界：登录仅提供身份，不搬运进度）。
- 退出登录：回到 `local_guest`，读取本地临时存档；账号存档保留在账号目录。
- 未来如需云存档，可在 `Auth.state_changed` 后由独立同步器读写 Supabase Storage/PostgREST，不影响本方案接口。

## 7. 自动化验证

- 单测 `tests/test_engine.gd::_test_auth_logic`：路径格式、非法 id 回退、四种合并决策。
- `--ui-test`：默认 `user_id == local_guest`、存档文件确实创建在 `user://saves/local_guest/slot_0.json`、Auth autoload 存在。
- 离线可用性：不配置 Supabase 启动游戏，应直接进入本地模式并可正常游玩/存档。


## 6. 云存档（上传/下载）

表结构、RLS 策略、字段说明与验收清单见 `docs/SAVE_DATA.md`，SQL 见 `docs/CLOUD_SAVE.sql`。

- 上传：`CloudSave.upload(UserData.export_dict())` → PostgREST `POST /rest/v1/saves?on_conflict=user_id`
- 下载：确认后 `CloudSave.download()` → `GET /rest/v1/saves?user_id=eq.<uuid>` → `UserData.overwrite_from_dict(data)`
- 登录/未登录、网络失败都只给短提示，不影响本地游玩。