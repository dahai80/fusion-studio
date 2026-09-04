#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 构建脚本
# 构建全部组件: SwiftUI App + Rust 后台服务 + Python 服务
# 支持: debug / release / package / sign / notarize / dmg
# ──────────────────────────────────────────────────────────────

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Fusion Studio"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONFIGURATION="${CONFIGURATION:-release}"

# Callers: build.sh package/dmg/sign. Affected API: VERSION variable → DMG filename + Info.plist CFBundleShortVersionString. Data: version string. User: "修复 Release workflow"
# 版本信息
VERSION="0.1.57"
BUILD_NUM=$(date +%Y%m%d%H%M)

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${CYAN}━━━ $1 ━━━${NC}"; }

# ─── 阶段 1: 构建 Rust 后台服务 ────────────────────────────────

build_services() {
    step "构建 Rust 后台服务"
    info "无 Rust 后台服务需构建 (env-daemon 已删除, env.* 由中央路由 daemon_server.py 实现)"
}

# ─── 阶段 2: 构建 SwiftUI App ─────────────────────────────────

build_app() {
    step "构建 Fusion Studio App"

    # 使用 Swift Package Manager 构建
    # F-ops-10: tail -5 → tail -20 + tee 落盘, 提升构建失败可诊断性 (pipefail 保 exit code 透传)。
    (cd "$PROJECT_DIR" && swift build -c $CONFIGURATION 2>&1 | tee /tmp/fusion-studio-spm-build.log | tail -20)
    info "✅ SPM 构建完成"

    # 将 Info.plist 复制到 SPM 构建产物旁（裸二进制运行需要隐私描述）
    local binary_path=$(cd "$PROJECT_DIR" && swift build -c $CONFIGURATION --show-bin-path 2>/dev/null || echo "")
    if [ -n "$binary_path" ] && [ -d "$binary_path" ]; then
        cp "$PROJECT_DIR/FusionStudio/Resources/Info.plist" "$binary_path/"
        info "✅ 复制 Info.plist 到构建产物目录"
    fi
}

