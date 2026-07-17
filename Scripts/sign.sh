#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Fusion Studio 代码签名脚本
# 签名 .app 并公证
# ──────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Fusion Studio"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# Apple Developer ID 证书名称（需要替换为实际证书）
DEV_ID=${1:-"Developer ID Application: Your Name (TEAMID)"}

echo "=== Fusion Studio 签名 & 公证 ==="

# 1. 签名 .app
echo "签名 App..."
codesign --force --options runtime \
    --sign "$DEV_ID" \
    --deep \
    --entitlements "$PROJECT_DIR/FusionStudio/Resources/Entitlements.plist" \
    "$APP_PATH"

# 2. 验证签名
echo "验证签名..."
codesign -dvvv "$APP_PATH"
spctl -a -t exec -vv "$APP_PATH"

# 3. 打包为 .dmg
echo "创建 DMG..."
DMG_PATH="$BUILD_DIR/FusionStudio-0.1.0-arm64.dmg"
hdiutil create -volname "Fusion Studio" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

# 4. 公证（需要 Apple ID）
# xcrun notarytool submit "$DMG_PATH" \
#     --apple-id "your@email.com" \
#     --team-id "TEAMID" \
#     --password "@keychain:AC_PASSWORD" \
#     --wait

# 5. 盖章
# xcrun stapler staple "$APP_PATH"

echo "✅ 签名完成"
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"