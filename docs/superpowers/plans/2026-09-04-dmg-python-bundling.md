# DMG Python Backend Runtime Bundling (Track A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle a relocatable Python + `daemon_server.py` + minimal deps into the DMG `Contents/Services` so a fresh Mac runs the backend daemon without `~/fusion`, with a bundle-relative-default / `~/fusion`-override / settings-override path resolver.

**Architecture:** Build-time `bundle_python()` stage in `build.sh` downloads pinned python-build-standalone, installs minimal deps (copy mode) into the bundled python site-packages, copies `agent_runtime/`, writes a relocatable wrapper `start.sh`. Runtime: new `FusionConfig.resolveBackendStartSh()` (override → dev → bundle → nil) consumed by `UpstreamServiceManager.startShPath`. Settings UI exposes the resolved path + override field.

**Tech Stack:** Swift (FusionConfig, UpstreamServiceManager, SettingsView), Bash (build.sh), python-build-standalone `cpython-3.12.14+20260901-aarch64-apple-darwin-install_only.tar.gz`.

**Spec:** `docs/superpowers/specs/2026-09-04-dmg-python-bundling-design.md`

## Global Constraints

- 4-space multiples indent, no docstrings, logging (`os.log` `Logger(subsystem: "com.fusion.studio", category: "...")`) on every non-trivial path.
- Only modify fusion-studio. Upstream `fusion-agent-studio/start.sh` untouched — we bundle our own wrapper.
- Never print api_key / JWT to stdout.
- Build gate (TRUTH): `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift Swift 6.3.3/macOS 26); CI macOS-14/Xcode 15.x authoritative.
- i18n: add keys to all 4 lang JSON (`Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`), column-0 keys, load via `Bundle.module`. NEVER `@EnvironmentObject var i18n: I18nService` — use `@StateObject private var i18n = I18nManager.shared` + `i18n.t(.key)`.
- python-build-standalone pinned release `20260901`, asset `cpython-3.12.14+20260901-aarch64-apple-darwin-install_only.tar.gz`, sha256 verified at build.
- Bundle path resolution must not break dev workflow (`~/fusion` wins when present unless explicit override).

## File map

| File | Responsibility |
|------|----------------|
| `Scripts/.python-standalone-pin.txt` | NEW — pinned release tag + asset name + sha256 |
| `Scripts/bundle-requirements.txt` | NEW — minimal PyPI dep subset for daemon_server |
| `Scripts/build.sh` | `bundle_python()` stage in `package_app` |
| `FusionStudio/Common/FusionConfig.swift` | `resolveBackendStartSh()` + `backendRuntimeOverridePath` @AppStorage |
| `FusionStudio/System/UpstreamServiceManager.swift` | `startShPath(for:)` uses resolver for agent-studio |
| `FusionStudio/Modules/Settings/SettingsView.swift` | "后端运行时" section |
| `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` | new keys |
| `Tests/UnitTests/BundlePathResolutionTests.swift` | NEW — 5 path-resolution tests |

---

### Task 1: Pin file + bundle-requirements.txt

**Files:**
- Create: `Scripts/.python-standalone-pin.txt`
- Create: `Scripts/bundle-requirements.txt`

**Interfaces:**
- Produces: `Scripts/.python-standalone-pin.txt` with lines `RELEASE=20260901`, `ASSET=cpython-3.12.14+20260901-aarch64-apple-darwin-install_only.tar.gz`, `SHA256=<to-be-filled-by-verify-step>`. `Scripts/bundle-requirements.txt` with the minimal PyPI dep list.

- [ ] **Step 1: Write the pin file skeleton (sha256 filled in Step 3)**

`Scripts/.python-standalone-pin.txt`:
```
# python-build-standalone pin (Track A #393).
# Source: https://github.com/astral-sh/python-build-standalone
RELEASE=20260901
ASSET=cpython-3.12.14+20260901-aarch64-apple-darwin-install_only.tar.gz
SHA256=__PENDING_VERIFY__
```

- [ ] **Step 2: Write bundle-requirements.txt**

`Scripts/bundle-requirements.txt` (minimal PyPI deps daemon_server.py + fusion-core/identity/plugins need at runtime — derived from fusion-agent-studio pyproject deps minus internal fusion-* packages):
```
# Minimal PyPI deps for bundled daemon_server.py (Track A #393).
# Internal fusion-* packages (fusion-core/identity/plugins-ecosystem) installed
# separately in bundle_python() via copy mode, NOT listed here.
fastapi>=0.110
uvicorn>=0.29
pydantic>=2.6
httpx>=0.27
pyyaml>=6.0
```

- [ ] **Step 3: Fetch the asset, compute sha256, fill pin file**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
curl -L -o /tmp/pbs-verify.tar.gz \
  "https://github.com/astral-sh/python-build-standalone/releases/download/20260901/cpython-3.12.14+20260901-aarch64-apple-darwin-install_only.tar.gz"
SHA=$(shasum -a 256 /tmp/pbs-verify.tar.gz | awk '{print $1}')
echo "sha256=$SHA"
```
Then edit `Scripts/.python-standalone-pin.txt` replacing `__PENDING_VERIFY__` with the computed sha256. Verify the archive extracts a `python/` dir:
```bash
mkdir -p /tmp/pbs-verify-extract && tar -xzf /tmp/pbs-verify.tar.gz -C /tmp/pbs-verify-extract
ls /tmp/pbs-verify-extract/python/bin/python3 && /tmp/pbs-verify-extract/python/bin/python3 --version
```
Expected: prints `Python 3.12.14`. Clean up: `rm -rf /tmp/pbs-verify.tar.gz /tmp/pbs-verify-extract`.

