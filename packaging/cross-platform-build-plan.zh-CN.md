# Hermes Agent 三端全功能可运行包计划

## 打包口径

用户要求：安装包需要包含所有功能。

执行定义：

- 默认按全功能运行时包构建，安装 `pyproject.toml` 中的 `.[all]` extra。
- 随包内置已构建 Web UI：`hermes_cli/web_dist`。
- 随包内置技能目录：`skills/` 与 `optional-skills/`。
- 启动时设置中文与打包环境变量：`HERMES_LANG=zh_CN`、`HERMES_SKIP_WEB_BUILD=1`、`HERMES_BUNDLED_SKILLS`、`HERMES_OPTIONAL_SKILLS`。
- 外部服务类功能仍需要用户自行配置 API key、OAuth、机器人 token、Webhook、设备或云账号；安装包不能也不应内置用户密钥。
- 平台不支持的依赖不强行打包。例：Windows 使用 `pywinpty`，macOS/Linux 使用 `ptyprocess`；`matrix` extra 在仓库中只纳入 Linux `.[all]`；Python 3.12 才可用的 `yc-bench` 需要单独开启。
- `rl` extra 依赖 Git 源包，风险和体积都高，脚本提供显式开关开启，不作为普通全功能包默认项。

## macOS arm64 中文包

当前既有产物：

- `dist-macos-cn/Hermes Agent.app`
- `dist-macos-cn/Hermes CLI.command`
- `dist-macos-cn/Hermes-Agent-0.9.0-macOS-arm64-zh.zip`

已验证的既有结果：

- `cd web && npm run build` 通过，产出 `hermes_cli/web_dist`。
- PyInstaller `onedir` 通过，二进制为 macOS arm64 Mach-O。
- 打包后二进制 `version` 可运行。
- 打包后 Dashboard 在 `HERMES_SKIP_WEB_BUILD=1` 下可启动，并返回 `lang="zh-CN"` 的首页 HTML。
- `.app/Contents/MacOS/Hermes Agent` 启动器可启动 Dashboard。

全功能调整：

- `packaging/macos/build_macos_app.sh` 默认执行 `uv pip install --python venv/bin/python -e '.[all]' pyinstaller` 后再打包。
- 如需包含 RL Git 源扩展，设置 `HERMES_INCLUDE_RL=1`。
- 如需包含 Python 3.12 以上的 `yc-bench`，设置 `HERMES_INCLUDE_YC_BENCH=1` 并使用兼容 Python。
- macOS 构建入口改为 `packaging/common/hermes_app_entry.py`，便于 Windows/Linux 复用同一套打包启动环境。
- 需要重新执行脚本重打，才能把当前 macOS 产物从“核心运行时包”升级为“全功能运行时包”。

## Windows x64 中文包

新增脚本：

- `packaging/windows/build_windows.ps1`

Windows 构建方式：

```powershell
powershell -ExecutionPolicy Bypass -File .\packaging\windows\build_windows.ps1
```

默认行为：

- 使用或创建 `venv\Scripts\python.exe`。
- 安装 `.[all]` 与 `pyinstaller`。
- 若缺少 `hermes_cli\web_dist\index.html`，执行 `web\npm run build`。
- 通过 Windows 原生 PyInstaller `onedir` 生成 `HermesAgent.exe`。
- 生成 zip：`dist-windows-cn\Hermes-Agent-0.9.0-Windows-x64-zh.zip`。
- 生成目录包含：`HermesAgent\`、`启动 Hermes Agent 中文版.bat`、`Hermes CLI.bat`、`README.zh-CN.txt`。

可选扩展：

```powershell
powershell -ExecutionPolicy Bypass -File .\packaging\windows\build_windows.ps1 -IncludeRl
powershell -ExecutionPolicy Bypass -File .\packaging\windows\build_windows.ps1 -IncludeYcBench
```

验证门槛：

- `dist-windows-cn\HermesAgent\HermesAgent.exe version` 可运行。
- `启动 Hermes Agent 中文版.bat` 可启动 Dashboard。
- Dashboard 首页 HTML 包含 `lang="zh-CN"`。
- `Hermes CLI.bat --help` 或 CLI 启动路径可运行。

限制：

- macOS 不能可靠交叉编译 Windows `.exe`，实际 Windows 包必须在 Windows 机器、Windows VM 或 Windows CI runner 上执行脚本。
- 未签名 `.exe` 可能触发 Defender/SmartScreen；正式分发前建议补代码签名。

## Linux 后续策略

- 在目标发行版或兼容容器中用 Python 3.11 + PyInstaller `onedir` 构建 Linux x86_64/aarch64 包。
- 默认安装 `.[all]`，Linux 上仓库定义的 `matrix` extra 会随 `.[all]` 纳入。
- 产出 `HermesAgent/` 目录、`hermes-agent.desktop`、`hermes-cli.sh`、`README.zh-CN.txt`。
- Desktop 文件默认启动 `dashboard`；CLI 脚本启动 `chat`。
- 同样内置 `web_dist`、`skills`、`optional-skills`，并设置 `HERMES_SKIP_WEB_BUILD=1`。
- Linux 版本需额外 smoke test `glibc` 兼容性，避免在过新的系统构建后无法在较老发行版运行。

## 当前已知限制

- macOS 包未签名、未 notarize；分发到其他机器可能触发 Gatekeeper，需要右键打开或清理 quarantine 属性。
- Windows 包需要在 Windows 环境实际构建，当前 macOS 环境只能准备脚本和验证脚本结构。
- 前端生产构建通过；`npm run lint` 当前受仓库既有 React 19 lint 规则影响失败，失败项主要是同步 `setState` 规则和少量已有未使用参数，不影响打包 smoke test。
- 全功能不等于内置用户密钥或第三方账号授权；外部集成功能随包可用，但仍需用户在本机配置凭据。
