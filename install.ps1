# Weekly Flow - Claude Code Skill Windows 安装脚本
# PowerShell 脚本

param(
    [switch]$Force,
    [switch]$Help,
    [string]$Repo = "Adonis0123/weekly-flow",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
    exit 1
}

# 显示帮助
function Show-Help {
    Write-Host @"

Weekly Flow - Claude Code Skill 安装器 (Windows)

用法:
    .\install.ps1 [选项]

选项:
    -Force    强制覆盖已存在的安装
    -Help     显示帮助信息
    -Repo     指定 GitHub 仓库 (默认: Adonis0123/weekly-flow)
    -Branch   指定分支 (默认: main)

示例:
    .\install.ps1           # 正常安装
    .\install.ps1 -Force    # 强制覆盖安装
    # 一键安装（如需强制覆盖，可先设置环境变量）
    # $env:WEEKLY_FLOW_FORCE=1; irm https://raw.githubusercontent.com/Adonis0123/weekly-flow/main/install.ps1 | iex

"@
    exit 0
}

# 检查依赖
function Test-Dependencies {
    Write-Info "检查依赖..."

    try {
        $null = git --version
    } catch {
        Write-Err "Git 未安装，请先安装 Git: https://git-scm.com/download/win"
    }

    Write-Info "依赖检查通过"
}

# 获取脚本所在目录
function Get-ScriptDirectory {
    return Split-Path -Parent $MyInvocation.ScriptName
}

function Get-PayloadDirectory {
    param(
        [string]$Repo,
        [string]$Branch
    )

    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    if ($scriptDir -and (Test-Path (Join-Path $scriptDir "SKILL.md"))) {
        return @{
            PayloadDir = $scriptDir
            TempDir = $null
        }
    }

    Write-Info "未检测到本地发布包文件，准备从 GitHub 下载源码 ($Repo@$Branch)..."

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("weekly-flow-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $zipPath = Join-Path $tempDir "weekly-flow.zip"
    $zipUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing | Out-Null
    } catch {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        Write-Err "下载失败：$zipUrl"
    }

    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    $extracted = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "weekly-flow-*" } | Select-Object -First 1
    if (-not $extracted) {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        Write-Err "解压失败：未找到源码目录"
    }

    if (-not (Test-Path (Join-Path $extracted.FullName "SKILL.md"))) {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        Write-Err "下载内容异常：未找到 SKILL.md"
    }

    return @{
        PayloadDir = $extracted.FullName
        TempDir = $tempDir
    }
}

# 安装 Skill
function Install-Skill {
    $payload = Get-PayloadDirectory -Repo $Repo -Branch $Branch
    $ScriptDir = $payload.PayloadDir
    $TempDir = $payload.TempDir

    $SkillDir = Join-Path $env:USERPROFILE ".claude\skills\weekly-report"

    Write-Info "安装 Weekly Flow Skill..."

    # 创建目标目录
    $ClaudeSkillsDir = Join-Path $env:USERPROFILE ".claude\skills"
    if (-not (Test-Path $ClaudeSkillsDir)) {
        New-Item -ItemType Directory -Path $ClaudeSkillsDir -Force | Out-Null
    }

    # 检查是否已存在
    if (Test-Path $SkillDir) {
        if ($Force) {
            Write-Warn "强制覆盖已存在的 Skill: $SkillDir"
            Remove-Item -Recurse -Force $SkillDir
        } else {
            Write-Warn "Skill 已存在: $SkillDir"
            $response = Read-Host "是否覆盖? (y/N)"
            if ($response -notmatch '^[Yy]') {
                Write-Info "取消安装"
                exit 0
            }
            Remove-Item -Recurse -Force $SkillDir
        }
    }

    try {
        # 复制文件
        New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null

        Copy-Item -Path (Join-Path $ScriptDir "SKILL.md") -Destination $SkillDir -Force
        Copy-Item -Path (Join-Path $ScriptDir "references") -Destination $SkillDir -Recurse -Force
        Copy-Item -Path (Join-Path $ScriptDir "src") -Destination $SkillDir -Recurse -Force

        if (Test-Path (Join-Path $ScriptDir "scripts")) {
            Copy-Item -Path (Join-Path $ScriptDir "scripts") -Destination $SkillDir -Recurse -Force
        }
    } finally {
        if ($TempDir -and (Test-Path $TempDir)) {
            Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
        }
    }

    Write-Info "Skill 安装完成: $SkillDir"
}

# 设置存储目录
function Set-Storage {
    $StorageDir = Join-Path $env:USERPROFILE ".weekly-reports"

    Write-Info "设置周报存储目录..."

    if (-not (Test-Path $StorageDir)) {
        New-Item -ItemType Directory -Path $StorageDir -Force | Out-Null
        Write-Info "创建存储目录: $StorageDir"
    }

    # 创建默认配置文件
    $ConfigFile = Join-Path $StorageDir "config.json"
    if (-not (Test-Path $ConfigFile)) {
        $config = @{
            repos = @()
            default_author = "auto"
            output_format = "markdown"
        } | ConvertTo-Json -Depth 3

        $config | Out-File -FilePath $ConfigFile -Encoding UTF8
        Write-Info "创建默认配置: $ConfigFile"
    }
}

# 显示使用说明
function Show-Usage {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Weekly Flow 安装完成!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "使用方式:"
    Write-Host "  在任意 Git 项目目录中执行: /weekly-report"
    Write-Host ""
    Write-Host "配置文件:"
    Write-Host "  $env:USERPROFILE\.weekly-reports\config.json"
    Write-Host ""
    Write-Host "周报存储:"
    Write-Host "  $env:USERPROFILE\.weekly-reports\{year}\week-{week}.md"
    Write-Host ""
}

# 主函数
function Main {
    if ($Help) {
        Show-Help
    }

    if (-not $Force -and $env:WEEKLY_FLOW_FORCE -match '^(1|true|yes|y)$') {
        $Force = $true
    }
    if ($env:WEEKLY_FLOW_REPO) {
        $Repo = $env:WEEKLY_FLOW_REPO
    }
    if ($env:WEEKLY_FLOW_BRANCH) {
        $Branch = $env:WEEKLY_FLOW_BRANCH
    }

    Write-Host "=========================================="
    Write-Host "  Weekly Flow - Claude Code Skill 安装器"
    Write-Host "=========================================="
    Write-Host ""

    Test-Dependencies
    Install-Skill
    Set-Storage
    Show-Usage

    Write-Info "安装成功!"
}

# 运行主函数
Main