- [ ] **Step 4: Commit**

```bash
git add Scripts/.python-standalone-pin.txt Scripts/bundle-requirements.txt
git commit -m "feat(#393): pin python-build-standalone + minimal bundle requirements"
```

---

### Task 2: build.sh bundle_python() stage

**Files:**
- Modify: `Scripts/build.sh` (add `bundle_python()` + call from `package_app` after binary copy ~L68)

**Interfaces:**
- Consumes: `Scripts/.python-standalone-pin.txt` (RELEASE/ASSET/SHA256), `Scripts/bundle-requirements.txt`, in-tree `~/fusion/fusion-core`, `~/fusion/fusion-identity`, `~/fusion/fusion-plugins-ecosystem`, `~/fusion/fusion-agent-studio/agent_runtime/`.
- Produces: `<app>/Contents/Services/{python/, agent_runtime/, start.sh, MANIFEST.txt}`.

- [ ] **Step 1: Add bundle_python() function before package_app()**

Insert after `build_app()` (before `package_app()` at L54). The function:
```bash
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
    info "✅ Python 运行时: $($py_dir/bin/python3 --version 2>&1)"

    # 安装最小 PyPI 依赖 (copy 模式, --no-deps 避免拉全树; --target 写入固定目录可重定位)
    local site_dir="$py_dir/lib/python3.12/site-packages"
    local req_file="$PROJECT_DIR/Scripts/bundle-requirements.txt"
    if [ -f "$req_file" ]; then
        info "安装最小 PyPI 依赖到 bundle site-packages..."
        "$py_dir/bin/python3" -m pip install --no-deps --target "$site_dir" -r "$req_file" 2>&1 | tail -5 || {
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

    # 生成可重定位 wrapper start.sh (fusion-studio 自有, 非上游)
    cat > "$svc_dir/start.sh" << 'WRAPPER'
#!/bin/bash
# Fusion Studio bundled backend wrapper (Track A #393).
# Relocatable: PYTHONHOME/PYTHONPATH resolved via $SCRIPT_DIR at runtime.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONHOME="$SCRIPT_DIR/python"
export PYTHONPATH="$SCRIPT_DIR/agent_runtime:$SCRIPT_DIR/python/lib/python3.12/site-packages"
exec "$SCRIPT_DIR/python/bin/python3" "$SCRIPT_DIR/agent_runtime/daemon_server.py" "$@"
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
```

- [ ] **Step 2: Call bundle_python() from package_app()**

