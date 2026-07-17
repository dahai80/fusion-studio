#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 构建脚本
# 构建全部组件: SwiftUI App + Rust 后台服务 + Python 服务
# ──────────────────────────────────────────────────────────────

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Fusion Studio"
APP_BUNDLE="$BUILD_dir/$APP_NAME.app"

echo "=== Fusion Studio 构建脚本 ==="
echo "项目目录: $PROJECT_DIR"
echo ""

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── 阶段 1: 构建 Rust 后台服务 ────────────────────────────────

build_services() {
    info "=== 构建 Rust 后台服务 ==="

    local services=("env-daemon" "supervisor")

    for svc in "${services[@]}"; do
        local svc_dir="$PROJECT_DIR/Services/$svc"
        if [ -f "$svc_dir/Cargo.toml" ]; then
            info "构建 $svc..."
            (cd "$svc_dir" && cargo build --release 2>&1 | tail -3)
            info "✅ $svc 构建完成"
        else
            warn "跳转 $svc（无 Cargo.toml）"
        fi
    done
}

# ─── 阶段 2: 构建 SwiftUI App ─────────────────────────────────

build_app() {
    info "=== 构建 Fusion Studio App ==="

    # 方式 1: swift build (SPM)
    if [ -f "$PROJECT_DIR/Package.swift" ]; then
        info "使用 Swift Package Manager 构建..."
        (cd "$PROJECT_DIR" && swift build -c release 2>&1 | tail -5)
        info "✅ SPM 构建完成"
    fi

    # 方式 2: xcodebuild (如果有 .xcodeproj)
    if [ -d "$PROJECT_DIR/FusionStudio.xcodeproj" ]; then
        info "使用 Xcode 构建..."
        xcodebuild \
            -project "$PROJECT_DIR/FusionStudio.xcodeproj" \
            -scheme "FusionStudio" \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR/DerivedData" \
            build 2>&1 | tail -5
        info "✅ Xcode 构建完成"
    fi
}

# ─── 阶段 3: 打包 .app Bundle ─────────────────────────────────

package_app() {
    info "=== 打包 Fusion Studio.app ==="

    local app_dir="$BUILD_DIR/$APP_NAME.app/Contents"
    mkdir -p "$app_dir/MacOS"
    mkdir -p "$app_dir/Resources"
    mkdir -p "$app_dir/Frameworks"
    mkdir -p "$app_dir/Services"

    # 复制可执行文件
    local binary_path=$(swift build -c release --show-bin-path 2>/dev/null || echo "")
    if [ -n "$binary_path" ] && [ -f "$binary_path/FusionStudio" ]; then
        cp "$binary_path/FusionStudio" "$app_dir/MacOS/"
        info "✅ 复制 App 二进制"
    fi

    # 复制 Info.plist
    if [ -f "$PROJECT_DIR/FusionStudio/Resources/Info.plist" ]; then
        cp "$PROJECT_DIR/FusionStudio/Resources/Info.plist" "$app_dir/"
    else
        generate_info_plist "$app_dir"
    fi

    # 复制后台服务
    for svc in env-daemon supervisor; do
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

    # 复制资源文件
    cp -r "$PROJECT_DIR/FusionStudio/Resources/"* "$app_dir/Resources/" 2>/dev/null || true

    info "✅ App Bundle 打包完成: $BUILD_DIR/$APP_NAME.app"
}

# ─── 生成 Info.plist ──────────────────────────────────────────

generate_info_plist() {
    local app_dir="$1"
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
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST
    info "✅ 生成 Info.plist"
}

# ─── 阶段 4: 签名 ─────────────────────────────────────────────

sign_app() {
    info "=== 签名 App ==="

    local dev_id=${1:-"Apple Development"}

    codesign --force --options runtime \
        --sign "$dev_id" \
        "$BUILD_DIR/$APP_NAME.app" 2>&1

    info "✅ 签名完成"
}

# ─── 阶段 5: 生成 DMG ─────────────────────────────────────────

create_dmg() {
    info "=== 生成 DMG 安装包 ==="

    local dmg_path="$BUILD_DIR/FusionStudio-0.1.0-arm64.dmg"
    local tmp_dir="$BUILD_DIR/dmg-tmp"
    mkdir -p "$tmp_dir"

    cp -R "$BUILD_DIR/$APP_NAME.app" "$tmp_dir/"
    ln -s "/Applications" "$tmp_dir/Applications"

    # 创建 DMG
    hdiutil create -volname "Fusion Studio" \
        -srcfolder "$tmp_dir" \
        -ov -format UDZO \
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
            info "App: $BUILD_DIR/$APP_NAME.app"
            info "DMG: $BUILD_DIR/FusionStudio-0.1.0-arm64.dmg"
            ;;
        clean)
            info "清理构建产物..."
            rm -rf "$BUILD_DIR"
            for svc in env-daemon supervisor; do
                (cd "$PROJECT_DIR/Services/$svc" && cargo clean 2>/dev/null) || true
            done
            swift package clean 2>/dev/null || true
            info "✅ 清理完成"
            ;;
        *)
            echo "用法: $0 {all|services|app|package|sign|dmg|clean}"
            echo ""
            echo "  all       完整构建（services + app + package + sign + dmg）"
            echo "  services  仅构建 Rust 后台服务"
            echo "  app       仅构建 SwiftUI App"
            echo "  package   打包 .app Bundle"
            echo "  sign      签名 App"
            echo "  dmg       生成 DMG 安装包"
            echo "  clean     清理构建产物"
            exit 1
            ;;
    esac
}

main "$@"