[CmdletBinding()]
param(
    [string]$Python = "",
    [string[]]$Extras = @("all"),
    [switch]$IncludeRl,
    [switch]$IncludeYcBench,
    [switch]$SkipInstall,
    [switch]$SkipWebBuild
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Root

$EffectiveExtras = New-Object System.Collections.Generic.List[string]
foreach ($extra in $Extras) {
    if (-not [string]::IsNullOrWhiteSpace($extra) -and -not $EffectiveExtras.Contains($extra)) {
        [void]$EffectiveExtras.Add($extra)
    }
}
if ($IncludeRl -and -not $EffectiveExtras.Contains("rl")) {
    [void]$EffectiveExtras.Add("rl")
}
if ($IncludeYcBench -and -not $EffectiveExtras.Contains("yc-bench")) {
    [void]$EffectiveExtras.Add("yc-bench")
}
$ExtraSpec = ($EffectiveExtras.ToArray() | Sort-Object -Unique) -join ","
if ([string]::IsNullOrWhiteSpace($ExtraSpec)) {
    throw "Extras 不能为空；全功能 Windows 包默认使用 -Extras all。"
}
$SupplementalPackages = New-Object System.Collections.Generic.List[string]
foreach ($package in @("websocket-client", "flask")) {
    [void]$SupplementalPackages.Add($package)
}
if ($EffectiveExtras.Contains("rl")) {
    foreach ($package in @("orjson", "scipy")) {
        [void]$SupplementalPackages.Add($package)
    }
}

if ([string]::IsNullOrWhiteSpace($Python)) {
    $Python = Join-Path $Root "venv\Scripts\python.exe"
    if (-not (Test-Path $Python)) {
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            throw "未找到 uv。请先安装 uv，或用 -Python 指向已有 Python 3.11 虚拟环境。"
        }
        & uv venv (Join-Path $Root "venv") --python 3.11
    }
}
if (-not (Test-Path $Python)) {
    throw "未找到 Python：$Python"
}

if (-not $SkipInstall) {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw "未找到 uv，无法安装全功能依赖。"
    }
    & uv pip install --python $Python -e ".[${ExtraSpec}]" pyinstaller @($SupplementalPackages.ToArray())
}

$WebIndex = Join-Path $Root "hermes_cli\web_dist\index.html"
if ((-not $SkipWebBuild) -and -not (Test-Path $WebIndex)) {
    Push-Location (Join-Path $Root "web")
    try {
        & npm run build
    }
    finally {
        Pop-Location
    }
}
if (-not (Test-Path $WebIndex)) {
    throw "未找到 hermes_cli\web_dist\index.html，Windows 包需要预构建 Web UI。"
}

$Version = (& $Python -c "from hermes_cli import __version__; print(__version__)").Trim()
$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$BinName = "HermesAgent"
$OutDir = Join-Path $Root "dist-windows-cn"
$AgentDir = Join-Path $OutDir $BinName
$ZipName = "Hermes-Agent-$Version-Windows-$Arch-zh.zip"
$ZipPath = Join-Path $OutDir $ZipName

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $Root "build")
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $Root "dist\$BinName")
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $OutDir

function Test-PythonModule {
    param([string]$Name)
    & $Python -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('$Name') else 1)" *> $null
    return $LASTEXITCODE -eq 0
}

$PyiArgs = @(
    "--clean",
    "--noconfirm",
    "--onedir",
    "--name", $BinName,
    "--paths", $Root,
    "--collect-submodules", "hermes_cli",
    "--collect-submodules", "agent",
    "--collect-submodules", "tools",
    "--collect-submodules", "gateway",
    "--collect-submodules", "cron",
    "--collect-submodules", "acp_adapter",
    "--collect-submodules", "plugins",
    "--collect-data", "hermes_cli",
    "--add-data", "$Root\hermes_cli\web_dist;hermes_cli\web_dist",
    "--add-data", "$Root\skills;skills",
    "--add-data", "$Root\optional-skills;optional-skills",
    "--add-data", "$Root\cli-config.yaml.example;.",
    "--add-data", "$Root\.env.example;.",
    "$Root\packaging\common\hermes_app_entry.py"
)