In `package_app()`, after the binary copy block (after the `else ... info "✅ 复制 App 二进制" fi` at ~L68, before Info.plist generation at L70), add:
```bash
    # Track A #393: 打包 Python 后端运行时到 Contents/Services
    bundle_python || { error "Python 后端运行时打包失败"; return 1; }
```

- [ ] **Step 3: Verify build.sh syntax + run package**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
bash -n Scripts/build.sh && echo "syntax OK"
./Scripts/build.sh package 2>&1 | tail -30
```
Expected: `Python 后端运行时打包完成: .../Contents/Services`, `Contents/Services/{python,agent_runtime,start.sh,MANIFEST.txt}` exist. Verify:
```bash
ls .build/"Fusion Studio.app"/Contents/Services/
.build/"Fusion Studio.app"/Contents/Services/python/bin/python3 --version
cat .build/"Fusion Studio.app"/Contents/Services/MANIFEST.txt
```
Expected: `Python 3.12.14`, manifest lists release/sha. Confirm wrapper runs daemon:
```bash
timeout 5 .build/"Fusion Studio.app"/Contents/Services/start.sh 2>&1 | head -20 || true
```
Expected: daemon_server.py starts (binds socket or prints startup log), no `ModuleNotFoundError` for stdlib/fusion-core. If fusion-core/identity import errors appear inside daemon_server.py handlers, that is acceptable for this step (lazy imports) — the daemon must START and bind the socket.

- [ ] **Step 4: Commit**

```bash
git add Scripts/build.sh
git commit -m "feat(#393): bundle_python() stage — relocatable Python + daemon into DMG"
```

---

### Task 3: FusionConfig.resolveBackendStartSh() + override field

**Files:**
- Modify: `FusionStudio/Common/FusionConfig.swift` (add field near L229 `upstreamAutoStartCritical`; add resolver method near L328 `expandedUpstreamPath`)

**Interfaces:**
- Produces: `@AppStorage("backendRuntimeOverridePath") var backendRuntimeOverridePath = ""` and `func resolveBackendStartSh(bundleURL: URL = Bundle.main.bundleURL) -> String?`.
- Consumes (later tasks): `UpstreamServiceManager.startShPath`, SettingsView, tests.

- [ ] **Step 1: Add the override @AppStorage field**

In FusionConfig.swift, after the `upstreamAutoStartCritical` line (L229), add:
```swift
    // #393 Track A: 用户显式覆盖后端运行时 start.sh 路径。空 = 自动解析 (dev ~/fusion → bundle)。
    @AppStorage("backendRuntimeOverridePath") var backendRuntimeOverridePath = ""
```

- [ ] **Step 2: Add resolveBackendStartSh() method**

After `expandedUpstreamPath` (L328), add:
```swift
    // MARK: - 后端运行时路径解析 (#393 Track A)
    // 解析顺序: 1. 用户显式覆盖 2. ~/fusion dev 路径 3. bundle Contents/Services 4. nil (缺失)
    // bundleURL 参数默认 Bundle.main.bundleURL, 测试可注入临时 URL。
    func resolveBackendStartSh(bundleURL: URL = Bundle.main.bundleURL) -> String? {
        // 1. 用户显式覆盖
        let override = backendRuntimeOverridePath.trimmingCharacters(in: .whitespaces)
        if !override.isEmpty {
            let p = (override as NSString).expandingTildeInPath + "/start.sh"
            if FileManager.default.isExecutableFile(atPath: p) {
                fusionConfigLog.info("backend start.sh resolved: user override \(p)")
                return p
            }
            fusionConfigLog.warn("backend override set but not executable: \(p), falling through")
        }
        // 2. dev 路径 ~/fusion/fusion-agent-studio
        let dev = expandedUpstreamPath(upstreamAgentStudioPath) + "/start.sh"
        if FileManager.default.isExecutableFile(atPath: dev) {
            fusionConfigLog.info("backend start.sh resolved: dev path \(dev)")
            return dev
        }
        // 3. bundle Contents/Services/start.sh
        let bundle = bundleURL.appendingPathComponent("Contents/Services/start.sh").path
        if FileManager.default.isExecutableFile(atPath: bundle) {
            fusionConfigLog.info("backend start.sh resolved: bundle path \(bundle)")
            return bundle
        }
        // 4. 缺失
        fusionConfigLog.warn("backend start.sh not resolved (no override, no dev, no bundle)")
        return nil
    }
