#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 全量服务启动脚本
# Issue #377: 服务编排委派给 fusion-supervisor (fusion-sv up/down/status)。
# Studio 仅保留 UI/launch 关注点 (启动 App, --no-app) + fusion-sv 缺失时的 legacy 兜底。
# Usage: ./start.sh [start|stop|restart|status] [--no-app]
# Callers: developer CLI, CI pipeline
# Affected API: fusion-sv UDS /tmp/fusion-sv.sock → 41 服务 start.sh (registry: architecture/port-registry.yaml)
# User instruction: "修复issue #377" — delegate to fusion-sv, fix stale fusion-health port 11456→11469
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

# ─── fusion-sv 定位 (PATH 优先, 回退 monorepo 构建产物) ──────────
# fusion-sv 二进制: cargo build --release in fusion-supervisor。不在 PATH 时用绝对路径。
# monorepo 根: fusion-sv daemon 需从该目录启动 (registry_path=architecture/port-registry.yaml 相对路径,
#   非 CWD 启动则读注册表失败)。FUSION_ROOT 令 start_sh_path 解析 <root>/<repo>/start.sh。
MONO_ROOT="${MONO_ROOT:-$HOME/fusion}"
SV_SOCK="/tmp/fusion-sv.sock"
SV_LOG_DIR="$HOME/.fusion-sv/logs"
SV_DAEMON_LOG="$SV_LOG_DIR/daemon.log"

locate_fusion_sv() {
    if command -v fusion-sv >/dev/null 2>&1; then
        echo "fusion-sv"
        return 0
    fi
    local candidate="$MONO_ROOT/fusion-supervisor/target/release/fusion-sv"
    if [ -x "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    return 1
}

FUSION_SV="$(locate_fusion_sv 2>/dev/null || true)"

# ─── fusion-sv daemon 就绪检测 + 自举 ─────────────────────────
# ping 通 = daemon 在跑。否则从 MONO_ROOT 自举 (registry 相对路径需 CWD=MONO_ROOT),
# FUSION_ROOT 同步设给 start_sh_path 解析。等待 socket 就绪最多 8s。
sv_ping() {
    "$FUSION_SV" ping >/dev/null 2>&1
}

ensure_daemon() {
    if sv_ping; then
        return 0
    fi
    info "fusion-sv daemon 未运行, 自举 (CWD=$MONO_ROOT, FUSION_ROOT=$MONO_ROOT)..."
    mkdir -p "$SV_LOG_DIR"
    (
        cd "$MONO_ROOT"
        FUSION_ROOT="$MONO_ROOT" nohup "$FUSION_SV" daemon >> "$SV_DAEMON_LOG" 2>&1 &
    )
    for _i in $(seq 1 8); do
        sleep 1
        if sv_ping; then
            info "fusion-sv daemon 就绪"
            return 0
        fi
    done
    error "fusion-sv daemon 自举超时 (8s), 日志: $SV_DAEMON_LOG"
    return 1
}

# ─── legacy 兜底服务注册表 (fusion-sv 缺失时用) ──────────────────
# 格式: id|display_name|start_sh_path|health_type|health_target|start_order|critical
# health_type: socket | http | jsonrpc | none
# critical: 1=关键服务 0=可选
# #377: fusion-health 端口 11456→11469 (11456 现归 simulation-metrics, 见 port-registry.yaml + issue#16)

SERVICES=(
    "agent-studio|Agent Studio|~/fusion/fusion-agent-studio/start.sh|socket|/tmp/fusion-studio.sock|1|1"
    "mlx|Fusion-MLX|~/claude-home/fusion-mlx/start.sh|http|http://localhost:11432/health|0|1"
    "artifacts-engine|Artifacts Engine|~/fusion/fusion-artifacts-engine/start.sh|jsonrpc|http://127.0.0.1:11451|2|1"
    "fusion-rag|Fusion-RAG|~/fusion/fusion-rag/start.sh|http|http://127.0.0.1:11436/health|3|0"
    "fusion-doc|Fusion Doc|~/fusion/fusion-doc/start.sh|http|http://127.0.0.1:11449/api/health|4|0"
    "multi-node|Multi-Node|~/fusion/fusion-multi-node/start.sh|http|http://127.0.0.1:11452/api/health|5|0"
    "fusion-model-hub|Model Hub|~/fusion/fusion-model-hub/start.sh|http|http://127.0.0.1:11444/api/v1/system/info|6|0"
    "fusion-guard|Fusion Guard|~/fusion/fusion-guard/start.sh|socket|/tmp/fusion-guard.sock|7|0"
    "fusion-code|Fusion Code|~/fusion/fusion-code/start.sh|http|http://127.0.0.1:11441/api/project/context|8|0"
    "project-svc|Fusion Projects|~/fusion/fusion-projects/start.sh|socket|/tmp/fusion-project-svc.sock|9|0"
    "cowork-desk|CoWork Desk|~/fusion/fusion-cowork|socket|/tmp/fusion-cowork.sock|10|0"
    "fusion-science|Fusion Science|~/fusion/fusion-science/start.sh|http|http://127.0.0.1:11462/api/v1/health|11|0"
    "fusion-health|Fusion Health|~/fusion/fusion-health/start.sh|http|http://127.0.0.1:11469/api/v1/health|12|0"
    "fusion-event|Fusion Event|~/fusion/fusion-event/start.sh|socket|/tmp/fusion-event.sock|13|0"
)

expand_path() {
    echo "${1/#\~/$HOME}"
}

# ─── 健康探测 (legacy 兜底用) ─────────────────────────────────

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

# ─── 解析服务条目 (legacy 兜底用) ──────────────────────────────

parse_service() {
    local entry="$1"
    IFS='|' read -r S_ID S_NAME S_START_SH S_HEALTH_KIND S_HEALTH_TARGET S_ORDER S_CRITICAL <<< "$entry"
    S_START_SH=$(expand_path "$S_START_SH")
}

# ─── legacy: 启动单个服务 ──────────────────────────────────────

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

# ─── legacy: 停止单个服务 ──────────────────────────────────────

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

# ─── legacy: 查询单个服务状态 ──────────────────────────────────

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

# ─── SwiftUI App (Studio 自身 UI/launch, 不委派) ───────────────

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

# ─── fusion-sv 委派路径 (#377) ────────────────────────────────

sv_start() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║        Fusion Studio — 服务启动 (fusion-sv)      ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    if ! ensure_daemon; then
        error "fusion-sv daemon 不可用, 回退 legacy 启动路径"
        legacy_start
        return
    fi

    info "fusion-sv up (启动全部已注册服务, 按层级 core→cluster)..."
    "$FUSION_SV" up || warn "fusion-sv up 部分服务启动失败 (见 $SV_DAEMON_LOG + ~/.fusion-sv/logs/<svc>.log)"

    echo ""
    if [[ "${NO_APP:-0}" != "1" ]]; then
        start_app
    else
        info "跳过 App 启动 (--no-app)"
    fi

    echo ""
    info "服务启动完成 (fusion-sv)"
    echo ""
    sv_status
}