# ─── 阶段 2.5: 打包 Python 后端运行时 (Track A #393) ──────────
# 下载 pinned python-build-standalone, 安装最小依赖 (copy 模式非 -e, 可重定位),
# 拷贝 agent_runtime/, 生成可重定位 wrapper start.sh + MANIFEST.txt。
bundle_python() {
    step "打包 Python 后端运行时 (Contents/Services)"
    local app_dir="$APP_BUNDLE/Contents"
    local svc_dir="$app_dir/Services"
    mkdir -p "$svc_dir"

    local pin_file="$PROJECT_DIR/Scripts/.python-standalone-pin.txt"
    if [ ! -f "$pin_file" ]; then
        warn "未找到 python-build-standalone pin 文件, 跳过 Python 打包"
        return 0
    fi
    # 解析 pin (RELEASE / ASSET / SHA256)
    local release asset expected_sha
    release=$(grep '^RELEASE=' "$pin_file" | cut -d= -f2)
    asset=$(grep '^ASSET=' "$pin_file" | cut -d= -f2)
    expected_sha=$(grep '^SHA256=' "$pin_file" | cut -d= -f2)
    if [ -z "$release" ] || [ -z "$asset" ] || [ "$expected_sha" = "__PENDING_VERIFY__" ]; then
        warn "python pin 不完整 (RELEASE/ASSET/SHA256), 跳过 Python 打包"
        return 0
    fi

    local cache_dir="$HOME/.fusion-studio/build-cache/python"
    mkdir -p "$cache_dir"
    local tarball="$cache_dir/$asset"
    local url="https://github.com/astral-sh/python-build-standalone/releases/download/$release/$asset"

    # 下载 (缓存命中 + sha256 校验通过则跳过)
    local need_download=1
    if [ -f "$tarball" ]; then
        local actual_sha
        actual_sha=$(shasum -a 256 "$tarball" | awk '{print $1}')
        if [ "$actual_sha" = "$expected_sha" ]; then
            need_download=0
            info "✅ python-build-standalone 缓存命中 (sha256 校验通过)"
        else
            warn "缓存 sha256 不匹配, 重新下载"
        fi
    fi
    if [ "$need_download" = "1" ]; then
        info "下载 python-build-standalone: $url"
        curl -L --fail -o "$tarball" "$url" || { error "下载失败"; return 1; }
        local actual_sha
        actual_sha=$(shasum -a 256 "$tarball" | awk '{print $1}')
        if [ "$actual_sha" != "$expected_sha" ]; then
            error "python-build-standalone sha256 校验失败: 期望 $expected_sha 实得 $actual_sha"
            return 1
        fi
        info "✅ sha256 校验通过: $expected_sha"
    fi

    # 解压到 Contents/Services/python
    local py_dir="$svc_dir/python"
    rm -rf "$py_dir"
    mkdir -p "$py_dir"
    tar -xzf "$tarball" -C "$svc_dir" || { error "解压失败"; return 1; }
    # tarball 顶层是 python/ 目录, 解压后 $svc_dir/python 已就位
    if [ ! -x "$py_dir/bin/python3" ]; then
        error "解压后未找到 $py_dir/bin/python3"
        return 1
    fi
    info "✅ Python 运行时: $("$py_dir/bin/python3" --version 2>&1)"

    # 安装最小 PyPI 依赖 (copy 模式, --target 写入固定目录可重定位)
    # 注: 不用 --no-deps —— fastapi/uvicorn/pydantic 有必需的运行时传递依赖
    # (starlette / typing-extensions / typing-inspection 等), --no-deps 会导致
    # daemon_server 启动时 ModuleNotFoundError. 依赖树由 bundle-requirements.txt
    # 顶层包经 pip resolver 解析, 只装必需的, 不会拉全树.
    local site_dir="$py_dir/lib/python3.12/site-packages"
    local req_file="$PROJECT_DIR/Scripts/bundle-requirements.txt"
    if [ -f "$req_file" ]; then
        info "安装最小 PyPI 依赖到 bundle site-packages..."
        # bundled python 可能未带 pip, 先 ensurepip (失败则回退尝试直接 pip)
        if ! "$py_dir/bin/python3" -m pip --version >/dev/null 2>&1; then
            warn "bundled python 缺 pip, 执行 ensurepip..."
            "$py_dir/bin/python3" -m ensurepip --upgrade 2>&1 | tail -3 || {
                warn "ensurepip 失败, PyPI 依赖安装将跳过"
            }
        fi
        "$py_dir/bin/python3" -m pip install --target "$site_dir" -r "$req_file" 2>&1 | tail -8 || {
            warn "PyPI 依赖安装失败 (网络?), 后端可启动但部分 RPC 可能不可用"
        }
    fi

    # 安装 in-tree fusion-* 包 (copy 模式非 -e, 避免绝对路径 egg-link)
    local mono_root="${MONO_ROOT:-$HOME/fusion}"
    local pkg
    for pkg in fusion-core fusion-identity fusion-plugins-ecosystem; do
        local src="$mono_root/$pkg"
        if [ -d "$src" ]; then
            info "安装 $pkg (copy 模式)..."
            "$py_dir/bin/python3" -m pip install --no-deps --target "$site_dir" "$src" 2>&1 | tail -3 || {
                warn "$pkg 安装失败, 跳过"
            }
        else
            warn "$pkg 源码未找到 ($src), 跳过"
        fi
    done

    # 拷贝 agent_runtime (daemon_server.py + agent_runtime 包)
    local ar_src="$mono_root/fusion-agent-studio/agent_runtime"
    if [ -d "$ar_src" ]; then
        cp -R "$ar_src" "$svc_dir/agent_runtime"
        info "✅ 拷贝 agent_runtime ($(du -sh "$svc_dir/agent_runtime" | awk '{print $1}'))"
    else
        error "agent_runtime 源码未找到: $ar_src"
        return 1
    fi

    # 拷贝 tools + server (agent_runtime 的同级包, 模块加载期直接导入, 必须随包)
    # tools: _runtime_nodes.py 顶层 `from tools.plan_tools import ...` (非惰性)
    # server: fusion_mlx_client / fusion_rag_client (handler 内惰性, 但体积小一并打包)
    local sib
    for sib in tools server; do
        local sib_src="$mono_root/fusion-agent-studio/$sib"
        if [ -d "$sib_src" ]; then
            cp -R "$sib_src" "$svc_dir/$sib"
            info "✅ 拷贝 $sib ($(du -sh "$svc_dir/$sib" | awk '{print $1}'))"
        else
            warn "$sib 源码未找到 ($sib_src), 跳过"
        fi
    done

    # 生成可重定位 wrapper start.sh (fusion-studio 自有, 非上游)
    # 注: daemon_server.py 用相对导入 (from .chat_engine import ...), 必须用
    # `python3 -m agent_runtime.daemon_server` 运行 (而非直接运行 .py),
    # 且 PYTHONPATH 须含 agent_runtime 的父目录 ($SCRIPT_DIR), 与上游
    # start.sh 的 `python3 -m agent_runtime.daemon_server` 一致。
    cat > "$svc_dir/start.sh" << 'WRAPPER'
#!/bin/bash
# Fusion Studio bundled backend wrapper (Track A #393).
# Relocatable: PYTHONHOME/PYTHONPATH resolved via $SCRIPT_DIR at runtime.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONHOME="$SCRIPT_DIR/python"
export PYTHONPATH="$SCRIPT_DIR:$SCRIPT_DIR/python/lib/python3.12/site-packages"
exec "$SCRIPT_DIR/python/bin/python3" -m agent_runtime.daemon_server "$@"
WRAPPER
    chmod +x "$svc_dir/start.sh"
    info "✅ 生成 wrapper start.sh (可重定位)"

    # 生成 MANIFEST.txt (诊断/更新校验)
    {
        echo "fusion-studio bundled Python runtime (Track A #393)"
        echo "python-build-standalone release: $release"
        echo "asset: $asset"
        echo "sha256: $expected_sha"
        echo "python version: $("$py_dir/bin/python3" --version 2>&1)"
        echo "site-packages: $(ls "$site_dir" 2>/dev/null | tr '\n' ' ')"
        echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$svc_dir/MANIFEST.txt"
    info "✅ MANIFEST.txt 生成"

    info "✅ Python 后端运行时打包完成: $svc_dir ($(du -sh "$svc_dir" | awk '{print $1}'))"
}

# ─── 阶段 3: 打包 .app Bundle ─────────────────────────────────

package_app() {
    step "打包 Fusion Studio.app"

    local app_dir="$APP_BUNDLE/Contents"
    mkdir -p "$app_dir/MacOS" "$app_dir/Resources" "$app_dir/Frameworks" "$app_dir/Services"

    local binary_path=$(cd "$PROJECT_DIR" && swift build -c $CONFIGURATION --show-bin-path 2>/dev/null || echo "")
    if [ -n "$binary_path" ] && [ -f "$binary_path/FusionStudio" ]; then
        cp "$binary_path/FusionStudio" "$app_dir/MacOS/"
        info "✅ 复制 App 二进制"
    else
        error "找不到构建产物: $binary_path/FusionStudio"
        return 1
    fi

    # Track A #393: 打包 Python 后端运行时到 Contents/Services
    bundle_python || { error "Python 后端运行时打包失败"; return 1; }

    # 生成 Info.plist
    cat > "$app_dir/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FusionStudio</string>
    <key>CFBundleIdentifier</key>
    <string>com.fusion-mlx.studio</string>
    <key>CFBundleName</key>
    <string>Fusion Studio</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUM</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSArchitecturePriority</key>
    <array><string>arm64</string></array>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Fusion Studio needs speech recognition for voice input in chat.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Fusion Studio needs microphone access for voice input in chat.</string>
    <key>NSCameraUsageDescription</key>
    <string>Fusion Studio needs camera access for multimodal input.</string>
</dict>
</plist>
PLIST
    info "✅ 生成 Info.plist"

    # 设置 App 图标（.icns 格式，macOS Dock 必需）
    if [ -f "$PROJECT_DIR/FusionStudio/Resources/AppIcon.icns" ]; then
        cp "$PROJECT_DIR/FusionStudio/Resources/AppIcon.icns" "$app_dir/Resources/AppIcon.icns"
        plutil -insert "CFBundleIconFile" -string "AppIcon" "$app_dir/Info.plist" 2>/dev/null || true
        info "✅ 设置 App 图标 (icns)"
    fi

    # 复制 Entitlements
    if [ -f "$PROJECT_DIR/FusionStudio/Resources/Entitlements.plist" ]; then
        cp "$PROJECT_DIR/FusionStudio/Resources/Entitlements.plist" "$app_dir/"
        info "✅ 复制 Entitlements"
    fi

    # 复制资源
    if [ -d "$PROJECT_DIR/FusionStudio/Resources" ]; then
        cp -r "$PROJECT_DIR/FusionStudio/Resources/"* "$app_dir/Resources/" 2>/dev/null || true
    fi

    # 构建 + 复制 fusion-design CLI
    local fd_dir="$HOME/fusion/fusion-design"
    if [ -f "$fd_dir/Cargo.toml" ]; then
        info "构建 fusion-design CLI..."
        (cd "$fd_dir" && cargo build --release -p fd-cli 2>&1 | tail -3)
        local fd_cli="$fd_dir/target/release/fusion-design"
        if [ -f "$fd_cli" ]; then
            cp "$fd_cli" "$app_dir/Resources/"
            info "✅ 复制 fusion-design CLI"
        else
            warn "fusion-design CLI 未找到, 跳过"
        fi
        # 更新 wasm (issue #206: 拒绝静默回退陈旧件)
        local fd_target="$fd_dir/target/wasm32-unknown-unknown"
        local fd_wasm="$fd_target/release/fd_host_web_bg.wasm"
        local fd_js="$fd_target/release/fd_host_web.js"
        local wasm_profile="release"
        if [ ! -f "$fd_wasm" ]; then
            fd_wasm="$fd_target/debug/fd_host_web_bg.wasm"
            fd_js="$fd_target/debug/fd_host_web.js"
            wasm_profile="debug"
        fi
        # 校验 bindgen 产物齐全: _bg.wasm + .js 缺一不可
        if [ -d "$fd_target" ] && { [ ! -f "$fd_wasm" ] || [ ! -f "$fd_js" ]; }; then
            warn "⚠️  fusion-design target 存在但缺 wasm-bindgen 产物 (profile=$wasm_profile)"
            warn "    需先在 fusion-design 跑 wasm-bindgen 后处理, 否则回退内置陈旧 wasm"
            warn "    缺失: $([ ! -f "$fd_wasm" ] && echo "_bg.wasm") $([ ! -f "$fd_js" ] && echo ".js")"
        fi
        if [ -f "$fd_wasm" ] && [ -f "$fd_js" ]; then
            cp "$fd_wasm" "$app_dir/Resources/wasm/"
            cp "$fd_js" "$app_dir/Resources/wasm/"
            info "✅ 复制 fd-host-web wasm + js glue (profile=$wasm_profile)"
            info "    wasm sha256: $(shasum -a 256 "$fd_wasm" | awk '{print $1}')"
            info "    js   sha256: $(shasum -a 256 "$fd_js" | awk '{print $1}')"
        else
            # 显式回退内置件, 非静默 (issue #206)
            local builtin_wasm="$app_dir/Resources/wasm/fd_host_web_bg.wasm"
            warn "⚠️  回退内置 fd-host-web wasm (无新 bindgen 产物)"
            if [ -f "$builtin_wasm" ]; then
                warn "    builtin wasm sha256: $(shasum -a 256 "$builtin_wasm" | awk '{print $1}')"
                warn "    ⚠️  前端跑的是内置旧版, 可能与 fd-cli Rust crate 版本错配"
            fi
        fi
    else
        warn "fusion-design 源码未找到, 跳过 CLI + wasm 构建"
    fi

    info "✅ App Bundle 打包完成: $APP_BUNDLE"
}

# ─── 阶段 4: 签名 ─────────────────────────────────────────────

sign_app() {
    step "签名 App"

    local dev_id="${1:-}"
    if [ -z "$dev_id" ]; then
        # 尝试自动查找开发者证书
        dev_id=$(security find-identity -v -p basic 2>/dev/null | grep "Developer ID Application" | head -1 | awk '{print $2}' || echo "")
        if [ -z "$dev_id" ]; then
            warn "未找到开发者证书，跳过签名"
            return 0
        fi
        info "自动使用证书: $dev_id"
    fi

    local entitlements="$PROJECT_DIR/FusionStudio/Resources/Entitlements.plist"
    if [ -f "$entitlements" ]; then
        codesign --force --options runtime \
            --sign "$dev_id" \
            --deep \
            --entitlements "$entitlements" \
            "$APP_BUNDLE" 2>&1
    else
        codesign --force --options runtime \
            --sign "$dev_id" \
            --deep \
            "$APP_BUNDLE" 2>&1
    fi

    # 验证签名
    codesign -dvvv "$APP_BUNDLE" 2>&1 | head -5
    spctl -a -t exec -vv "$APP_BUNDLE" 2>&1 || warn "签名验证未通过（开发环境可忽略）"
    info "✅ 签名完成"
}

# ─── 阶段 5: 公证 ─────────────────────────────────────────────

notarize_app() {
    step "公证 App"

    local apple_id="${1:-}"
    local team_id="${2:-}"
    local password="${3:-}"

    if [ -z "$apple_id" ] || [ -z "$team_id" ]; then
        warn "跳过公证（需要 Apple ID 和 Team ID）"
        warn "用法: $0 notarize <apple-id> <team-id> [password]"
        return 0
    fi

    local dmg_path="$BUILD_DIR/FusionStudio-$VERSION-arm64.dmg"
    if [ ! -f "$dmg_path" ]; then
        create_dmg
    fi

    local pwd_arg="${password:-@keychain:AC_PASSWORD}"
    xcrun notarytool submit "$dmg_path" \
        --apple-id "$apple_id" \
        --team-id "$team_id" \
        --password "$pwd_arg" \
        --wait

    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler staple "$dmg_path"
    info "✅ 公证完成"
}

# ─── 阶段 6: 生成 DMG ─────────────────────────────────────────

create_dmg() {
    step "生成 DMG 安装包"

    local dmg_path="$BUILD_DIR/FusionStudio-$VERSION-arm64.dmg"
    local tmp_dir="$BUILD_DIR/dmg-tmp"
    mkdir -p "$tmp_dir"

    cp -R "$APP_BUNDLE" "$tmp_dir/"
    ln -s "/Applications" "$tmp_dir/Applications"

    # 显式指定镜像容量：hdiutil -srcfolder 自动估算偏小，曾导致
    # "No space left on device"（镜像内部空间不足）。按实际内容 MB * 1.5 + 256MB 余量。
    local content_mb
    content_mb=$(du -sm "$tmp_dir" 2>/dev/null | awk '{print $1}')
    local dmg_size=$(( content_mb * 3 / 2 + 256 ))
    info "DMG 内容 ${content_mb}MB → 镜像容量 ${dmg_size}MB"

    # 创建 DMG
    hdiutil create -volname "Fusion Studio $VERSION" \
        -srcfolder "$tmp_dir" \
        -ov -format UDZO \
        -imagekey zlib-level=9 \
        -size "${dmg_size}m" \
        "$dmg_path" 2>&1 | tail -3

    rm -rf "$tmp_dir"
    info "✅ DMG 生成完成: $dmg_path"
}

# ─── 主流程 ───────────────────────────────────────────────────

main() {
    local action="${1:-all}"

    case "$action" in
        services)
            build_services
            ;;
        app)
            build_app
            ;;
        package)
            build_services
            build_app
            package_app
            ;;
        sign)
            shift
            sign_app "$@"
            ;;
        notarize)
            shift
            notarize_app "$@"
            ;;
        dmg)
            create_dmg
            ;;
        all)
            build_services
            build_app
            package_app
            sign_app
            create_dmg
            info "🎉 Fusion Studio 构建完成！"
            info "App: $APP_BUNDLE"
            info "DMG: $BUILD_DIR/FusionStudio-$VERSION-arm64.dmg"
            ;;
        clean)
            step "清理构建产物"
            rm -rf "$BUILD_DIR" 2>/dev/null || true
            (cd "$PROJECT_DIR" && swift package clean 2>/dev/null) || true
            info "✅ 清理完成"
            ;;
        *)
            echo "Fusion Studio 构建脚本 v$VERSION"
            echo ""
            echo "用法: $0 {all|services|app|package|sign|notarize|dmg|clean}"
            echo ""
            echo "  all        完整构建（services + app + package + sign + dmg）"
            echo "  services   仅构建 Rust 后台服务"
            echo "  app        仅构建 SwiftUI App"
            echo "  package    构建全部并打包 .app"
            echo "  sign       签名 App"
            echo "  notarize   公证 App（需 Apple ID 参数）"
            echo "  dmg        生成 DMG 安装包"
            echo "  clean      清理构建产物"
            echo ""
            echo "环境变量:"
            echo "  CONFIGURATION  debug|release (默认: release)"
            exit 1
            ;;
    esac
}

main "$@"