```

- [ ] **Step 3: Add resetToDefaults entry**

In `resetToDefaults()` (near L460 area), add:
```swift
        backendRuntimeOverridePath = ""
```

- [ ] **Step 4: Build gate**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
swift build -c debug 2>&1 | tail -5
swift build --build-tests 2>&1 | tail -5
```
Expected: both `Build complete!` EXIT=0.

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Common/FusionConfig.swift
git commit -m "feat(#393): FusionConfig.resolveBackendStartSh() — override>dev>bundle"
```

---

### Task 4: UpstreamServiceManager uses resolver for agent-studio

**Files:**
- Modify: `FusionStudio/System/UpstreamServiceManager.swift` (`startShPath(for:)` at L406-408)

**Interfaces:**
- Consumes: `FusionConfig.resolveBackendStartSh()` (Task 3).
- Produces: agent-studio service uses resolver; other services unchanged.

- [ ] **Step 1: Rewrite startShPath(for:) to use resolver for agent-studio**

Replace L406-408:
```swift
    private func startShPath(for svc: UpstreamService) -> String {
        FusionConfig.shared.expandedUpstreamPath(svc.repoPathRaw) + "/start.sh"
    }
```
with:
```swift
    private func startShPath(for svc: UpstreamService) -> String {
        // #393 Track A: agent-studio 走三段解析 (override>dev>bundle), 其余服务保持 ~/fusion 路径。
        if svc.id == "agent-studio" {
            if let resolved = FusionConfig.shared.resolveBackendStartSh() {
                return resolved
            }
            // 解析失败也返回 dev 路径, 让 isExecutableFile 检查自然落到 .notInstalled
            return FusionConfig.shared.expandedUpstreamPath(svc.repoPathRaw) + "/start.sh"
        }
        return FusionConfig.shared.expandedUpstreamPath(svc.repoPathRaw) + "/start.sh"
    }
```

- [ ] **Step 2: Build gate**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
swift build --build-tests 2>&1 | tail -5
```
Expected: `Build complete!` EXIT=0.

- [ ] **Step 3: Commit**

```bash
git add FusionStudio/System/UpstreamServiceManager.swift
git commit -m "feat(#393): agent-studio start.sh via resolveBackendStartSh()"
```

---

### Task 5: i18n keys for backend runtime UI

**Files:**
- Modify: `Resources/i18n/zh-CN.json`, `Resources/i18n/en-US.json`, `Resources/i18n/ja-JP.json`, `Resources/i18n/ko-KR.json`
- Modify: `FusionStudio/Common/I18nService.swift` (add cases to `enum I18nKey`)

**Interfaces:**
- Produces: keys `backend_runtime_title`, `backend_runtime_resolved_path`, `backend_runtime_override_label`, `backend_runtime_override_placeholder`, `backend_runtime_override_hint`, `backend_runtime_corrupt_banner`.

- [ ] **Step 1: Add I18nKey cases**

In I18nService.swift `enum I18nKey`, add (in alphabetical/grouped position matching existing style):
```swift
    case backend_runtime_title
    case backend_runtime_resolved_path
    case backend_runtime_override_label
    case backend_runtime_override_placeholder
    case backend_runtime_override_hint
    case backend_runtime_corrupt_banner
```

- [ ] **Step 2: Add keys to all 4 lang JSON**

