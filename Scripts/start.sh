#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 全量服务启动脚本
# 按 SidebarSection 顺序启动所有后台服务
# Usage: ./start.sh [start|stop|restart|status] [--no-app]
# Callers: developer CLI, CI pipeline
# Affected API: health endpoints for all services (port-aligned to FusionConfig.swift)
# Data: SERVICES array (id|display_name|start_sh|health_type|health_target|order|critical)
# User instruction: "修复issue #111" — align ports to FusionConfig authoritative table
# ──────────────────────────────────────────────────────────────

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }
skip()  { printf "${CYAN}[SKIP]${NC}  %s\n" "$*"; }

# ─── 服务注册表（与 SidebarSection + UpstreamServiceManager 对齐）──
# 格式: id|display_name|start_sh_path|health_type|health_target|start_order|critical
# health_type: socket | http | jsonrpc | none
# critical: 1=关键服务 0=可选

SERVICES=(
    "agent-studio|Agent Studio|~/fusion/fusion-agent-studio/start.sh|socket|/tmp/fusion-studio.sock|1|1"
    "mlx|Fusion-MLX|~/claude-home/fusion-mlx/start.sh|http|http://localhost:11432/health|0|1"
    "artifacts-engine|Artifacts Engine|~/fusion/fusion-artifacts-engine/start.sh|jsonrpc|http://127.0.0.1:11451|2|1"
    "fusion-rag|Fusion-RAG|~/fusion/fusion-kb/start.sh|http|http://127.0.0.1:11436/health|3|0"
    "fusion-doc|Fusion Doc|~/fusion/fusion-doc/start.sh|http|http://127.0.0.1:11449/api/health|4|0"
    "multi-node|Multi-Node|~/fusion/fusion-multi-node/start.sh|http|http://127.0.0.1:11452/api/health|5|0"
    "fusion-model-hub|Model Hub|~/fusion/fusion-model-hub/start.sh|http|http://127.0.0.1:11444/api/v1/system/info|6|0"
    "fusion-code|Fusion Code|~/fusion/fusion-code/start.sh|http|http://127.0.0.1:11441/api/project/context|8|0"
    "project-svc|Fusion Projects|~/fusion/fusion-projects/start.sh|socket|/tmp/fusion-project-svc.sock|9|0"
    "cowork-desk|CoWork Desk|~/fusion/fusion-cowork|socket|/tmp/fusion-cowork.sock|10|0"
)

expand_path() {
    echo "${1/#\~/$HOME}"
}

# ─── 健康探测 ──────────────────────────────────────────────────

probe_socket() {
    local sock="$1"
    [ -S "$sock" ] || return 1
    python3 -c "import socket,sys
try:
    s=socket.socket(socket.AF_UNIX);s.settimeout(2);s.connect(sys.argv[1]);s.close();sys.exit(0)
except Exception: sys.exit(1)" "$sock" 2>/dev/null
}

probe_http() {
    curl -sf -o /dev/null -m 2 "$1" 2>/dev/null
}

probe_jsonrpc() {
    curl -sf -m 2 -H "Content-Type: application/json" \
         -d '{"jsonrpc":"2.0","method":"ping","id":1}' "$1" 2>/dev/null | grep -q '"pong"'
}

probe_health() {
    local kind="$1" target="$2"
    case "$kind" in
        socket)  probe_socket "$target" ;;
        http)    probe_http "$target" ;;
        jsonrpc) probe_jsonrpc "$target" ;;
        *)       return 1 ;;
    esac
}

# ─── 解析服务条目 ──────────────────────────────────────────────

parse_service() {
    local entry="$1"
    IFS='|' read -r S_ID S_NAME S_START_SH S_HEALTH_KIND S_HEALTH_TARGET S_ORDER S_CRITICAL <<< "$entry"
    S_START_SH=$(expand_path "$S_START_SH")
}

# ─── 启动单个服务 ──────────────────────────────────────────────

