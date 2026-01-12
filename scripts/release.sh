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

info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# 检查依赖
check_git_dependencies() {
    if ! command -v git &> /dev/null; then
        error "Git 未安装"
    fi
}

check_gh_dependencies() {
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) 未安装，请先安装: https://cli.github.com/"
    fi

    # 检查 gh 是否已登录
    if ! gh auth status &> /dev/null; then
        error "GitHub CLI 未登录，请先运行: gh auth login"
    fi
}

gh_is_available() {
    command -v gh &> /dev/null && gh auth status &> /dev/null
}

get_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
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

collect_release_assets() {
    local dist_dir="dist"
    local -a assets=()

    if [ ! -d "$dist_dir" ]; then
        error "未找到 dist/ 目录，请先运行构建"
    fi

    shopt -s nullglob
    assets+=("$dist_dir"/*.tar.gz)
    assets+=("$dist_dir"/*.zip)
    shopt -u nullglob

    if [ -s "$dist_dir/checksums.txt" ]; then
        assets+=("$dist_dir/checksums.txt")
    fi

    if [ ${#assets[@]} -eq 0 ]; then
        error "dist/ 下未找到可上传的构建产物（.tar.gz/.zip）"
    fi

    printf '%s\0' "${assets[@]}"
}

# 显示版本选择菜单
show_version_menu() {
    local current=$1

    echo "" >&2
    echo -e "${CYAN}========================================${NC}" >&2
    echo -e "${CYAN}  Weekly Flow 发布工具${NC}" >&2
    echo -e "${CYAN}========================================${NC}" >&2
    echo "" >&2
    echo -e "当前版本: ${YELLOW}v${current}${NC}" >&2
    echo "" >&2

    # 显示自上次 tag 以来的更改
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [ -n "$last_tag" ]; then
        echo -e "${BLUE}自 ${last_tag} 以来的提交:${NC}" >&2
        git --no-pager log "${last_tag}..HEAD" --oneline --no-decorate 2>/dev/null | head -10 >&2
        local commit_count=$(git rev-list "${last_tag}..HEAD" --count 2>/dev/null || echo "0")
        if [ "$commit_count" -gt 10 ]; then
            echo "  ... 还有 $((commit_count - 10)) 个提交" >&2
        fi
    else
        echo -e "${BLUE}最近的提交:${NC}" >&2
        git --no-pager log --oneline --no-decorate -10 2>/dev/null >&2
    fi

    # 显示未提交的更改
    if [[ -n $(git status --porcelain) ]]; then
        echo "" >&2
        echo -e "${YELLOW}未提交的更改:${NC}" >&2
        git status --short >&2
    fi

    echo "" >&2
    echo "请选择版本更新类型:" >&2
    echo "" >&2
}

choose_menu_index() {
    local prompt=$1
    shift
    local -a options=("$@")

    local option_count=${#options[@]}
    if [ "$option_count" -le 0 ]; then
        echo "-1"
        return 0
    fi

    if [ ! -t 0 ] || [ ! -t 1 ]; then
        echo "$prompt" >&2
        local i
        for i in "${!options[@]}"; do
            printf "  %s\n" "${options[$i]}" >&2
        done
        local choice=""
        read -r -p "选择 [1-${option_count}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$option_count" ]; then
            echo $((choice - 1))
        else
            echo "-1"
        fi
        return 0
    fi

    local selected=0
    local esc=$'\033'

    _wf_restore_cursor() {
        tput cnorm 2>/dev/null || true
        printf "\033[0m" >&2
    }

    _wf_restore_cursor
    tput civis 2>/dev/null || true
    trap '_wf_restore_cursor; return 130' INT TERM

    echo "$prompt" >&2

    _wf_render_menu() {
        local i
        for i in "${!options[@]}"; do
            printf "\033[2K\r" >&2
            if [ "$i" -eq "$selected" ]; then
                printf "\033[7m> %s\033[0m\n" "${options[$i]}" >&2
            else
                printf "  %s\n" "${options[$i]}" >&2
            fi
        done
    }

    _wf_render_menu

    while true; do
        local key=""
        IFS= read -rsn1 key

        if [[ "$key" == "$esc" ]]; then
            local rest=""
            IFS= read -rsn2 -t 0.01 rest || rest=""
            case "$rest" in
                "[A") selected=$(( (selected - 1 + option_count) % option_count )) ;;
                "[B") selected=$(( (selected + 1) % option_count )) ;;
            esac
        elif [[ "$key" == "" || "$key" == $'\n' || "$key" == $'\r' ]]; then
            _wf_restore_cursor
            trap - INT TERM
            printf "\n" >&2
            echo "$selected"
            return 0
        elif [[ "$key" =~ ^[1-9]$ ]]; then
            local idx=$((key - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "$option_count" ]; then
                _wf_restore_cursor
                trap - INT TERM
                printf "\n" >&2
                echo "$idx"
                return 0
            fi
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            _wf_restore_cursor
            trap - INT TERM
            printf "\n" >&2
            echo "-1"
            return 0
        fi

        printf "\033[%dA" "$option_count" >&2
        _wf_render_menu
    done
}

# 获取用户选择
get_version_choice() {
    local current=$1
    local new_version=""

    while true; do
        show_version_menu "$current"

        local patch_version
        local minor_version
        local major_version
        patch_version="$(calculate_new_version "$current" patch)"
        minor_version="$(calculate_new_version "$current" minor)"
        major_version="$(calculate_new_version "$current" major)"

        local -a options=(
            "1) patch  - 补丁版本 (bug 修复)        -> v${patch_version}"
            "2) minor  - 次要版本 (新功能，向后兼容) -> v${minor_version}"
            "3) major  - 主要版本 (重大变更)        -> v${major_version}"
            "4) custom - 自定义版本号"
            "5) cancel - 取消发布"
        )

        local idx
        idx="$(choose_menu_index "使用 ↑/↓ 选择，回车确认（或直接按 1-5 / q）" "${options[@]}")"

        case $idx in
            0)
                new_version="$patch_version"
                break
                ;;
            1)
                new_version="$minor_version"
                break
                ;;
            2)
                new_version="$major_version"
                break
                ;;
            3)
                read -r -p "请输入自定义版本号 (如 1.2.3): " custom_version
                if [[ $custom_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    new_version=$custom_version
                    break
                else
                    warn "版本号格式无效，请使用 x.y.z 格式"
                fi
                ;;
            4)
                info "取消发布"
                exit 0
                ;;
            -1)
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

# 构建发布包
build_release() {
    info "构建发布包..."
    chmod +x scripts/build-release.sh
    ./scripts/build-release.sh
}

commit_tag_and_push() {
    local version=$1

    info "提交版本更新并创建 tag..."

    git add pyproject.toml install.sh
    if ! git commit -m "chore: bump version to ${version}"; then
        echo ""
        warn "提交失败（可能未配置 git user.name/user.email，或存在其他问题）"
        git status --short || true
        error "请先修复 git 提交问题后重试"
    fi

    git tag -a "v${version}" -m "Release v${version}"

    local branch
    branch="$(get_current_branch)"
    if [ "$branch" = "HEAD" ]; then
        warn "当前处于 detached HEAD，将仅推送 tags"
        git push origin --tags
    else
        git push origin "$branch" --tags
    fi

    info "已推送: 分支 ${branch} + tag v${version}"
}

create_github_release() {
    local version=$1

    info "创建 GitHub Release v${version}..."

    local -a assets=()
    while IFS= read -r -d '' f; do
        assets+=("$f")
    done < <(collect_release_assets)

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
        "${assets[@]}"

    info "Release 创建成功!"
    echo ""
    echo -e "${GREEN}查看 Release:${NC} $(gh release view "v${version}" --json url -q .url)"
}

# 主函数
main() {
    echo ""

    check_git_dependencies

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

    # 提交 + tag + push（不依赖 gh）
    commit_tag_and_push "$new_version"

    # GitHub Release（可选）
    echo ""
    local create_with_gh="n"
    if gh_is_available; then
        read -p "使用 gh 创建 GitHub Release 并上传 dist/? (Y/n): " create_with_gh
        create_with_gh=${create_with_gh:-y}
    else
        warn "gh 不可用或未登录，将跳过自动创建 GitHub Release（可先安装并运行 gh auth login）"
        echo "手动创建 Release（可选）:"
        echo "  1) 在 GitHub 创建 Release: v${new_version}"
        echo "  2) 上传 dist/ 下的构建产物"
        create_with_gh="n"
    fi

    if [[ $create_with_gh =~ ^[Yy]$ ]]; then
        check_gh_dependencies
        create_github_release "$new_version"
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  发布完成! v${new_version}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