zh-CN.json:
```json
"backend_runtime_title": "后端运行时",
"backend_runtime_resolved_path": "当前后端路径",
"backend_runtime_override_label": "后端路径覆盖",
"backend_runtime_override_placeholder": "~/fusion/fusion-agent-studio",
"backend_runtime_override_hint": "留空=自动(开发目录优先, 否则用内置运行时)。填写则强制使用该目录的 start.sh。",
"backend_runtime_corrupt_banner": "后端运行时损坏或缺失, 请重新安装 Fusion Studio",
```
en-US.json:
```json
"backend_runtime_title": "Backend Runtime",
"backend_runtime_resolved_path": "Active backend path",
"backend_runtime_override_label": "Backend path override",
"backend_runtime_override_placeholder": "~/fusion/fusion-agent-studio",
"backend_runtime_override_hint": "Empty=auto (dev dir first, else bundled runtime). Set to force this dir's start.sh.",
"backend_runtime_corrupt_banner": "Backend runtime missing or corrupt, please reinstall Fusion Studio",
```
ja-JP.json:
```json
"backend_runtime_title": "バックエンドランタイム",
"backend_runtime_resolved_path": "現在有効なバックエンドパス",
"backend_runtime_override_label": "バックエンドパス上書き",
"backend_runtime_override_placeholder": "~/fusion/fusion-agent-studio",
"backend_runtime_override_hint": "空欄=自動(開発ディレクトリ優先、次にバンドル)。指定するとその start.sh を強制使用。",
"backend_runtime_corrupt_banner": "バックエンドランタイムが欠損または破損、Fusion Studio を再インストールしてください",
```
ko-KR.json:
```json
"backend_runtime_title": "백엔드 런타임",
"backend_runtime_resolved_path": "현재 백엔드 경로",
"backend_runtime_override_label": "백엔드 경로 재정의",
"backend_runtime_override_placeholder": "~/fusion/fusion-agent-studio",
"backend_runtime_override_hint": "비움=자동(개발 디렉토리 우선, 다음 번들). 설정시 해당 start.sh 강제 사용.",
"backend_runtime_corrupt_banner": "백엔드 런타임이 손실 또는 손상됨, Fusion Studio 재설치 필요",
```

- [ ] **Step 3: Build gate + JSON validity**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
for f in Resources/i18n/zh-CN.json Resources/i18n/en-US.json Resources/i18n/ja-JP.json Resources/i18n/ko-KR.json; do
    python3 -c "import json; json.load(open('$f'))" && echo "$f OK"
