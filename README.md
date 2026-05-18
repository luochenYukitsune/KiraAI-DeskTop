# kiraAI-DeskTop

<div align="center">

![KiraAI](https://img.shields.io/badge/KiraAI-bundled_from_main-00d4ff?style=for-the-badge) ![Electron](https://img.shields.io/badge/Electron-28.0-47848f?style=for-the-badge) ![Python](https://img.shields.io/badge/Python-3.10+-blue?style=for-the-badge)

**KiraAI 桌面客户端 — Electron 外壳，CI 时按需打包最新 KiraAI 源代码**

</div>

---

## 项目简介

kiraAI-DeskTop 是 [KiraAI](https://github.com/xxynet/KiraAI) 的 Electron 桌面客户端。**本仓库只保留 Electron 外壳**（启动器、加载页面、安装器配置），KiraAI 后端源码在 CI 构建时从 `xxynet/KiraAI` 仓库的 `main` 分支克隆并打入安装包，因此每次发版自动跟随 KiraAI 主仓库的最新代码。

## 仓库结构

```
.
├── main.js              # Electron 主进程：拉起 Python 后端 + 健康检查 + 加载窗口
├── preload.js           # Electron preload
├── loading.html         # 启动加载页
├── assets/KD-LOGO.ico   # Windows 图标（mac/linux 由 CI 转换生成）
├── build/installer.nsh  # NSIS 自定义安装脚本
├── package.json         # electron-builder 配置（三平台 target）
└── .github/workflows/
    └── build.yml        # CI：clone KiraAI main → 构建前端 → 三平台打包
```

构建时 CI 会在仓库根目录创建 `backend/`，内容是 KiraAI 源码 + 前端构建产物。该目录被 `.gitignore` 排除，永远不会进入提交。

## 系统要求（终端用户）

- **Windows 10/11 (x64)** — 需要 Python 3.10+ 在 PATH
- **macOS 12+（Intel / Apple Silicon）** — 需要 `python3` 在 PATH
- **Linux (x64)** — 需要 `python3` 在 PATH

首次启动时桌面应用会在用户数据目录下创建 Python 虚拟环境并安装 `requirements.txt`。

## 构建产物（由 GitHub Actions 产出）

**Desktop App（Electron + Python 后端）：**

| 平台 | 产物 |
|------|------|
| Windows x64 | `kiraAI-DeskTop Setup <version>.exe` (NSIS) |
| macOS Intel / Apple Silicon | `kiraAI-DeskTop-<version>.dmg` / `-arm64.dmg` |
| Linux x64 | `*.AppImage` / `*.deb` |

**Python Backend Only（跨平台一份）：**

| 内容 | 文件 |
|------|------|
| KiraAI source + 预构建前端 dist | `kiraAI-backend-<YYYYMMDD>-<shortsha>.zip` |

解压后用 `backend/scripts/run.sh`（mac/linux）或 `backend/scripts/run.bat`（Windows）启动 —— 仅需要用户机器上有 Python 3.10+。

## 触发构建

CI 由 [.github/workflows/build.yml](.github/workflows/build.yml) 定义，三种触发方式：

- **手动触发** — Actions 页面点 `Run workflow`：
  - `kiraai_ref`（默认 `main`，也可填 tag / commit SHA）
  - `force`（默认 `false`，仅对 schedule 触发的"已构建过"场景生效）
- **push 到本仓库 `main`** — 外壳代码改动时自动出三平台包
- **每日定时检测上游** — 每天 UTC 16:00（北京 00:00）运行一个轻量 `check` job：
  - 用 `git ls-remote` 拿 KiraAI `main` 的最新 commit SHA
  - 查 Actions cache 里 key `kiraai-built-<SHA>` 是否存在
  - **不存在** → 触发三平台构建，成功后写入 marker
  - **已存在** → 跳过，不消耗矩阵构建的 CI 分钟

也就是说定时任务只在上游真的有新 commit 时才出包，避免无意义的 nightly。需要强制重建已构建过的 SHA 时，用 manual dispatch 勾上 `force`。

## Release 发布

- **schedule 检测到上游有更新** 或 **手动 `workflow_dispatch`** 触发的构建，会自动发布为 GitHub **Pre-release（Nightly）**：
  - tag：固定 `nightly`（滚动 tag，每次发布前先删旧 release + tag 再重建，避免 assets 堆积）
  - 标题：`Nightly Build YYYY-MM-DD`（每次刷新成当次构建日期）
  - 标记 `prerelease: true`，不抢 Latest
  - 产物文件名包含 `<X.Y.Z>-nightly.<YYYYMMDD>-<shortsha>`，从文件名能看出具体版本
  - body 含 unsigned 提示 + macOS `xattr -cr` 解决"damaged"提示 + 产物对照表 + KiraAI commit 链接
- **push 到本仓库 main** 触发的构建只产 artifacts，不发 Release（外壳代码改动不算 KiraAI 版本变化）

构建产物也都会上传到 workflow artifacts（保留 90 天），按平台分组：`kiraAI-DeskTop-windows` / `kiraAI-DeskTop-macos` / `kiraAI-DeskTop-linux` / `kiraAI-DeskTop-backend`。

## 本地开发

只调试外壳（无后端，主窗口会无限重连）：

```bash
npm install
npm start
```

完整本地构建（需先手动准备 KiraAI 后端）：

```bash
# 1. 把 KiraAI 源码克隆到 backend/
git clone --depth=1 https://github.com/xxynet/KiraAI.git backend

# 2. 构建 WebUI 前端并铺到运行时目录
cd backend/webui/frontend && npm install && npm run build && cd -
mkdir -p backend/data/dist
cp -R backend/webui/static/dist/. backend/data/dist/   # 或 backend/webui/frontend/dist

# 3. 出包（按当前平台）
npm install
npm run build:win    # 或 build:mac / build:linux
```

产物在 `dist/`。

## 修改外壳行为

- 主进程逻辑：[main.js](main.js)
- 加载页样式 / 文案：[loading.html](loading.html)
- Windows 安装器：[build/installer.nsh](build/installer.nsh)、`package.json` 的 `build.nsis` 段
- mac/linux target 配置：`package.json` 的 `build.mac` / `build.linux` 段

## 图标说明

当前 `assets/KD-LOGO.ico` 是 Windows 图标（最大 24×24）。mac/linux 包由 CI 用 ImageMagick 从 .ico 升采样到 1024×1024 生成，**清晰度有限**。建议补一张高分辨率源图（例如 1024×1024 PNG），放到 `build/icon.png` 并在 `.gitignore` 中放出（去掉对应那行），CI 就会优先用它。

## 友情链接

- [KiraAI 主项目](https://github.com/xxynet/KiraAI)
- [KiraAI 文档](https://docs.kira-ai.top)
- [问题反馈](https://github.com/xxynet/KiraAI/issues)

## 许可证

AGPL-3.0 License

---

<div align="center">

**Light up the digital soul**

</div>
