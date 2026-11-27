# 灯泡方块（Light Blocks）

一款像素风格的点灯解谜小游戏：点一下方块，它和上下左右四格一起翻转亮灭，把整盘灯全部点亮即可过关。

> 使用 **Godot 4.7.2** + **GDScript** 开发，Windows 桌面版，单文件发布。
> **下载压缩包 → 解压 → 双击 `灯泡方块.exe` 即可游玩。**

<p align="center">
  <a href="https://github.com/CloudMarshmallow/Light-Bulb-Block/releases/latest/download/LightBlocks-v6.1-Windows-x64.zip">
    <img src="https://img.shields.io/badge/Download-Windows%20x64%20v6.1-2ea043?style=for-the-badge&logo=windows&logoColor=white" alt="Download Windows x64 v6.1">
  </a>
</p>

**[⬇️ 点此直接下载最新压缩包（Windows 64 位）](https://github.com/CloudMarshmallow/Light-Bulb-Block/releases/latest/download/LightBlocks-v6.1-Windows-x64.zip)**

---

## 玩法

### 基本规则

- **点方格**：点击任意方块，该方块与其**上下左右四邻**一起切换亮/灭。
- **目标**：让棋盘上所有方块都亮起，即通关。
- **步数限制**：每关都有步数上限（比最优解略宽裕）；HUD 显示「已用 / 上限」，接近上限变橙，用尽即失败（可重试本关或返回主页）。

### 两种挑战模式

| 模式 | 说明 |
|---|---|
| **常规挑战** | 无限关卡，难度缓慢上升；第 100 关后难度加速提升。**可离线游玩**，进度自动保存，下次打开会从上次的关卡继续。 |
| **每日挑战** | 每天固定 **10 关**，需**联网**获取服务器日期（同一天同一时区题目相同）。通关全部 10 关奖励 **100 金币**，**每天只能领取一次**，通关后当天入口显示「今日已完成」。 |

- 每局题目随机生成；每日挑战按当天日期生成，重进当天题目不变。
- 常规挑战不计时也不结束；每日挑战通关后显示本次总用时。

### 辅助功能

| 图标 | 功能 | 限制 |
|---|---|---|
| ↶ 撤销 | 撤回上一步 | 每关 **1 次** |
| ⟲ 重置 | 把棋盘恢复到本关初始状态 | **不限次数** |
| 💡 提示 | 高亮一个应该点击的方块 | 每关 **1 次** |
| ⏸ 暂停 | 继续 / 重开本关 / 返回主页 | — |

### 变异关卡

每 5 关会出现一次变异（每日挑战固定在第 6 / 8 / 10 关），进入前会弹出警示说明：

| 变异 | 效果 |
|---|---|
| 👁 **幽暗** | 所有方块几乎同色，只有极细微的明暗差别，印花也变得模糊——需要靠记忆和推理 |
| ❄ **冰封** | 部分方块被冰封，无法点击 |
| 🔒 **硬化** | 本关的「提示」被禁用 |

变异方块上会显示专属印花（雪花 / 冰面 / 模糊点阵），并配有专属音效。

### 金币与皮肤商店

- **金币**：显示在右上角；主要来源为每日挑战通关（+100）。
- **商店**（主菜单 🛍）：6 种方块风格 —

| 风格 | 价格 |
|---|---|
| 暖黄（默认） | 免费 |
| 樱花 | 100 |
| 海洋 | 150 |
| 霓虹 | 200 |
| 森野 | 250 |
| 金砖 | 300 |

- 每种风格有独立配色与印花（点 / 斜线 / 棋盘 / 十字 / 网格），购买后立即应用并保存。
- 金币不足会提示还差多少；购买成功会提示并播放金币音效。

### 通关记录

- 记录页（主菜单 🕒）用图标切换「每日 / 常规」两套记录；
- 顶部显示通关次数与总用时，下方为每一局的日期、用时、关卡数；
- 常规挑战的记录会随账号同步（登录状态下）。

### 其他

- **玩法说明页**：主菜单「?」打开，包含玩法、变异、图标含义的完整说明；首次开始游戏会自动弹出。
- **设置**（主菜单 ⚙）：音量、音乐开关、全屏、窗口尺寸（1024×576 / 1280×720 / 1600×900 / 1920×1080）、重置常规进度。
- **登录**（主菜单左上角云图标）：手机号 + 密码注册/登录，可上传/下载云存档。**账号配置已随程序内置，开箱即用**；登录不是必须的，**断网或未登录也能正常游玩常规挑战**。

---

## 技术栈

| 项目 | 说明 |
|---|---|
| 引擎 | **Godot 4.7.2**（GL Compatibility 渲染后端，兼容性最好） |
| 语言 | **GDScript 2.0**（全静态类型） |
| 平台 | Windows（x86_64 桌面版） |
| 分辨率 | 逻辑分辨率 1280×720，`canvas_items` 拉伸，支持任意窗口尺寸 |
| UI | 100% 程序化构建（无编辑器布局），32×32 像素图标 + 图标优先设计 |
| 解谜算法 | **GF(2) 高斯消元** 求最小步数解，配合反向生成保证每题可解且有唯一目标步数 |
| 存档 | 本地 JSON（`user://saves/<id>/slot_0.json`），原子写入 + 备份回退 |
| 登录 / 云存档 | Supabase（Auth 手机号登录 + PostgREST 云存档表，行级安全 RLS） |
| 音频 | 程序合成音效与循环 BGM（WAV） |
| 美术 | 开源素材 + 程序生成，像素化处理，来源与授权见 `art/ICON_CREDITS.md` |

### 目录结构

```
灯泡方块/
├── project.godot          # 工程配置（1280×720，gl_compatibility）
├── icon.png               # 游戏图标
├── export_presets.cfg     # Windows 导出预设（单文件，内嵌资源与账号配置）
├── auth_config.json       # 内置账号服务配置（随程序分发）
├── scenes/main.tscn       # 唯一场景（UI 全程序化）
├── scripts/
│   ├── puzzle_engine.gd   # GF(2) 求解 + 反向生成
│   ├── level_plan.gd      # 双模式关卡计划与奖励常量
│   ├── user_data.gd       # 存档 / 金币 / 皮肤 / 记录
│   ├── auth.gd            # 登录（Supabase Auth）
│   ├── auth_logic.gd      # 登录存档纯逻辑（可单测）
│   ├── cloud_save.gd      # 云存档上传下载
│   ├── world_time.gd      # 服务器时间（每日挑战）
│   ├── styles.gd          # 6 种皮肤数据
│   ├── pattern_overlay.gd # 皮肤印花层
│   ├── mutation_decal.gd  # 变异印花层
│   ├── leaves_fx.gd       # 物理落叶 / 尘埃 / 影子
│   ├── sun_system.gd      # 实时太阳（按时区）
│   ├── sun_rays.gd        # 阳光光束层
│   ├── ui_kit.gd          # 图标 / 按钮 / 面板工厂
│   └── main.gd            # 所有界面与游戏流程
├── shaders/sun_rays.gdshader
├── art/                   # 背景、图标、素材授权
├── audio/                 # 音效与 BGM
├── docs/                  # Supabase / 云存档配置文档
├── tests/test_engine.gd   # 单元测试
└── tools/                 # 素材生成脚本
```

---

## 下载与安装

### ⬇️ 一键下载

**直接下载最新版本（Windows 64 位）：**

> **https://github.com/CloudMarshmallow/Light-Bulb-Block/releases/latest/download/LightBlocks-v6.1-Windows-x64.zip**

点上面的链接即可直接下载压缩包，无需进入 Releases 页面。

### 安装步骤

1. **下载压缩包**（`LightBlocks-vX.X-Windows-x64.zip`）；
2. **解压**到任意文件夹（整个文件夹解压，不要只拖出 exe）；
3. 双击 **`灯泡方块.exe`** 即可开始游戏（单文件，已内嵌全部资源与账号配置）；
4. 无需安装，无需管理员权限；存档自动保存在本机用户目录。

> 首次运行如遇 Windows SmartScreen 提示「已保护你的电脑」，点「更多信息」→「仍要运行」即可（因为本游戏未做商业代码签名）。

**系统要求**

| 项目 | 最低配置 |
|---|---|
| 系统 | Windows 10 / 11（64 位） |
| 显卡 | 支持 OpenGL 3.3 的集成显卡即可 |
| 内存 | 2 GB |
| 磁盘 | 约 110 MB |
| 网络 | 可选（仅每日挑战与云存档需要） |

### 存档位置

```
%APPDATA%\Godot\app_userdata\灯泡方块\saves\
```

- 未登录：`saves/local_guest/slot_0.json`
- 已登录：`saves/<账号ID>/slot_0.json`
- 删除该目录即可重置全部进度。

---

## 开发与测试

```powershell
$godot = "Godot.exe"
$game  = "本目录"

# 单元测试（求解器 / 关卡计划 / 皮肤 / 登录逻辑 / 时间工具）
& $godot --headless --path $game --script res://tests/test_engine.gd   # 期望 FAILURES=0

# 自动演示（常规+每日全部关卡自动最优解）
& $godot --headless --path $game -- --auto-demo                        # 期望 AUTO_DEMO_DONE fails=0

# 界面端到端测试
& $godot --headless --path $game -- --ui-test                          # 期望 UI_TEST_RESULT fails=0

# 素材重新生成（可选）
& $godot --headless --path $game --script res://tools/gen_icons.gd
& $godot --headless --path $game --script res://tools/pixelate_bg.gd
```

---

## 云存档配置（可选）

项目已内置 `auth_config.json`，开箱即用。若需换成自己的 Supabase 项目：

1. 执行 `docs/CLOUD_SAVE.sql` 建表与 RLS；
2. 修改 `auth_config.json` 里的 `url` 和 `anon_key`（**只能用 publishable/anon key，不能用 secret/service_role key**）；
3. 重新导出。

详细流程见 [`docs/SUPABASE_SETUP.md`](docs/SUPABASE_SETUP.md)、[`docs/SAVE_DATA.md`](docs/SAVE_DATA.md)、[`docs/AUTH_PLAN.md`](docs/AUTH_PLAN.md)。

---

## 素材授权

- 游戏图标：game-icons.net "light-bulb"（CC BY 3.0）+ 程序合成背景
- 金币图标：game-icons.net "two-coins"（CC BY 3.0）
- 商店购物车：Material Symbols "shopping-cart"（Apache-2.0）
- 背景图：项目方提供并程序像素化；其余图标、音效、BGM 均为程序生成

完整清单见 `art/ICON_CREDITS.md`。

---

## 已知限制

1. **未做代码签名**：首次运行 Windows SmartScreen 会提示，点「更多信息 → 仍要运行」即可。
2. **每日挑战依赖网络时间**：时间服务不可达时该模式被拦截（常规挑战不受影响）。
3. **云同步并发**：极短时间内多次改动可能跳过当次自动上传，下一次保存会补传。
4. **历史记录上限 20 条**。