start_one() {
    local entry="$1"
    parse_service "$entry"

    info "启动 ${S_NAME}..."

    if probe_health "$S_HEALTH_KIND" "$S_HEALTH_TARGET"; then
        skip "${S_NAME} 已在运行"
        return 0
    fi

    # cowork 无 start.sh，直接 python -m
    if [ "$S_ID" = "cowork-desk" ]; then
        if [ ! -d "$S_START_SH" ]; then
            warn "fusion-cowork 未找到: $S_START_SH，跳过"
            return 0
        fi
        local python_bin="$S_START_SH/.venv/bin/python"
        [ ! -f "$python_bin" ] && python_bin="python3"
        (cd "$S_START_SH" && "$python_bin" -m fusion_cowork.cli desk rpc --sock /tmp/fusion-cowork.sock) &
        info "${S_NAME} 已启动 (PID: $!)"
        for _i in $(seq 1 15); do
            sleep 1
            if probe_socket /tmp/fusion-cowork.sock; then
                info "${S_NAME} 就绪"
                return 0
            fi
        done
        warn "${S_NAME} 启动超时，继续后续流程"
        return 0
    fi

    if [ ! -f "$S_START_SH" ]; then
        if [ "$S_CRITICAL" = "1" ]; then
            error "${S_NAME} 未找到 start.sh: $S_START_SH (关键服务!)"
        else
            warn "${S_NAME} 未找到 start.sh: $S_START_SH，跳过"
        fi
        return 0
    fi

    [ ! -x "$S_START_SH" ] && chmod +x "$S_START_SH"

    local log_dir="$PROJECT_DIR/.build/service-logs"
    mkdir -p "$log_dir"

    # 后台执行 start.sh start，防止 exec 阻塞（如 fusion-code）
    bash "$S_START_SH" start >> "$log_dir/${S_ID}.log" 2>&1 &
    local start_pid=$!

    # 先等 start.sh 退出（自带 nohup & 的会很快退出；exec 的会一直运行）
    local wait_count=0
    while kill -0 "$start_pid" 2>/dev/null && [ $wait_count -lt 5 ]; do
        sleep 1
        wait_count=$((wait_count + 1))
        # 如果已经健康了，start.sh 可能还在跑（exec 模式），直接跳过
        if probe_health "$S_HEALTH_KIND" "$S_HEALTH_TARGET"; then
            info "${S_NAME} 就绪 (start.sh 仍在运行 PID=$start_pid)"
            return 0
        fi
    done

    # start.sh 已退出或超时，检查健康
    if probe_health "$S_HEALTH_KIND" "$S_HEALTH_TARGET"; then
        info "${S_NAME} 就绪"
        return 0
    fi

    # start.sh 退出但服务未就绪，继续等待
    for _i in $(seq 1 25); do
        sleep 1
        if probe_health "$S_HEALTH_KIND" "$S_HEALTH_TARGET"; then
            info "${S_NAME} 就绪"
            return 0
        fi
    done

    if [ "$S_CRITICAL" = "1" ]; then
        error "${S_NAME} 启动超时 (30s), 日志: $log_dir/${S_ID}.log"
    else
        warn "${S_NAME} 启动超时 (30s)，继续后续流程"
    fi
}

# ─── 停止单个服务 ──────────────────────────────────────────────

stop_one() {
    local entry="$1"
    parse_service "$entry"

    info "停止 ${S_NAME}..."

    if [ "$S_ID" = "cowork-desk" ]; then
        pkill -f "fusion_cowork desk rpc" 2>/dev/null || true
        rm -f /tmp/fusion-cowork.sock
        info "${S_NAME} 已停止"
        return 0
    fi

    if [ ! -f "$S_START_SH" ]; then
        return 0
    fi
    bash "$S_START_SH" stop 2>/dev/null || true
    info "${S_NAME} 已停止"
}

# ─── 查询单个服务状态 ──────────────────────────────────────────

status_one() {
    local entry="$1"
    parse_service "$entry"

    if probe_health "$S_HEALTH_KIND" "$S_HEALTH_TARGET"; then
        printf "  ${GREEN}●${NC} %-20s %s\n" "$S_NAME" "运行中"
    elif [ "$S_ID" = "cowork-desk" ]; then
        if [ -d "$S_START_SH" ]; then
            printf "  ${RED}○${NC} %-20s %s\n" "$S_NAME" "未启动"
        else
            printf "  ${YELLOW}○${NC} %-20s %s\n" "$S_NAME" "未安装"
        fi
    elif [ -f "$S_START_SH" ]; then
        printf "  ${RED}○${NC} %-20s %s\n" "$S_NAME" "未启动"
    else
        printf "  ${YELLOW}○${NC} %-20s %s\n" "$S_NAME" "未安装"
    fi
}