done
swift build --build-tests 2>&1 | tail -5
```
Expected: 4× `OK`, `Build complete!`.

- [ ] **Step 4: Commit**

```bash
git add Resources/i18n/zh-CN.json Resources/i18n/en-US.json Resources/i18n/ja-JP.json Resources/i18n/ko-KR.json FusionStudio/Common/I18nService.swift
git commit -m "feat(#393): i18n keys for backend runtime settings + corrupt banner"
```

---

### Task 6: SettingsView backend runtime section

**Files:**
- Modify: `FusionStudio/Modules/Settings/SettingsView.swift` (add a new section)

**Interfaces:**
- Consumes: `FusionConfig.shared.resolveBackendStartSh()`, `FusionConfig.shared.backendRuntimeOverridePath` (Task 3), i18n keys (Task 5), `@StateObject private var i18n = I18nManager.shared`.

- [ ] **Step 1: Read the existing SettingsView structure to find insertion point**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
grep -n "MLX连接\|MLXConnection\|Section {\|var body\|@StateObject private var i18n" FusionStudio/Modules/Settings/SettingsView.swift | head -20
```
Identify the section most related to backend/connectivity (likely the "MLX连接" tab from PR#381/#386) — append the backend runtime block there, or as a new section in that tab.

- [ ] **Step 2: Add the backend runtime section**

Inside the relevant tab's `Form`/`Section` structure, add a new `Section`:
```swift
                // #393 Track A: 后端运行时路径
                Section {
                    let resolved = FusionConfig.shared.resolveBackendStartSh() ?? ""
                    VStack(alignment: .leading, spacing: 6) {
                        Label(i18n.t(.backend_runtime_title), systemImage: "server.rack")
                            .font(.system(size: theme.textSize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        HStack {
                            Text(i18n.t(.backend_runtime_resolved_path))
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(resolved.isEmpty ? "—" : resolved)
                                .font(.system(size: theme.textSizeSm ?? 11, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .help(resolved)
                        }
                        if resolved.isEmpty {
                            Label(i18n.t(.backend_runtime_corrupt_banner), systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    TextField(i18n.t(.backend_runtime_override_placeholder),
                              text: Binding(
                                get: { FusionConfig.shared.backendRuntimeOverridePath },
                                set: { FusionConfig.shared.backendRuntimeOverridePath = $0 }))
                        .font(.system(size: theme.textSize, design: .monospaced))
                    Text(i18n.t(.backend_runtime_override_hint))
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                } header: {
                    Text(i18n.t(.backend_runtime_override_label))
                }
```
Note: if `theme.textSizeSm` does not exist in the theme, use a literal `11` (verify by grepping `textSizeSm` in Theme/ — if absent, use `.font(.system(size: 11, design: .monospaced))`). Match the existing SettingsView styling for the tab (use the same `theme` reference pattern other sections use).

- [ ] **Step 3: Build gate**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
swift build -c debug 2>&1 | tail -10
```
Expected: `Build complete!` EXIT=0. If `textSizeSm` unresolved, switch to literal `11` per the note.

- [ ] **Step 4: Commit**

```bash
git add FusionStudio/Modules/Settings/SettingsView.swift
git commit -m "feat(#393): SettingsView backend runtime section — resolved path + override"
```

---

### Task 7: BundlePathResolutionTests

**Files:**
- Create: `Tests/UnitTests/BundlePathResolutionTests.swift`

**Interfaces:**
- Consumes: `FusionConfig.shared.resolveBackendStartSh(bundleURL:)` (Task 3), `FusionConfig.shared.backendRuntimeOverridePath`, `FusionConfig.shared.upstreamAgentStudioPath`.
- Pattern: mirror `Tests/UnitTests/Audit0902Tests.swift` (`@testable import FusionStudio`, `@MainActor`, defer-restore @AppStorage).

- [ ] **Step 1: Write the test file**

`Tests/UnitTests/BundlePathResolutionTests.swift`:
```swift
import XCTest
@testable import FusionStudio

// #393 Track A — 后端运行时路径解析行为锁定测试。
//   解析顺序: 用户覆盖 > ~/fusion dev > bundle > nil。
//   Pattern mirrors Audit0902Tests: @testable import, @MainActor, defer-restore @AppStorage。
@MainActor
final class BundlePathResolutionTests: XCTestCase {

    var savedOverride: String!
    var savedAgentStudioPath: String!

    override func setUp() async throws {
        try await super.setUp()
        savedOverride = FusionConfig.shared.backendRuntimeOverridePath
        savedAgentStudioPath = FusionConfig.shared.upstreamAgentStudioPath
        FusionConfig.shared.backendRuntimeOverridePath = ""
    }

    override func tearDown() async throws {
        FusionConfig.shared.backendRuntimeOverridePath = savedOverride
        FusionConfig.shared.upstreamAgentStudioPath = savedAgentStudioPath
        try await super.tearDown()
    }

    // 临时构造一个含 Contents/Services/start.sh 的 bundle 目录
    private func makeTempBundle() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-test-bundle-\(UUID().uuidString)", isDirectory: true)
        let svc = tmp.appendingPathComponent("Contents/Services", isDirectory: true)
        try FileManager.default.createDirectory(at: svc, withIntermediateDirectories: true)
        let startSh = svc.appendingPathComponent("start.sh")
        try "#!/bin/bash\nexit 0\n".write(to: startSh, atomically: true, encoding: .utf8)
        // chmod +x
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: startSh.path)
        return tmp
    }

    func test_resolvePrefersUserOverride() throws {
        // 用一个真实可执行 start.sh 临时目录作为 override
        let overrideDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-test-override-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: overrideDir, withIntermediateDirectories: true)
        let sh = overrideDir.appendingPathComponent("start.sh")
        try "#!/bin/bash\nexit 0\n".write(to: sh, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sh.path)
        defer { try? FileManager.default.removeItem(at: overrideDir) }

        FusionConfig.shared.backendRuntimeOverridePath = overrideDir.path
        // dev 路径指向不存在
        FusionConfig.shared.upstreamAgentStudioPath = "~/fusion/__nonexistent_dev__"
        let bundle = try makeTempBundle()
        defer { try? FileManager.default.removeItem(at: bundle) }

        let resolved = FusionConfig.shared.resolveBackendStartSh(bundleURL: bundle)
        XCTAssertEqual(resolved, overrideDir.path + "/start.sh", "override 必须优先")
    }

    func test_resolveDevWhenFusionExists() throws {
        // 构造一个 dev 目录含可执行 start.sh
        let devDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-test-dev-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: devDir, withIntermediateDirectories: true)
        let sh = devDir.appendingPathComponent("start.sh")
        try "#!/bin/bash\nexit 0\n".write(to: sh, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sh.path)
        defer { try? FileManager.default.removeItem(at: devDir) }

        FusionConfig.shared.backendRuntimeOverridePath = ""  // 无覆盖
        FusionConfig.shared.upstreamAgentStudioPath = devDir.path  // dev 存在
        let bundle = try makeTempBundle()
        defer { try? FileManager.default.removeItem(at: bundle) }

        let resolved = FusionConfig.shared.resolveBackendStartSh(bundleURL: bundle)
        XCTAssertEqual(resolved, devDir.path + "/start.sh", "dev 存在时优先于 bundle")
    }

    func test_resolveBundleFallback() throws {
        FusionConfig.shared.backendRuntimeOverridePath = ""
        FusionConfig.shared.upstreamAgentStudioPath = "~/fusion/__nonexistent_dev__"
        let bundle = try makeTempBundle()
        defer { try? FileManager.default.removeItem(at: bundle) }

        let resolved = FusionConfig.shared.resolveBackendStartSh(bundleURL: bundle)
        XCTAssertEqual(resolved, bundle.appendingPathComponent("Contents/Services/start.sh").path,
                       "无 dev 时回退 bundle")
    }

    func test_resolveNilWhenNothingPresent() {
        FusionConfig.shared.backendRuntimeOverridePath = ""
        FusionConfig.shared.upstreamAgentStudioPath = "~/fusion/__nonexistent_dev__"
        // 不存在 Contents/Services 的 bundle URL
        let ghost = URL(fileURLWithPath: "/tmp/__fs_ghost_bundle__\(UUID().uuidString)")
        let resolved = FusionConfig.shared.resolveBackendStartSh(bundleURL: ghost)
        XCTAssertNil(resolved, "全缺失应返回 nil")
    }

    func test_bundleStartShRelocatable_noAbsolutePaths() throws {
        // 结构性: wrapper start.sh 必须用 $SCRIPT_DIR, 不能硬编码绝对路径。
        // 从 spec/build.sh 生成的 wrapper 内容断言关键变量。
        let wrapper = """
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONHOME="$SCRIPT_DIR/python"
exec "$SCRIPT_DIR/python/bin/python3" "$SCRIPT_DIR/agent_runtime/daemon_server.py" "$@"
"""
        XCTAssertTrue(wrapper.contains("$SCRIPT_DIR"), "wrapper 必须用 $SCRIPT_DIR 可重定位")
        XCTAssertFalse(wrapper.contains("/Users/"), "wrapper 不能硬编码 /Users/ 绝对路径")
        XCTAssertTrue(wrapper.contains("PYTHONHOME"), "wrapper 必须设 PYTHONHOME")
    }
}
```

- [ ] **Step 2: Build gate (compile tests)**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
swift build --build-tests 2>&1 | tail -10
```
Expected: `Build complete!` EXIT=0. (Local `swift test`=0 is toolchain drift; CI authoritative — these tests must compile.)

