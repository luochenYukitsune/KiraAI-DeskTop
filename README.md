# kiraAI-DeskTop

<div align="center">

![KiraAI](https://img.shields.io/badge/KiraAI_v2.12.0-00d4ff?style=for-the-badge) ![Electron](https://img.shields.io/badge/Electron-28.0-47848f?style=for-the-badge) ![Python](https://img.shields.io/badge/Python-3.10+-blue?style=for-the-badge)

**KiraAI 桌面客户端 - 一键安装，开箱即用**

</div>

---

## 项目简介

kiraAI-DeskTop 是 [KiraAI](https://github.com/xxynet/KiraAI) 的 Electron 桌面客户端版本。将 Python 后端与 Vue.js SPA 前端打包为独立的 Windows 应用程序，无需手动配置 Python 环境，一键安装即可使用。

KiraAI 是一个模块化、多平台的 AI 虚拟生命体，连接大语言模型（LLM）和各种聊天平台（QQ、Telegram、微信），以虚拟生命体为中心进行交互。

## 功能特性

- **一键安装** - NSIS 安装向导，自动安装到 `%LOCALAPPDATA%\Programs\kiraAI-DeskTop`
- **自动环境配置** - 首次运行自动创建 Python 虚拟环境并安装依赖（清华镜像加速）
- **离线可用** - Vue.js SPA 前端预编译打包，无需联网下载
- **加载动画** - 优雅的启动加载界面，实时显示后端日志
- **系统集成** - 桌面快捷方式、开始菜单快捷方式
- **管理员权限** - 默认以管理员身份运行，确保所有功能正常
- **数据分离** - 用户数据独立存储在 `%LOCALAPPDATA%\kiraAI-DeskTop\`，卸载不影响数据
- **完整功能** - 包含 KiraAI v2.12.0 全部功能（MCP、Skills、异步数据库等）

## 系统要求

- **操作系统**: Windows 10/11 (x64)
- **Python**: 3.10+ (需预先安装并添加到系统 PATH)

## 安装使用

### 安装包

1. 运行 `kiraAI-DeskTop Setup 2.12.0.exe`
2. 按向导完成安装
3. 双击桌面快捷方式 `kiraAI-DeskTop` 启动

首次启动时，程序会自动：
1. 创建 Python 虚拟环境 (`venv`)
2. 安装所需依赖包
3. 初始化配置和数据文件

此过程可能需要几分钟，请耐心等待。加载窗口会实时显示启动日志。

## 目录结构

```
安装目录:
  kiraAI-DeskTop/
  └── resources/
      ├── app/                    # Electron 应用
      │   ├── main.js             # 主进程
      │   ├── preload.js          # 预加载脚本
      │   ├── loading.html        # 加载窗口
      │   └── assets/             # 图标等资源
      └── backend/                # KiraAI v2.12.0 后端
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
          ├── data/dist/          # 预编译前端 (打包时使用)
          └── scripts/run.bat     # Windows 启动脚本

用户数据:
  %LOCALAPPDATA%\kiraAI-DeskTop\
  ├── config/                    # 配置文件
  ├── memory/                    # 记忆存储
  ├── plugins/                   # 插件目录
  ├── files/                     # 文件缓存
  ├── temp/                      # 临时文件
  ├── sticker/                   # 表情包
  ├── skills/                    # 技能配置
  ├── webui.json                 # WebUI 端口配置
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

### 打包构建

```bash
# 构建前端 (Vue.js SPA)
cd backend/webui/frontend
npm install
npm run build
# 复制构建产物到 data/dist/
xcopy webui\static\dist backend\data\dist\ /E /Y
echo v2.12.0 > backend\data\dist\\.version

# 返回项目根目录
cd ..\..

# 构建 Windows 安装包
npm run build

# 构建解压版（不打包安装程序）
npm run build:dir
```

构建输出目录：`../KiraAI-Dist/`

## 配置说明

### 端口配置

默认端口：`5267`

修改 `%LOCALAPPDATA%\kiraAI-DeskTop\webui.json`：
```json
{
  "host": "127.0.0.1",
  "port": 5267
}
```

### 后端配置

所有配置文件位于 `%LOCALAPPDATA%\kiraAI-DeskTop\` 目录下。

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

1. **Python 未安装**: 确保已安装 Python 3.10+，并添加到系统 PATH
2. **端口被占用**: 修改 `webui.json` 中的端口号
3. **杀毒软件拦截**: 部分杀毒软件可能阻止程序创建虚拟环境，请添加信任

### 查看日志

启动时点击加载窗口查看实时日志，或查看 `%LOCALAPPDATA%\kiraAI-DeskTop\` 下的日志文件。

### 数据备份

用户配置、聊天记忆、插件等数据存储在 `%LOCALAPPDATA%\kiraAI-DeskTop\`，卸载程序不会删除该目录，重新安装后数据自动恢复。

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
