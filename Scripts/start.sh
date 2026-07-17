#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 启动脚本
# 一键启动所有服务：后台守护进程 + MLX 推理 + App
# ──────────────────────────────────────────────────────────────

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    info "正在停止所有服务..."
    if [ -n "${ENV_DAEMON_PID:-}" ]; then
        kill "$ENV_DAEMON_PID" 2>/dev/null || true
    fi
    if [ -n "${MLX_DAEMON_PID:-}" ]; then
        kill "$MLX_DAEMON_PID" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# ─── 启动环境守护进程 ──────────────────────────────────────────

start_env_daemon() {
    info "启动环境守护进程 (env-daemon)..."
    local env_bin="$PROJECT_DIR/Services/env-daemon/target/release/env-daemon"

    if [ ! -f "$env_bin" ]; then
        warn "env-daemon 未构建，正在构建..."
        (cd "$PROJECT_DIR/Services/env-daemon" && cargo build --release)
    fi

    "$env_bin" &
    ENV_DAEMON_PID=$!
    info "env-daemon 已启动 (PID: $ENV_DAEMON_PID)"
    sleep 1
}

# ─── 启动 MLX 守护进程 ─────────────────────────────────────────

start_mlx_daemon() {
    info "启动 MLX 守护进程 (mlx-daemon)..."
    local mlx_daemon="$PROJECT_DIR/Services/mlx-daemon/daemon.py"

    if [ ! -f "$mlx_daemon" ]; then
        error "mlx-daemon 未找到: $mlx_daemon"
        return 1
    fi

    python3 "$mlx_daemon" --no-daemon &
    MLX_DAEMON_PID=$!
    info "mlx-daemon 已启动 (PID: $MLX_DAEMON_PID)"
    sleep 2
}

# ─── 启动 SwiftUI App ────────────────────────────────────────

start_app() {
    info "启动 Fusion Studio App..."
    local app_path="$PROJECT_DIR/.build/Fusion Studio.app"

    if [ -d "$app_path" ]; then
        open "$app_path"
    else
        # 开发模式：使用 swift run
        info "开发模式：swift run..."
        (cd "$PROJECT_DIR" && swift run &
         SWIFT_PID=$!
         wait $SWIFT_PID)
    fi
}

# ─── 主流程 ───────────────────────────────────────────────────

main() {
    echo "=== Fusion Studio 启动 ==="
    echo ""

    start_env_daemon
    start_mlx_daemon
    start_app

    info "所有服务已启动"
    info "按 Ctrl+C 停止所有服务"

    # 等待所有后台进程
    wait
}

main "$@"