$OptionalHiddenImports = @(
    "modal",
    "daytona",
    "telegram",
    "discord",
    "slack_bolt",
    "slack_sdk",
    "mautrix",
    "markdown",
    "aiosqlite",
    "asyncpg",
    "elevenlabs",
    "faster_whisper",
    "sounddevice",
    "numpy",
    "winpty",
    "honcho",
    "mcp",
    "agent_client_protocol",
    "mistralai",
    "dingtalk_stream",
    "lark_oapi",
    "fastapi",
    "uvicorn",
    "wandb",
    "atroposlib",
    "tinker",
    "orjson",
    "scipy",
    "websocket",
    "flask"
)
foreach ($module in $OptionalHiddenImports) {
    if (Test-PythonModule $module) {
        $PyiArgs += @("--hidden-import", $module)
        if ($module -notin @("numpy", "sounddevice", "winpty", "orjson", "scipy")) {
            $PyiArgs += @("--collect-submodules", $module)
        }
    }
}

& $Python -m PyInstaller @PyiArgs

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $Root "dist\$BinName") -Destination $OutDir

$DashboardBat = Join-Path $OutDir "启动 Hermes Agent 中文版.bat"
$CliBat = Join-Path $OutDir "Hermes CLI.bat"
$Readme = Join-Path $OutDir "README.zh-CN.txt"

@"
@echo off
setlocal
set "BASE=%~dp0"
set "RESOURCE_ROOT=%BASE%HermesAgent\_internal"
set "HERMES_LANG=zh_CN"
set "LANG=zh_CN.UTF-8"
set "HERMES_SKIP_WEB_BUILD=1"
set "HERMES_BUNDLED_SKILLS=%RESOURCE_ROOT%\skills"
set "HERMES_OPTIONAL_SKILLS=%RESOURCE_ROOT%\optional-skills"
set "HERMES_PACKAGED=windows"
"%BASE%HermesAgent\HermesAgent.exe" dashboard %*
"@ | Set-Content -Path $DashboardBat -Encoding ascii

@"
@echo off
setlocal
set "BASE=%~dp0"
set "RESOURCE_ROOT=%BASE%HermesAgent\_internal"
set "HERMES_LANG=zh_CN"
set "LANG=zh_CN.UTF-8"
set "HERMES_SKIP_WEB_BUILD=1"
set "HERMES_BUNDLED_SKILLS=%RESOURCE_ROOT%\skills"
set "HERMES_OPTIONAL_SKILLS=%RESOURCE_ROOT%\optional-skills"
set "HERMES_PACKAGED=windows"
"%BASE%HermesAgent\HermesAgent.exe" chat %*
"@ | Set-Content -Path $CliBat -Encoding ascii

@"
Hermes Agent Windows 中文版 $Version ($Arch)

使用方式：
1. 双击 “启动 Hermes Agent 中文版.bat” 启动中文 Web 管理面板。
2. 双击 “Hermes CLI.bat” 在终端中启动 CLI 聊天模式。
3. 首次运行会使用默认用户目录下的 .hermes 作为配置和会话目录。

说明：
- 本包按全功能运行时口径构建，默认安装 pyproject.toml 中的 .[$ExtraSpec] 依赖。
- 本包内置已构建的 Web UI，不需要在目标机器安装 Node.js/npm。
- 本包内置 skills/optional-skills 目录，并通过 HERMES_BUNDLED_SKILLS/HERMES_OPTIONAL_SKILLS 指向资源目录。
- 外部服务功能仍需要用户自行配置对应 API key/OAuth/机器人 token。
- Windows 安全中心或 SmartScreen 可能拦截未签名 exe；正式分发前建议补代码签名。
"@ | Set-Content -Path $Readme -Encoding utf8

if (Test-Path $ZipPath) {
    Remove-Item -Force $ZipPath
}
Compress-Archive -Path @($AgentDir, $DashboardBat, $CliBat, $Readme) -DestinationPath $ZipPath -Force

Write-Host "已产出：$ZipPath"
Write-Host "应用目录：$AgentDir"
