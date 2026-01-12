#!/bin/bash
# Weekly Flow - 一键发布脚本
# 支持语义化版本选择，自动创建 tag 和 GitHub Release

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# 检查依赖
check_dependencies() {
    if ! command -v git &> /dev/null; then
        error "Git 未安装"
    fi

    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) 未安装，请先安装: https://cli.github.com/"
    fi

    # 检查 gh 是否已登录
    if ! gh auth status &> /dev/null; then
        error "GitHub CLI 未登录，请先运行: gh auth login"
    fi
}

# 获取当前版本
get_current_version() {
    grep 'version = ' pyproject.toml | head -1 | cut -d'"' -f2
}

# 解析版本号
parse_version() {
    local version=$1
    IFS='.' read -r MAJOR MINOR PATCH <<< "$version"
}

# 计算新版本
calculate_new_version() {
    local current=$1
    local bump_type=$2

    parse_version "$current"

    case $bump_type in
        major)
            echo "$((MAJOR + 1)).0.0"
            ;;
        minor)
            echo "${MAJOR}.$((MINOR + 1)).0"
            ;;
        patch)
            echo "${MAJOR}.${MINOR}.$((PATCH + 1))"
            ;;
        *)
            echo "$current"
            ;;
    esac
}

# 更新版本号
update_version() {
    local new_version=$1

    # 更新 pyproject.toml
    sed -i.bak "s/^version = \".*\"/version = \"$new_version\"/" pyproject.toml
    rm -f pyproject.toml.bak

    # 更新 install.sh
    sed -i.bak "s/^VERSION=\".*\"/VERSION=\"$new_version\"/" install.sh
    rm -f install.sh.bak

    info "版本已更新为: $new_version"
}

# 显示版本选择菜单
show_version_menu() {
    local current=$1

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Weekly Flow 发布工具${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "当前版本: ${YELLOW}v${current}${NC}"
    echo ""
    echo "请选择版本更新类型:"
    echo ""
    echo -e "  ${GREEN}1)${NC} patch  - 补丁版本 (bug 修复)        -> v$(calculate_new_version "$current" patch)"
    echo -e "  ${GREEN}2)${NC} minor  - 次要版本 (新功能，向后兼容) -> v$(calculate_new_version "$current" minor)"
    echo -e "  ${GREEN}3)${NC} major  - 主要版本 (重大变更)        -> v$(calculate_new_version "$current" major)"
    echo -e "  ${GREEN}4)${NC} custom - 自定义版本号"
    echo -e "  ${GREEN}5)${NC} cancel - 取消发布"
    echo ""
}

# 获取用户选择
get_version_choice() {
    local current=$1
    local new_version=""

    while true; do
        show_version_menu "$current"
        read -p "请输入选项 [1-5]: " choice

        case $choice in
            1)
                new_version=$(calculate_new_version "$current" patch)
                break
                ;;
            2)
                new_version=$(calculate_new_version "$current" minor)
                break
                ;;
            3)
                new_version=$(calculate_new_version "$current" major)
                break
                ;;
            4)
                read -p "请输入自定义版本号 (如 1.2.3): " custom_version
                if [[ $custom_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    new_version=$custom_version
                    break
                else
                    warn "版本号格式无效，请使用 x.y.z 格式"
                fi
                ;;
            5)
                info "取消发布"
                exit 0
                ;;
            *)
                warn "无效选项，请重新选择"
                ;;
        esac
    done

    echo "$new_version"
}

# 检查工作区状态
check_workspace() {
    if [[ -n $(git status --porcelain) ]]; then
        warn "工作区有未提交的更改:"
        git status --short
        echo ""
        read -p "是否继续? 版本更新会被自动提交 (y/n): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 构建发布包
build_release() {
    info "构建发布包..."
    chmod +x scripts/build-release.sh
    ./scripts/build-release.sh
}

# 创建 Release
create_release() {
    local version=$1

    info "创建 GitHub Release v${version}..."

    # 提交版本更新
    git add pyproject.toml install.sh
    git commit -m "chore: bump version to ${version}" || true

    # 创建并推送 tag
    git tag -a "v${version}" -m "Release v${version}"
    git push origin main --tags

    # 创建 GitHub Release
    gh release create "v${version}" \
        --title "Weekly Flow v${version}" \
        --notes "## Weekly Flow v${version}

### 安装方式

**一键安装（推荐）**

macOS / Linux:
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/main/install.sh | bash
\`\`\`

Windows (PowerShell):
\`\`\`powershell
irm https://raw.githubusercontent.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/main/install.ps1 | iex
\`\`\`

**下载安装包**

下载下方的 \`.tar.gz\` (macOS/Linux) 或 \`.zip\` (Windows) 文件，解压后运行安装脚本。
" \
        dist/*.tar.gz dist/*.zip dist/checksums.txt

    info "Release 创建成功!"
    echo ""
    echo -e "${GREEN}查看 Release:${NC} $(gh release view "v${version}" --json url -q .url)"
}

# 主函数
main() {
    echo ""

    check_dependencies
    check_workspace

    local current_version=$(get_current_version)
    local new_version=$(get_version_choice "$current_version")

    echo ""
    echo -e "即将发布: ${YELLOW}v${current_version}${NC} -> ${GREEN}v${new_version}${NC}"
    echo ""
    read -p "确认发布? (y/n): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        info "取消发布"
        exit 0
    fi

    # 更新版本号
    update_version "$new_version"

    # 构建发布包
    build_release

    # 创建 Release
    create_release "$new_version"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  发布完成! v${new_version}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

main "$@"
