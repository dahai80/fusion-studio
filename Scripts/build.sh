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
VERSION="0.1.21"
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

    local services=("env-daemon")
    for svc in "${services[@]}"; do
        local svc_dir="$PROJECT_DIR/Services/$svc"
        if [ -f "$svc_dir/Cargo.toml" ]; then
            info "构建 $svc..."
            (cd "$svc_dir" && cargo build --release 2>&1 | tail -3)
            info "✅ $svc 构建完成"
        fi
    done
}

# ─── 阶段 2: 构建 SwiftUI App ─────────────────────────────────

build_app() {
    step "构建 Fusion Studio App"

    # 使用 Swift Package Manager 构建
    (cd "$PROJECT_DIR" && swift build -c $CONFIGURATION 2>&1 | tail -5)
    info "✅ SPM 构建完成"
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

    # 复制后台服务
    for svc in env-daemon; do
        local svc_bin="$PROJECT_DIR/Services/$svc/target/release/$svc"
        if [ -f "$svc_bin" ]; then
            cp "$svc_bin" "$app_dir/Services/"
            info "✅ 复制 $svc 服务"
        fi
    done

    # 复制 Python 服务
    local mlx_daemon="$PROJECT_DIR/Services/mlx-daemon/daemon.py"
    if [ -f "$mlx_daemon" ]; then
        cp "$mlx_daemon" "$app_dir/Services/"
        info "✅ 复制 mlx-daemon"
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
        # 更新 wasm
        local fd_wasm="$fd_dir/target/wasm32-unknown-unknown/release/fd_host_web_bg.wasm"
        if [ ! -f "$fd_wasm" ]; then
            fd_wasm="$fd_dir/target/wasm32-unknown-unknown/debug/fd_host_web_bg.wasm"
        fi
        if [ -f "$fd_wasm" ]; then
            cp "$fd_wasm" "$app_dir/Resources/wasm/"
            local fd_js="$fd_dir/target/wasm32-unknown-unknown/release/fd_host_web.js"
            [ ! -f "$fd_js" ] && fd_js="$fd_dir/target/wasm32-unknown-unknown/debug/fd_host_web.js"
            [ -f "$fd_js" ] && cp "$fd_js" "$app_dir/Resources/wasm/"
            info "✅ 复制 fd-host-web wasm + js glue"
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

    # 创建 DMG
    hdiutil create -volname "Fusion Studio $VERSION" \
        -srcfolder "$tmp_dir" \
        -ov -format UDZO \
        -imagekey zlib-level=9 \
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
            for svc in env-daemon; do
                (cd "$PROJECT_DIR/Services/$svc" && cargo clean 2>/dev/null) || true
            done
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