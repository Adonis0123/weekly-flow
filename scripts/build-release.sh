#!/bin/bash
# Weekly Flow - 打包发布脚本
# 创建可分发的安装包

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"

# 切换到项目目录
cd "$PROJECT_DIR"

# 版本号（从 pyproject.toml 读取）
VERSION=$(grep 'version = ' pyproject.toml | head -1 | cut -d'"' -f2)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 清理旧的构建
clean() {
    info "清理旧的构建..."
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"
}

# 创建通用发布包
build_release() {
    info "创建发布包 v${VERSION}..."

    local RELEASE_NAME="weekly-flow-v${VERSION}"
    local RELEASE_DIR="$DIST_DIR/$RELEASE_NAME"

    mkdir -p "$RELEASE_DIR"

    # 复制核心文件
    cp "$PROJECT_DIR/SKILL.md" "$RELEASE_DIR/"
    cp "$PROJECT_DIR/README.md" "$RELEASE_DIR/"
    cp "$PROJECT_DIR/LICENSE" "$RELEASE_DIR/" 2>/dev/null || echo "MIT License" > "$RELEASE_DIR/LICENSE"
    cp "$PROJECT_DIR/install.sh" "$RELEASE_DIR/"
    cp "$PROJECT_DIR/install.ps1" "$RELEASE_DIR/"

    # 复制目录
    cp -r "$PROJECT_DIR/src" "$RELEASE_DIR/"
    cp -r "$PROJECT_DIR/references" "$RELEASE_DIR/"

    # 设置执行权限
    chmod +x "$RELEASE_DIR/install.sh"

    # 创建 tar.gz 包（适用于 macOS/Linux）
    info "创建 tar.gz 包..."
    cd "$DIST_DIR"
    tar -czf "${RELEASE_NAME}.tar.gz" "$RELEASE_NAME"

    # 创建 zip 包（适用于 Windows 和跨平台）
    info "创建 zip 包..."
    if command -v zip &> /dev/null; then
        zip -r "${RELEASE_NAME}.zip" "$RELEASE_NAME"
    else
        warn "zip 命令未找到，跳过 zip 包创建"
    fi

    cd "$PROJECT_DIR"

    info "发布包创建完成:"
    echo "  - $DIST_DIR/${RELEASE_NAME}.tar.gz"
    if [ -f "$DIST_DIR/${RELEASE_NAME}.zip" ]; then
        echo "  - $DIST_DIR/${RELEASE_NAME}.zip"
    fi
}

# 生成校验和
generate_checksums() {
    info "生成校验和..."
    cd "$DIST_DIR"

    # 生成校验和，忽略不存在的文件
    if command -v sha256sum &> /dev/null; then
        sha256sum *.tar.gz 2>/dev/null > checksums.txt || true
        sha256sum *.zip 2>/dev/null >> checksums.txt || true
    elif command -v shasum &> /dev/null; then
        shasum -a 256 *.tar.gz 2>/dev/null > checksums.txt || true
        shasum -a 256 *.zip 2>/dev/null >> checksums.txt || true
    else
        warn "无法生成校验和，sha256sum/shasum 未找到"
    fi

    cd "$PROJECT_DIR"

    if [ -s "$DIST_DIR/checksums.txt" ]; then
        info "校验和文件: $DIST_DIR/checksums.txt"
    fi
}

# 显示发布说明
show_release_notes() {
    echo ""
    echo "=========================================="
    echo "  发布包构建完成 v${VERSION}"
    echo "=========================================="
    echo ""
    echo "发布文件:"
    ls -lh "$DIST_DIR"/*.tar.gz 2>/dev/null || true
    ls -lh "$DIST_DIR"/*.zip 2>/dev/null || true
    echo ""
    echo "下一步操作:"
    echo "  运行 make publish 一键发布到 GitHub"
    echo ""
    echo "或手动操作:"
    echo "  1. 在 GitHub 创建 Release: v${VERSION}"
    echo "  2. 上传 dist/ 目录下的文件"
    echo ""
}

# 主函数
main() {
    echo "=========================================="
    echo "  Weekly Flow 打包工具 v${VERSION}"
    echo "=========================================="
    echo ""

    clean
    build_release
    generate_checksums
    show_release_notes

    info "打包完成!"
}

main "$@"