sv_stop() {
    echo ""
    info "停止全部服务 (fusion-sv down, 逆序 cluster→core)..."
    if ! sv_ping; then
        warn "fusion-sv daemon 未运行, 无需停止"
        return
    fi
    "$FUSION_SV" down || warn "fusion-sv down 部分服务停止失败"
    info "全部服务已停止 (fusion-sv)"
}

sv_status() {
    echo ""
    echo "─── 服务状态 (fusion-sv) ─────────────────────────"
    if sv_ping; then
        "$FUSION_SV" status
    else
        warn "fusion-sv daemon 未运行"
    fi
    echo ""
}

# ─── legacy 兜底路径 (fusion-sv 缺失时) ───────────────────────

legacy_start() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║     Fusion Studio — 全量服务启动 (legacy)        ║"
    echo "╚══════════════════════════════════════════════════╝"
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
    info "所有服务启动完成 (legacy)"
    echo ""
    legacy_status
}

legacy_stop() {
    echo ""
    info "停止所有服务 (legacy)..."
    local sorted
    sorted=$(printf '%s\n' "${SERVICES[@]}" | sort -t'|' -k6 -nr)
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        stop_one "$entry"
    done <<< "$sorted"
    echo ""
    info "所有服务已停止 (legacy)"
}

legacy_status() {
    echo ""
    echo "─── 服务状态 (legacy) ─────────────────────────────"
    printf "  %-4s %-20s %s\n" "" "服务" "状态"
    echo "  ────────────────────────────────────────────────"
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
    start)
        if [ -n "$FUSION_SV" ]; then
            sv_start
        else
            warn "fusion-sv 未找到 (PATH + $MONO_ROOT/fusion-supervisor/target/release/fusion-sv 均无), 回退 legacy 14 服务路径"
            legacy_start
        fi
        ;;
    stop)
        if [ -n "$FUSION_SV" ] && sv_ping; then
            sv_stop
        else
            legacy_stop
        fi
        ;;
    restart)
        if [ -n "$FUSION_SV" ]; then
            sv_stop
            echo ""
            sleep 2
            sv_start
        else
            legacy_stop
            echo ""
            sleep 2
            legacy_start
        fi
        ;;
    status)
        if [ -n "$FUSION_SV" ] && sv_ping; then
            sv_status
        else
            legacy_status
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [--no-app]"
        echo ""
        echo "服务编排: fusion-sv (fusion-supervisor) up/down/status, registry=architecture/port-registry.yaml"
        echo "fusion-sv 缺失时回退 legacy 14 服务路径 (SERVICES 数组)"
        echo ""
        echo "关键服务 (registry): fusion-mlx, fusion-gateway, fusion-agent-studio, fusion-artifacts-engine"
        echo ""
        echo "环境变量:"
        echo "  MONO_ROOT  monorepo 根目录 (默认 \$HOME/fusion, fusion-sv daemon 启动 CWD)"
        exit 1
        ;;
esac
