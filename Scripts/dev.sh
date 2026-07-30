#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> 清理编译产物..."
rm -rf .build/arm64-apple-macosx
rm -rf .build/debug
rm -rf .build/release
rm -rf ".build/Fusion Studio.app"

echo "==> 清理 DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FusionStudio-* 2>/dev/null || true

echo "==> 编译 debug..."
swift build -c debug 2>&1 | tail -3

echo "==> 杀旧进程..."
pkill -f "FusionStudio" 2>/dev/null || true
sleep 1

echo "==> 启动 FusionStudio..."
BIN=".build/arm64-apple-macosx/debug/FusionStudio"
if [ -f "$BIN" ]; then
    "$BIN" &
    echo "==> 已启动: $BIN (PID $!)"
else
    echo "ERROR: 二进制未找到: $BIN"
    exit 1
fi