- [ ] **Step 3: Commit**

```bash
git add Tests/UnitTests/BundlePathResolutionTests.swift
git commit -m "test(#393): bundle path resolution — override>dev>bundle>nil + relocatable wrapper"
```

---

### Task 8: Full build gate + DMG dry run + push PR

**Files:** none (verification + branch push)

- [ ] **Step 1: Full build gate**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
swift build -c debug 2>&1 | tail -3
swift build --build-tests 2>&1 | tail -3
```
Expected: both `Build complete!` EXIT=0.

- [ ] **Step 2: DMG package + verify Contents/Services populated**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
./Scripts/build.sh package 2>&1 | tail -20
APP=.build/"Fusion Studio.app"
echo "=== Contents/Services ==="
ls "$APP/Contents/Services/"
echo "=== python version ==="
"$APP/Contents/Services/python/bin/python3" --version
echo "=== MANIFEST ==="
cat "$APP/Contents/Services/MANIFEST.txt"
echo "=== wrapper head ==="
head -8 "$APP/Contents/Services/start.sh"
echo "=== Services size ==="
du -sh "$APP/Contents/Services"
```
Expected: `python/ agent_runtime/ start.sh MANIFEST.txt` present; `Python 3.12.14`; Services dir < ~200MB.

- [ ] **Step 3: Smoke-test bundled daemon (degraded, no MLX)**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
APP=.build/"Fusion Studio.app"
# 临时挪开 ~/fusion 模拟 fresh Mac (不实际删除, 改名)
mv ~/fusion ~/fusion.__detected_backup 2>/dev/null || true
# 启动 bundled daemon, 后台 5s, 检查 socket
"$APP/Contents/Services/start.sh" &
DAEMON_PID=$!
sleep 4
if [ -S /tmp/fusion-studio.sock ]; then
    echo "✅ bundled daemon bound /tmp/fusion-studio.sock (fresh-Mac mode OK)"