# ─── env-daemon (Rust, 内置) ────────────────────────────────

start_env_daemon() {
    info "启动 env-daemon..."
    local env_bin="$PROJECT_DIR/Services/env-daemon/target/release/env-daemon"
    if [ ! -f "$env_bin" ]; then
        warn "env-daemon 未构建，正在构建..."
        (cd "$PROJECT_DIR/Services/env-daemon" && cargo build --release 2>&1)
    fi
    if [ -f "$env_bin" ]; then
        "$env_bin" &
        info "env-daemon 已启动 (PID: $!)"
    else
        warn "env-daemon 构建失败，跳过"
    fi
}

stop_env_daemon() {
    pkill -f "env-daemon" 2>/dev/null || true
    info "env-daemon 已停止"
}

# ─── SwiftUI App ──────────────────────────────────────────────

start_app() {
    info "启动 Fusion Studio App..."
    local app_path="$PROJECT_DIR/.build/Fusion Studio.app"
    if [ -d "$app_path" ]; then
        open "$app_path"
        info "App 已启动"
    else
        info "App bundle 未找到，开发模式: swift run..."
        (cd "$PROJECT_DIR" && swift run)
    fi
}

# ─── 主流程 ───────────────────────────────────────────────────

do_start() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║        Fusion Studio — 全量服务启动              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    start_env_daemon
    echo ""

    # 按 start_order 排序启动
    local sorted
    sorted=$(printf '%s\n' "${SERVICES[@]}" | sort -t'|' -k6 -n)
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        start_one "$entry"
    done <<< "$sorted"

    echo ""

    if [[ "${NO_APP:-0}" != "1" ]]; then
        start_app
    else
        info "跳过 App 启动 (--no-app)"
    fi

    echo ""
    info "所有服务启动完成"
    echo ""
    do_status
}

do_stop() {
    echo ""
    info "停止所有服务..."
    local sorted
    sorted=$(printf '%s\n' "${SERVICES[@]}" | sort -t'|' -k6 -nr)
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        stop_one "$entry"
    done <<< "$sorted"
    stop_env_daemon
    echo ""
    info "所有服务已停止"
}

do_restart() {
    do_stop
    echo ""
    sleep 2
    do_start
}

do_status() {
    echo ""
    echo "─── 服务状态 ─────────────────────────────────────"
    printf "  %-4s %-20s %s\n" "" "服务" "状态"
    echo "  ────────────────────────────────────────────────"
    if pgrep -f "env-daemon" >/dev/null 2>&1; then
        printf "  ${GREEN}●${NC} %-20s %s\n" "env-daemon" "运行中"
    else
        printf "  ${RED}○${NC} %-20s %s\n" "env-daemon" "未启动"
    fi
    for entry in "${SERVICES[@]}"; do
        status_one "$entry"
    done
    echo ""
}

# ─── 入口 ─────────────────────────────────────────────────────

ACTION="${1:-start}"
if [[ " ${@:2} " == *" --no-app "* ]]; then
    NO_APP=1
fi

case "$ACTION" in
    start)   do_start ;;
    stop)    do_stop ;;
    restart) do_restart ;;
    status)  do_status ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [--no-app]"
        echo ""
        echo "服务列表 (按 SidebarSection):"
        echo "  Projects     → project-svc (UDS /tmp/fusion-project-svc.sock)"
        echo "  Artifacts    → artifacts-engine (JSON-RPC :8892)"
        echo "  Code         → fusion-code (HTTP :4827)"
        echo "  Design       → fd-cli (内置，无需启动)"
        echo "  Agent        → agent-studio (UDS /tmp/fusion-studio.sock)"
        echo "  AI Agent     → agent-studio (同上)"
        echo "  CoWork       → cowork-desk (UDS /tmp/fusion-cowork.sock)"
        echo "  FSB          → (开发中)"
        echo "  Fusion-MLX   → fusion-mlx (HTTP :11434)"
        echo "  Multi-Node   → multi-node (HTTP :9753)"
        echo ""
        echo "关键服务: agent-studio, fusion-mlx, artifacts-engine"
        exit 1
        ;;
esac
