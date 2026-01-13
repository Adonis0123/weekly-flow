#!/bin/bash
# Weekly Flow - Claude Code Skill 安装脚本
# 支持 macOS 和 Linux

set -e

# 版本号
VERSION="1.0.4"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认选项
REPO="Adonis0123/weekly-flow"
BRANCH="main"
TMP_DIR=""
PAYLOAD_DIR=""

# 打印带颜色的消息
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 显示帮助信息
show_help() {
    echo ""
    echo "Weekly Flow - Claude Code Skill 安装器 v${VERSION}"
    echo ""
    echo "用法:"
    echo "  ./install.sh [选项]"
    echo ""
    echo "选项:"
    echo "      --repo     指定 GitHub 仓库 (默认: Adonis0123/weekly-flow)"
    echo "      --branch   指定分支 (默认: main)"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --version  显示版本信息"
    echo ""
    echo "示例:"
    echo "  ./install.sh    # 全量覆盖安装"
    echo "  curl -fsSL https://raw.githubusercontent.com/Adonis0123/weekly-flow/main/install.sh | bash"
    echo ""
    exit 0
}

# 显示版本
show_version() {
    echo "Weekly Flow v${VERSION}"
    exit 0
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            -v|--version)
                show_version
                ;;
            *)
                error "未知参数: $1，使用 --help 查看帮助"
                ;;
        esac
    done
}

# 检测操作系统
detect_os() {
    OS="$(uname -s)"
    case "$OS" in
        Linux*)     OS_TYPE="linux";;
        Darwin*)    OS_TYPE="macos";;
        CYGWIN*|MINGW*|MSYS*)    OS_TYPE="windows";;
        *)          OS_TYPE="unknown";;
    esac
    info "检测到操作系统: $OS_TYPE"
}

# 检查依赖
check_dependencies() {
    info "检查依赖..."

    if ! command -v git &> /dev/null; then
        error "Git 未安装，请先安装 Git"
    fi

    info "依赖检查通过"
}

cleanup_tmp() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR" 2>/dev/null || true
    fi
}

download_payload() {
    if command -v curl &> /dev/null; then
        curl -fsSL -L "$1" -o "$2"
    elif command -v wget &> /dev/null; then
        wget -qO "$2" "$1"
    else
        error "缺少下载工具：请安装 curl 或 wget"
    fi
}

prepare_payload_dir() {
    local script_dir
    script_dir="$(get_script_dir)"

    if [ -f "$script_dir/SKILL.md" ] && [ -d "$script_dir/src" ] && [ -d "$script_dir/references" ]; then
        PAYLOAD_DIR="$script_dir"
        return 0
    fi

    info "未检测到本地发布包文件，准备从 GitHub 下载源码 (${REPO}@${BRANCH})..."

    if ! command -v tar &> /dev/null; then
        error "缺少 tar 命令，无法解压下载包"
    fi

    TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t weekly-flow)"
    trap cleanup_tmp EXIT

    local archive_url="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
    local archive_path="${TMP_DIR}/weekly-flow.tar.gz"

    download_payload "$archive_url" "$archive_path"
    tar -xzf "$archive_path" -C "$TMP_DIR"

    local extracted_dir
    extracted_dir="$(find "$TMP_DIR" -maxdepth 1 -type d -name "weekly-flow-*" | head -1)"
    if [ -z "$extracted_dir" ] || [ ! -d "$extracted_dir" ]; then
        error "下载解压失败：未找到源码目录"
    fi

    if [ ! -f "$extracted_dir/SKILL.md" ]; then
        error "下载内容异常：未找到 SKILL.md"
    fi

    PAYLOAD_DIR="$extracted_dir"
}

# 获取脚本所在目录
get_script_dir() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    echo "$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}

# 安装到 Claude Code skills 目录
install_skill() {
    prepare_payload_dir
    local SCRIPT_DIR="$PAYLOAD_DIR"
    local SKILL_DIR="$HOME/.claude/skills/weekly-report"

    info "安装 Weekly Flow Skill..."

    # 创建目标目录
    mkdir -p "$HOME/.claude/skills"

    # 如果已存在，直接覆盖
    if [ -d "$SKILL_DIR" ]; then
        info "覆盖已存在的 Skill: $SKILL_DIR"
        rm -rf "$SKILL_DIR"
    fi

    # 复制文件
    mkdir -p "$SKILL_DIR"
    cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/"
    cp -r "$SCRIPT_DIR/references" "$SKILL_DIR/"
    cp -r "$SCRIPT_DIR/src" "$SKILL_DIR/"
    cp -r "$SCRIPT_DIR/scripts" "$SKILL_DIR/" 2>/dev/null || true

    info "Skill 安装完成: $SKILL_DIR"
}

# 创建周报存储目录
setup_storage() {
    local STORAGE_DIR="$HOME/.weekly-reports"

    info "设置周报存储目录..."

    if [ ! -d "$STORAGE_DIR" ]; then
        mkdir -p "$STORAGE_DIR"
        info "创建存储目录: $STORAGE_DIR"
    fi

    # 创建默认配置文件
    local CONFIG_FILE="$STORAGE_DIR/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
  "repos": [],
  "default_author": "auto",
  "output_format": "markdown"
}
EOF
        info "创建默认配置: $CONFIG_FILE"
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo "=========================================="
    echo "  Weekly Flow 安装完成!"
    echo "=========================================="
    echo ""
    echo "使用方式:"
    echo "  在任意 Git 项目目录中执行: /weekly-report"
    echo ""
    echo "配置文件:"
    echo "  ~/.weekly-reports/config.json"
    echo ""
    echo "周报存储:"
    echo "  ~/.weekly-reports/{year}/week-{week}.md"
    echo ""
}

# 主函数
main() {
    parse_args "$@"

    echo "=========================================="
    echo "  Weekly Flow - Claude Code Skill 安装器 v${VERSION}"
    echo "=========================================="
    echo ""

    detect_os
    check_dependencies
    install_skill
    setup_storage
    show_usage

    info "安装成功!"
}

# 运行主函数
main "$@"
