#!/bin/bash
# Weekly Flow - Claude Code Skill 安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# 检查依赖
check_dependencies() {
    info "检查依赖..."

    if ! command -v git &> /dev/null; then
        error "Git 未安装，请先安装 Git"
    fi

    info "依赖检查通过"
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
    local SCRIPT_DIR=$(get_script_dir)
    local SKILL_DIR="$HOME/.claude/skills/weekly-report"

    info "安装 Weekly Flow Skill..."

    # 创建目标目录
    mkdir -p "$HOME/.claude/skills"

    # 如果已存在，询问是否覆盖
    if [ -d "$SKILL_DIR" ]; then
        warn "Skill 已存在: $SKILL_DIR"
        read -p "是否覆盖? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "取消安装"
            exit 0
        fi
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
    echo "=========================================="
    echo "  Weekly Flow - Claude Code Skill 安装器"
    echo "=========================================="
    echo ""

    check_dependencies
    install_skill
    setup_storage
    show_usage

    info "安装成功!"
}

# 运行主函数
main "$@"
