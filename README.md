# kiraAI-DeskTop

<div align="center">

![KiraAI](https://img.shields.io/badge/KiraAI_v2.13.0-00d4ff?style=for-the-badge) ![Electron](https://img.shields.io/badge/Electron-28.0-47848f?style=for-the-badge) ![Python](https://img.shields.io/badge/Python-3.10+-blue?style=for-the-badge)

**KiraAI 桌面客户端 - 一键安装，开箱即用**

</div>

---

## 项目简介

kiraAI-DeskTop 是 [KiraAI](https://github.com/xxynet/KiraAI) 的 Electron 桌面客户端版本。将 Python 后端与 Vue.js SPA 前端打包为独立的 Windows / macOS 应用程序，无需手动配置 Python 环境，一键安装即可使用。

KiraAI 是一个模块化、多平台的 AI 虚拟生命体，连接大语言模型（LLM）和各种聊天平台（QQ、Telegram、微信），以虚拟生命体为中心进行交互。

## 功能特性

- **跨平台支持** - 提供 Windows NSIS 安装包和 macOS dmg（支持 Apple Silicon + Intel）
- **一键安装** - Windows NSIS 向导自动安装到 `%LOCALAPPDATA%\Programs\kiraAI-DeskTop`；macOS 拖动到 Applications 即可
- **自动环境配置** - 首次运行自动检测 Python 3.10+，创建虚拟环境并安装依赖
- **离线可用** - Vue.js SPA 前端预编译打包（Windows），无需联网下载
- **加载动画** - 优雅地启动加载界面，实时显示后端日志
- **系统集成** - Windows 桌面/开始菜单快捷方式；macOS Launchpad 集成
- **管理员权限**（Windows）- 默认以管理员身份运行，确保所有功能正常
- **macOS 原生交互** - 关闭窗口仅隐藏，App 与后端保持运行；点击 Dock 图标即可重新唤起；Cmd+Q 才真正退出
- **数据分离** - 用户数据独立存储于系统标准位置，卸载不影响数据
  - Windows: `%LOCALAPPDATA%\kiraAI-DeskTop\`
  - macOS: `~/Library/Application Support/kiraAI-DeskTop/backend/`
- **完整功能** - 包含 KiraAI v2.13.0 全部功能（MCP、Skills、异步数据库等）

## 系统要求

- **操作系统**: Windows 10/11 (x64) 或 macOS 11+ (Apple Silicon / Intel)
- **Python**: 3.10+
  - Windows: 需预先安装并添加到系统 PATH
  - macOS: 推荐通过 [python.org](https://www.python.org/downloads/) 或 Homebrew (`brew install python@3.12`) 安装。系统自带的 `/usr/bin/python3` 是 3.9，不可用

## 安装使用

### Windows 安装

1. 运行 `kiraAI-DeskTop Setup <version>.exe`
2. 按向导完成安装
3. 双击桌面快捷方式 `kiraAI-DeskTop` 启动

### macOS 安装

1. 下载对应架构的 dmg：
   - Apple Silicon (M1/M2/M3/M4)：`kiraAI-DeskTop-x.x.x-arm64.dmg`
   - Intel：`kiraAI-DeskTop-x.x.x.dmg`
2. 双击 dmg，将 `kiraAI-DeskTop` 拖到 `Applications` 文件夹
3. 首次打开会被 Gatekeeper 拦截（应用未签名）：
   - 在 Finder 里**右键**应用 → 「打开」→ 「打开」确认；或
   - 终端执行：`xattr -cr "/Applications/kiraAI-DeskTop.app"`

### 首次启动

启动时程序会自动：
1. 检测 Python 3.10+ 解释器
2. 创建 Python 虚拟环境 (`venv`)
3. 安装所需依赖包
4. 初始化配置和数据文件

此过程可能需要几分钟，请耐心等待。加载窗口会实时显示启动日志。

### macOS 使用说明

- **关闭窗口不退出**：点击窗口左上角的红色关闭按钮只会隐藏窗口，App 和后端继续在后台运行（macOS 标准交互）。点击 Dock 图标即可重新唤起窗口。
- **真正退出**：使用 `Cmd+Q` 或菜单栏 → KiraAI → 退出，会同时关停后端进程。
- **登录页令牌位置**：登录页提示"在 data/webui.json 中获取令牌"，在 macOS 上 Electron 会自动将该提示替换为实际路径 `~/Library/Application Support/kiraAI-DeskTop/backend/webui.json`。

## 目录结构

```text
安装目录（Windows）: %LOCALAPPDATA%\Programs\kiraAI-DeskTop\
安装目录（macOS）  : /Applications/kiraAI-DeskTop.app/Contents/
  └── resources/                  # Windows 小写 / macOS 大写 Resources
      ├── app/                    # Electron 应用
      │   ├── main.js             # 主进程
      │   ├── preload.js          # 预加载脚本
      │   ├── loading.html        # 加载窗口
      │   └── assets/             # 图标等资源
      └── backend/                # KiraAI v2.13.0 后端
          ├── main.py             # 后端入口
          ├── core/               # 核心模块
          │   ├── adapter/        # 平台适配器 (QQ/Telegram/微信/B站)
          │   ├── agent/          # Agent 执行器 & MCP/Skills
          │   ├── chat/           # 聊天会话管理
          │   ├── config/         # 配置管理
          │   ├── db/             # 异步数据库 (aiosqlite)
          │   ├── persona/        # 人设管理
          │   ├── plugin/         # 插件系统
          │   ├── provider/       # 模型提供商
          │   ├── tag/            # 标签系统
          │   ├── utils/          # 工具函数 & dist版本检查
          │   └── workflow/       # 工作流引擎
          ├── webui/              # Web 管理界面 (Vue.js SPA)
          │   ├── app.py          # Flask 应用
          │   ├── routes/         # API 路由
          │   └── static/dist/    # 前端构建产物
          ├── venv/               # Python 虚拟环境（首次启动时创建）
          └── scripts/
              ├── run.bat         # Windows 启动脚本
              └── run.sh          # macOS / Linux 启动脚本

用户数据:
  Windows: %LOCALAPPDATA%\kiraAI-DeskTop\
  macOS  : ~/Library/Application Support/kiraAI-DeskTop/backend/
  ├── config/                    # 配置文件
  ├── memory/                    # 记忆存储
  ├── plugins/                   # 插件目录
  ├── plugin_data/               # 插件运行时数据
  ├── files/                     # 文件缓存
  ├── temp/                      # 临时文件
  ├── sticker/                   # 表情包
  ├── skills/                    # 技能配置
  ├── tools/                     # 工具
  ├── dist/                      # 前端 SPA（首次启动下载，仅 macOS）
  ├── webui.json                 # WebUI 端口配置
  ├── .jwt_secret                # JWT 密钥
  ├── log.log                    # 后端日志
  └── data.db                    # 主数据库
```

## 开发构建

### 环境准备

```bash
# 安装 Node.js 依赖
npm install

# 开发模式运行
npm start
```

### 打包构建（Windows）

PowerShell / CMD：

```powershell
# 构建前端 (Vue.js SPA)
cd backend\webui\frontend
npm install
npm run build
# 复制构建产物到 data/dist/
xcopy ..\static\dist ..\..\data\dist\ /E /Y
echo v2.13.0 > ..\..\data\dist\.version

# 返回项目根目录
cd ..\..\..

# 构建 NSIS 安装包
npm run build

# 构建解压版（不打包安装程序）
npm run build:dir
```

### 打包构建（macOS）

macOS 的前端 dist 由后端首次启动时按需下载，**无需**手动构建前端目录。

```bash
# 在仓库根目录执行（必须在 macOS 主机上）
npm install
npm run build:mac          # 同时打 arm64 + x64 dmg

# 仅打单一架构：
npm run build:mac:arm      # Apple Silicon
npm run build:mac:x64      # Intel
```

构建输出目录：`../KiraAI-Dist/`

> macOS 打包注意事项：
> - 必须在 macOS 主机上执行（dmg 依赖 `hdiutil` 等系统工具）
> - 当前配置未做代码签名（`identity: null`），分发给他人需要 Apple Developer ID 签名 + 公证（notarization）
> - 应用图标 `assets/KD-LOGO.icns` 由 `assets/KD-LOGO.ico` 通过 `sips` + `iconutil` 生成

## 配置说明

### 端口配置

默认端口：`5267`

修改 `webui.json`（位置见下方）：
```json
{
  "host": "127.0.0.1",
  "port": 5267
}
```

### 后端配置

所有配置文件位于用户数据目录下：
- **Windows**: `%LOCALAPPDATA%\kiraAI-DeskTop\`
- **macOS**: `~/Library/Application Support/kiraAI-DeskTop/backend/`

| 文件 | 说明 |
|------|------|
| `webui.json` | WebUI 服务配置（监听地址、端口） |
| `config/system_config.json` | 系统配置 |
| `config/skills.json` | 技能配置 |
| `config/mcp.json` | MCP 配置 |

## 功能模块

### Provider（模型提供商）
- OpenAI
- ModelScope
- SiliconFlow CN
- VolcEngine

### Adapter（适配器）
- QQ (NapCat)
- Telegram
- 微信 (WeChat OC)
- Bilibili

### Plugin（插件）
- Chat - 聊天增强
- Memory - 记忆管理
- Search - 搜索功能
- Sticker - 表情包
- File - 文件处理
- Session Tools - 会话工具
- Kira-AI - AI 核心

## 常见问题

### 启动失败

1. **Python 未安装**:
   - Windows: 确保已安装 Python 3.10+，并添加到系统 PATH
   - macOS: 不能用系统自带的 `/usr/bin/python3`（3.9）。通过 [python.org](https://www.python.org/downloads/) 或 Homebrew (`brew install python@3.12`) 安装。`run.sh` 会自动从 `/opt/homebrew/bin`、`/usr/local/bin`、`/Library/Frameworks/Python.framework` 等位置寻找 3.10+ 解释器
2. **端口被占用**: 修改 `webui.json` 中的端口号
3. **杀毒软件拦截**（Windows）: 部分杀毒软件可能阻止程序创建虚拟环境，请添加信任
4. **Gatekeeper 拦截**（macOS）: 应用未签名时首次打开会被拦截，右键 → 打开，或在终端执行 `xattr -cr "/Applications/kiraAI-DeskTop.app"`

### 查看日志

启动时点击加载窗口查看实时日志，或查看用户数据目录下的 `log.log` 文件：
- **Windows**: `%LOCALAPPDATA%\kiraAI-DeskTop\log.log`
- **macOS**: `~/Library/Application Support/kiraAI-DeskTop/backend/log.log`

### 数据备份

用户配置、聊天记忆、插件等数据存储在用户数据目录下，卸载/删除应用不会删除该目录，重新安装后数据自动恢复。
- **Windows**: `%LOCALAPPDATA%\kiraAI-DeskTop\`
- **macOS**: `~/Library/Application Support/kiraAI-DeskTop/backend/`

## 友情链接

- [KiraAI 主项目](https://github.com/xxynet/KiraAI)
- [KiraAI 文档](https://docs.kira-ai.top)
- [问题反馈](https://github.com/xxynet/KiraAI/issues)

## 许可证

AGPL3.0 License

---

<div align="center">

**Light up the digital soul**

</div>
