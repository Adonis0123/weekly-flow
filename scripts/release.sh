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

has_release_workflow() {
    [ -f ".github/workflows/release.yml" ] || [ -f ".github/workflows/release.yaml" ]
}

get_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
}

ensure_git_lock_cleared() {
    local lock_path
    lock_path="$(git rev-parse --git-path index.lock 2>/dev/null || true)"
    if [ -n "$lock_path" ] && [ -f "$lock_path" ]; then
        warn "检测到 Git 锁文件: ${lock_path}"
        echo "这通常表示：另一个 git 进程仍在运行，或上次 git 操作异常中断。" >&2
        echo "请先确认没有 git/editor 进程占用该仓库后再删除锁文件。" >&2
        echo "" >&2
        ls -la "$lock_path" >&2 || true
        echo "" >&2
        local ans=""
        read -r -p "是否尝试删除该锁文件并继续? (y/N): " ans
        ans=${ans:-n}
        if [[ $ans =~ ^[Yy]$ ]]; then
            rm -f "$lock_path"
        else
            error "已取消：请处理锁文件后重试（例如：rm -f \"$lock_path\"）"
        fi
    fi
}

ensure_clean_worktree_or_confirm() {
    if [[ -n $(git status --porcelain) ]]; then
        warn "检测到未提交的更改：发布 tag 默认不会包含这些改动"
        git status --short >&2 || true
        echo "" >&2
        local cont=""
        read -r -p "仍要继续发布? (y/N): " cont
        cont=${cont:-n}
        if [[ ! $cont =~ ^[Yy]$ ]]; then
            info "已取消，请先提交或 stash 后再发布"
            exit 0
        fi
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

# 检查 gum 是否可用
gum_is_available() {
    command -v gum &> /dev/null
}

# 检查是否有可用的 TTY（通过 /dev/tty 检测，避免子 shell 问题）
tty_is_available() {
    [ -e /dev/tty ] && [ -r /dev/tty ] && [ -w /dev/tty ]
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

    # 方案 1: 使用 gum（推荐，支持方向键导航）
    if gum_is_available && tty_is_available; then
        echo "$prompt" >&2
        local selected=""
        selected=$(gum choose --cursor="> " --cursor.foreground="212" "${options[@]}" < /dev/tty 2>/dev/tty) || {
            echo "-1"
            return 0
        }

        # 查找选中项的索引
        local i
        for i in "${!options[@]}"; do
            if [ "${options[$i]}" = "$selected" ]; then
                echo "$i"
                return 0
            fi
        done
        echo "-1"
        return 0
    fi

    # 方案 2: 回退到简单数字选择
    echo "$prompt" >&2
    local i
    for i in "${!options[@]}"; do
        printf "  %s\n" "${options[$i]}" >&2
    done
    local choice=""
    if tty_is_available; then
        read -r -p "选择 [1-${option_count}]: " choice < /dev/tty
    else
        read -r -p "选择 [1-${option_count}]: " choice
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$option_count" ]; then
        echo $((choice - 1))
    else
        echo "-1"
    fi
    return 0
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
        idx="$(choose_menu_index "请选择（↑/↓ 选择，回车确认）：" "${options[@]}")"

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
                # 返回空字符串表示取消
                echo ""
                return 0
                ;;
            -1)
                # 返回空字符串表示取消
                echo ""
                return 0
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

    ensure_git_lock_cleared

    git add pyproject.toml install.sh
    local commit_output=""
    if ! commit_output="$(git commit -m "chore: bump version to ${version}" 2>&1)"; then
        echo ""
        echo "$commit_output" >&2
        echo "" >&2

        if echo "$commit_output" | grep -q "index.lock"; then
            error "提交失败：Git 锁文件未释放，请处理后重试"
        fi
        if echo "$commit_output" | grep -q "Please tell me who you are"; then
            error "提交失败：请先配置 git 身份（git config --global user.name/user.email）后重试"
        fi

        warn "提交失败（可能未配置 git user.name/user.email，或存在其他问题）"
        git status --short || true
        error "请先修复 git 提交问题后重试"
    fi

    echo "$commit_output" >&2

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

    # 检查是否取消了发布
    if [ -z "$new_version" ]; then
        info "取消发布"
        exit 0
    fi

    echo ""
    echo -e "即将发布: ${YELLOW}v${current_version}${NC} -> ${GREEN}v${new_version}${NC}"
    echo ""
    read -p "确认发布? (y/n): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        info "取消发布"
        exit 0
    fi

    ensure_clean_worktree_or_confirm

    # 更新版本号
    update_version "$new_version"

    # 构建发布包
    build_release

    # 提交 + tag + push（不依赖 gh）
    commit_tag_and_push "$new_version"

    # GitHub Release（根据是否有工作流决定）
    echo ""
    if has_release_workflow; then
        info "检测到 GitHub Actions Release 工作流"
        info "Release 将由 GitHub Actions 自动创建: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'OWNER/REPO')/actions"
    elif gh_is_available; then
        local create_with_gh=""
        read -r -p "使用 gh 创建 GitHub Release 并上传 dist/? (Y/n): " create_with_gh
        create_with_gh=${create_with_gh:-y}
        if [[ $create_with_gh =~ ^[Yy]$ ]]; then
            check_gh_dependencies
            create_github_release "$new_version"
        fi
    else
        warn "gh 不可用或未登录，将跳过自动创建 GitHub Release"
        echo "手动创建 Release（可选）:"
        echo "  1) 在 GitHub 创建 Release: v${new_version}"
        echo "  2) 上传 dist/ 下的构建产物"
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
