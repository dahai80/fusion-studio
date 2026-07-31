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
    if [ -n "${ARTIFACTS_ENGINE_PID:-}" ]; then
        kill "$ARTIFACTS_ENGINE_PID" 2>/dev/null || true
    fi
    if [ -n "${PROJECT_SVC_PID:-}" ]; then
        kill "$PROJECT_SVC_PID" 2>/dev/null || true
    fi
    if [ -n "${COWORK_DESK_PID:-}" ]; then
        kill "$COWORK_DESK_PID" 2>/dev/null || true
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

# ─── 启动 Artifacts Engine ──────────────────────────────────────

start_artifacts_engine() {
    info "启动 Artifacts Engine (fusion-artifacts-engine)..."
    local artifacts_dir="$HOME/fusion/fusion-artifacts-engine"

    if [ ! -d "$artifacts_dir" ]; then
        warn "fusion-artifacts-engine 未找到: $artifacts_dir，跳过"
        return 0
    fi

    # 优先使用 venv
    local python="python3"
    if [ -f "$artifacts_dir/.venv/bin/activate" ]; then
        source "$artifacts_dir/.venv/bin/activate"
        python="python"
    fi

    # 检查是否已在运行
    if curl -sf http://127.0.0.1:8892 -H "Content-Type: application/json" \
         -d '{"jsonrpc":"2.0","method":"ping","id":1}' 2>/dev/null | grep -q '"pong"'; then
        info "artifacts-engine 已在运行，跳过启动"
        return 0
    fi

    (cd "$artifacts_dir" && $python -m fusion_artifacts_engine start) &
    ARTIFACTS_ENGINE_PID=$!
    info "artifacts-engine 已启动 (PID: $ARTIFACTS_ENGINE_PID)"

    # 等待就绪
    for i in $(seq 1 10); do
        sleep 1
        if curl -sf http://127.0.0.1:8892 -H "Content-Type: application/json" \
             -d '{"jsonrpc":"2.0","method":"ping","id":1}' 2>/dev/null | grep -q '"pong"'; then
            info "artifacts-engine 就绪"
            return 0
        fi
    done
    warn "artifacts-engine 启动超时，继续后续流程"
}

# ─── 启动 Fusion Projects 服务 (project-svc) ────────────────────

start_project_svc() {
    info "启动 Fusion Projects 服务 (project-svc)..."
    local proj_dir="$HOME/fusion/fusion-projects"
    local sock="${FUSION_PROJECT_SOCK:-/tmp/fusion-project-svc.sock}"

    if [ ! -d "$proj_dir" ]; then
        warn "fusion-projects 未找到: $proj_dir，跳过"
        return 0
    fi

    local python="python3"
    if [ -f "$proj_dir/.venv/bin/activate" ]; then
        source "$proj_dir/.venv/bin/activate"
        python="python"
    fi

    # 已在运行则跳过（UDS connect 成功即存活）
    if "$python" -c "import socket,sys
try:
    s=socket.socket(socket.AF_UNIX);s.settimeout(2);s.connect('$sock');s.close();sys.exit(0)
except Exception: sys.exit(1)" 2>/dev/null; then
        info "project-svc 已在运行，跳过启动"
        return 0
    fi

    (cd "$proj_dir" && FUSION_PROJECT_SOCK="$sock" $python -m project_service.daemon_server) &
    PROJECT_SVC_PID=$!
    info "project-svc 已启动 (PID: $PROJECT_SVC_PID)"

    for i in $(seq 1 10); do
        sleep 1
        if "$python" -c "import socket,sys
try:
    s=socket.socket(socket.AF_UNIX);s.settimeout(2);s.connect('$sock');s.close();sys.exit(0)
except Exception: sys.exit(1)" 2>/dev/null; then
            info "project-svc 就绪"
            return 0
        fi
    done
    warn "project-svc 启动超时，继续后续流程"
}

# ─── 启动 CoWork Desk RPC ──────────────────────────────────────

start_cowork_desk_rpc() {
    info "启动 CoWork Desk RPC (fusion-cowork)..."
    local cowork_dir="$HOME/fusion/fusion-cowork"
    local sock="${FUSION_COWORK_SOCK:-/tmp/fusion-cowork.sock}"

    if [ ! -d "$cowork_dir" ]; then
        warn "fusion-cowork 未找到: $cowork_dir，跳过"
        return 0
    fi

    local python="python3"
    if [ -f "$cowork_dir/.venv/bin/activate" ]; then
        source "$cowork_dir/.venv/bin/activate"
        python="python"
    fi

    if "$python" -c "import socket,sys
try:
    s=socket.socket(socket.AF_UNIX);s.settimeout(2);s.connect('$sock');s.close();sys.exit(0)
except Exception: sys.exit(1)" 2>/dev/null; then
        info "cowork-desk 已在运行，跳过启动"
        return 0
    fi

    (cd "$cowork_dir" && $python -m fusion_cowork desk rpc --sock "$sock") &
    COWORK_DESK_PID=$!
    info "cowork-desk 已启动 (PID: $COWORK_DESK_PID)"

    for i in $(seq 1 10); do
        sleep 1
        if "$python" -c "import socket,sys
try:
    s=socket.socket(socket.AF_UNIX);s.settimeout(2);s.connect('$sock');s.close();sys.exit(0)
except Exception: sys.exit(1)" 2>/dev/null; then
            info "cowork-desk 就绪"
            return 0
        fi
    done
    warn "cowork-desk 启动超时，继续后续流程"
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
    start_artifacts_engine
    start_project_svc
    start_cowork_desk_rpc
    start_app

    info "所有服务已启动"
    info "按 Ctrl+C 停止所有服务"

    # 等待所有后台进程
    wait
}

main "$@"