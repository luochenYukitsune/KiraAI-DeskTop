# KiraAI Desktop

<div align="center">

![KiraAI](https://img.shields.io/badge/KiraAI-2.9.1-00d4ff?style=for-the-badge) ![Electron](https://img.shields.io/badge/Electron-28.0-47848f?style=for-the-badge) ![Python](https://img.shields.io/badge/Python-3.10+-blue?style=for-the-badge)

**KiraAI 桌面客户端 - 一键安装，开箱即用**

</div>

---

## 项目简介

KiraAI Desktop 是 [KiraAI](https://github.com/xxynet/KiraAI) 的 Electron 桌面客户端版本。将 Python 后端与 Web 前端打包为独立的 Windows 应用程序，无需手动配置 Python 环境，一键安装即可使用。

KiraAI 是一个模块化、多平台的 AI 虚拟生命体，连接大语言模型（LLM）和各种聊天平台（QQ、Telegram、微信），以虚拟生命体为中心进行交互。

## 功能特性

- **一键安装** - NSIS 安装向导，支持自定义安装路径
- **自动环境配置** - 首次运行自动创建 Python 虚拟环境并安装依赖
- **加载动画** - 优雅的启动加载界面，实时显示后端日志
- **系统集成** - 桌面快捷方式、开始菜单快捷方式
- **完整功能** - 包含 KiraAI 2.9.1 所有功能

## 系统要求

- **操作系统**: Windows 10/11 (x64)
- **Python**: 3.10+ (需预先安装，用于后端运行)

## 安装使用

### 方式一：安装包（推荐）

1. 运行 `KiraAI Setup 2.9.1.exe`
2. 选择安装路径（建议不要安装在 `Program Files` 目录）
3. 完成安装后，双击桌面快捷方式启动

### 方式二：便携版

1. 解压 `win-unpacked` 文件夹
2. 双击 `KiraAI.exe` 启动

## 首次运行

首次启动时，程序会自动：
1. 创建 Python 虚拟环境 (`venv`)
2. 安装所需依赖包
3. 初始化配置文件

此过程可能需要几分钟，请耐心等待。加载窗口会实时显示启动日志。

## 项目结构

```
KiraAI-Electron/
├── main.js              # Electron 主进程
├── preload.js           # 预加载脚本
├── loading.html         # 加载动画窗口
├── package.json         # 项目配置
└── backend/             # KiraAI 后端代码
    ├── core/            # 核心模块
    │   ├── adapter/     # 平台适配器
    │   ├── agent/       # Agent 执行器
    │   ├── chat/        # 聊天会话管理
    │   ├── config/      # 配置管理
    │   ├── persona/     # 人设管理
    │   ├── plugin/      # 插件系统
    │   ├── provider/    # 模型提供商
    │   └── utils/       # 工具函数
    ├── webui/           # Web 管理界面
    ├── scripts/         # 启动脚本
    ├── data/            # 数据目录
    │   ├── config/      # 配置文件
    │   ├── memory/      # 记忆存储
    │   └── plugins/     # 插件目录
    └── main.py          # 后端入口
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
# 构建 Windows 安装包
npm run build

# 构建解压版（不打包安装程序）
npm run build:dir
```

构建输出目录：`KiraAI-Dist/`

## 配置说明

### 后端配置

配置文件位于 `backend/data/config/` 目录：

| 文件 | 说明 |
|------|------|
| `webui.json` | WebUI 服务配置（端口等） |
| `system_config.json` | 系统配置 |
| `skills.json` | 技能配置 |
| `mcp.json` | MCP 配置 |

### 端口配置

默认端口：`5267`

修改 `backend/data/webui.json`：
```json
{
  "host": "127.0.0.1",
  "port": 5267
}
```

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

### Plugin（插件）
- Chat - 聊天增强
- Memory - 记忆管理
- Search - 搜索功能
- Sticker - 表情包
- File - 文件处理
- Session Tools - 会话工具

## 常见问题

### 启动失败

1. **Python 未安装**: 确保已安装 Python 3.10+，并添加到系统 PATH
2. **端口被占用**: 修改 `webui.json` 中的端口号
3. **权限问题**: 不要安装在 `Program Files` 目录

### 查看日志

启动时点击加载窗口的「查看详细日志」按钮，或查看 `backend/data/log.log` 文件。

## 相关链接

- [KiraAI 主项目](https://github.com/xxynet/KiraAI)
- [KiraAI 文档](https://docs.kira-ai.top)
- [问题反馈](https://github.com/xxynet/KiraAI/issues)

## 许可证

MIT License

---

<div align="center">

**Light up the digital soul**

</div>
