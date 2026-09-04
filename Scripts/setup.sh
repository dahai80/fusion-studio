#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 开发环境快速设置脚本
# 一键安装所有依赖，构建所有组件
# ──────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── 检查系统要求 ──────────────────────────────────────────────

check_requirements() {
    info "=== 检查系统要求 ==="

    # macOS 版本
    local os_version=$(sw_vers -productVersion 2>/dev/null || echo "0")
    info "macOS: $os_version"

    # Apple Silicon
    local arch=$(uname -m)
    if [ "$arch" != "arm64" ]; then
        warn "非 Apple Silicon 设备，部分功能可能受限"
    else
        info "架构: $arch ✅"
    fi

    # Xcode CLI
    if ! xcode-select -p &>/dev/null; then
        error "Xcode CLI Tools 未安装，执行: xcode-select --install"
        exit 1
    fi
    info "Xcode CLI Tools: ✅"

    # Homebrew
    if ! command -v brew &>/dev/null; then
        error "Homebrew 未安装"
        info "安装: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    info "Homebrew: ✅"

    # Swift
    if ! command -v swift &>/dev/null; then
        error "Swift 未安装（需要 Xcode 或 Swift toolchain）"
        exit 1
    fi
    info "Swift: $(swift --version | head -1)"

    # Rust — F-ops-9: Services/env-daemon 已删除 (#296), Rust 现为可选 (仅本地 Rust 后台服务需要)。
    # 不再强制安装; 缺失则 warn 跳过, 不阻断 setup。
    if command -v rustc &>/dev/null; then
        info "Rust: $(rustc --version)"
    else
        warn "Rust 未安装 (可选, 本地 Rust 后台服务已移除 — 见 #296)。跳过。"
    fi

    # Python
    if ! command -v python3 &>/dev/null; then
        error "Python3 未安装"
        exit 1
    fi
    info "Python: $(python3 --version)"
}

# ─── 安装依赖 ───────────────────────────────────────────────────

install_deps() {
    info "=== 安装项目依赖 ==="

    # Homebrew 依赖
    local brew_packages=("cmake" "glfw" "glew")
    for pkg in "${brew_packages[@]}"; do
        if ! brew list "$pkg" &>/dev/null; then
            info "安装 $pkg..."
            brew install "$pkg"
        else
            info "$pkg: ✅"
        fi
    done

    # Python 依赖
    # OPS-7 (审计product-0905 P2): 不污染系统 pip3 — 优先 monorepo 共享 .venv (CLAUDE.md 约定),
    # 次选项目本地 .venv; 均无则 warn (不强制 pip3 install 入系统环境)。
    local pip_packages=("mlx" "pybullet" "psutil")
    local venv_dir=""
    local monorepo_venv="$PROJECT_DIR/../.venv/bin/activate"
    if [ -f "$monorepo_venv" ]; then
        venv_dir="$PROJECT_DIR/../.venv"
        info "使用 monorepo 共享 venv: $venv_dir"
        # shellcheck disable=SC1090
        source "$monorepo_venv"
    elif [ -f "$PROJECT_DIR/.venv/bin/activate" ]; then
        venv_dir="$PROJECT_DIR/.venv"
        info "使用项目本地 venv: $venv_dir"
        # shellcheck disable=SC1090
        source "$PROJECT_DIR/.venv/bin/activate"
    else
        warn "未找到 .venv (monorepo 或项目级)。Python 依赖检查将使用系统 python3 —"
        warn "建议先在 monorepo root 执行 source .venv/bin/activate 再运行本脚本 (CLAUDE.md 约定)。"
    fi

    local pip_cmd="pip3"
    if [ -n "$venv_dir" ]; then
        pip_cmd="$venv_dir/bin/pip"
    fi

    for pkg in "${pip_packages[@]}"; do
        if ! python3 -c "import $pkg" &>/dev/null 2>&1; then
            info "安装 $pkg..."
            if [ -n "$venv_dir" ]; then
                "$pip_cmd" install "$pkg"
            else
                warn "跳过 $pkg 安装 (无 venv, 避免污染系统环境) — 请在激活的 venv 中手动 pip install"
            fi
        else
            info "$pkg: ✅"
        fi
    done

    # 退出 venv (若本脚本激活了), 避免影响后续 shell 状态
    if [ -n "$venv_dir" ]; then
        deactivate 2>/dev/null || true
    fi
}

# ─── 构建所有组件 ────────────────────────────────────────────────

build_all() {
    info "=== 构建所有组件 ==="

    # 构建 Swift App
    info "构建 Fusion Studio App..."
    (cd "$PROJECT_DIR" && swift build -c release)
}

# ─── 主流程 ─────────────────────────────────────────────────────

main() {
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$PROJECT_DIR"

    echo "=== Fusion Studio 开发环境设置 ==="
    echo ""

    check_requirements
    echo ""
    install_deps
    echo ""
    build_all

    echo ""
    info "🎉 环境设置完成！"
    info "运行 ./Scripts/start.sh 启动 Fusion Studio"
}

main "$@"