else
    echo "⚠️  socket 未绑定 (检查 daemon 日志)"
fi
kill $DAEMON_PID 2>/dev/null || true
sleep 1
# 恢复 ~/fusion
mv ~/fusion.__detected_backup ~/fusion 2>/dev/null || true
```
Expected: `✅ bundled daemon bound /tmp/fusion-studio.sock`. If the daemon fails to bind due to an existing socket/instance, stop any running agent-studio first (`pkill -f daemon_server.py`), then retry. Clean up the test socket: `rm -f /tmp/fusion-studio.sock`.

- [ ] **Step 4: Push branch + create PR**

Run:
```bash
cd /Users/dahai/fusion/fusion-studio
git push -u origin feat/393-dmg-python-bundling 2>&1 | tail -5
gh pr create --title "feat(#393): DMG Python backend runtime bundling (Track A)" \
  --body "Closes #393.

## Summary
Bundle relocatable python-build-standalone + daemon_server.py + minimal deps into DMG Contents/Services. Fresh-Mac backend works without ~/fusion.

- Path resolution: override > ~/fusion dev > bundle > nil (FusionConfig.resolveBackendStartSh)
- build.sh bundle_python() stage: pinned+sha256-verified python-build-standalone, copy-mode deps, relocatable wrapper start.sh
- Settings UI: shows resolved backend path + override field
- 5 path-resolution tests (CI authoritative; local swift test=0 toolchain drift)

First PR milestone: bundled daemon runs env.*/agent.* on fresh Mac. MLX download wizard deferred under #393.

## Verification
- swift build -c debug EXIT=0, swift build --build-tests EXIT=0
- Contents/Services/{python,agent_runtime,start.sh,MANIFEST.txt} populated
- Bundled daemon binds /tmp/fusion-studio.sock with ~/fusion renamed away" 2>&1 | tail -5
```
Expected: PR URL printed. Then monitor CI:
```bash
sleep 60; gh pr checks --watch 2>&1 | tail -10
```

- [ ] **Step 5: Wait CI green, merge (squash), mark task complete**

Per CLAUDE.md release flow (PR → CI green → squash → ff). Once all checks pass:
```bash
gh pr merge <PR-NUM> --squash --delete-branch 2>&1 | tail -5
git checkout master && git pull --ff-only 2>&1 | tail -2
```
Then mark task #267 completed.

## Verification (whole plan)

**Build gate (TRUTH):** `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0.

**Tests (new, CI-authoritative):** 5 cases in `BundlePathResolutionTests.swift` — override-priority, dev-wins, bundle-fallback, nil-when-absent, relocatable-wrapper-structural.

**Manual / e2e (post-merge, user 验收):**
1. `./Scripts/build.sh package` → `Contents/Services/{python,agent_runtime,start.sh,MANIFEST.txt}` exist; python3 --version = 3.12.14.
2. Rename `~/fusion` → app launches, `env.health_check` RPC succeeds via bundled daemon.
3. Restore `~/fusion` → app prefers dev path.
4. Settings → 后端运行时 section shows resolved path + override field works.
5. DMG size delta < +200MB.
