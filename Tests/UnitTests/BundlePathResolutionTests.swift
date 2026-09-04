import XCTest
@testable import FusionStudio

// #393 Track A — resolveBackendStartSh(bundleURL:) 路径解析行为锁定测试。
//   覆盖 (spec docs/superpowers/specs/2026-09-04-dmg-python-bundling-design.md):
//   T1 用户覆盖优先 (override set + 可执行 → 返回 override)
//   T2 dev 模式 (~/fusion start.sh 存在 → 返回 dev, 即便 bundle 也在)
//   T3 bundle 回退 (无 override 无 dev → 返回 bundle path)
//   T4 全无 → nil
//   T5 wrapper start.sh 结构可重定位 ($SCRIPT_DIR, PYTHONHOME)

@MainActor
final class BundlePathResolutionTests: XCTestCase {

    // 测试用的可执行文件: 写一个临时脚本 + chmod +x
    private func makeExecutable(_ path: String) {
        let parent = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: path, contents: Data("#!/bin/bash\necho ok\n".utf8))
        // 0755
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }

    // allowlist 仅允许 NSHomeDirectory() 或 bundleURL 前缀 (审计v0.1.58 P0-bundling-1).
    // CI 上 NSTemporaryDirectory()=/var/folders 不在 /Users/runner 下 → 会被拒.
    // 测试 fixture 必须落在 home 下, 与生产 allowlist 契约一致 (非放宽安全).
    private func homeTmpDir(_ label: String) -> String {
        let home = NSHomeDirectory()
        let dir = (home as NSString).appendingPathComponent(".fusion-studio-test/\(label)_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    // (1) 用户覆盖 + 可执行 → 返回 override
    func test_resolveBackendPath_prefersUserOverride() {
        let dir = homeTmpDir("override")
        let tmp = dir + "/start.sh"
        makeExecutable(tmp)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let cfg = FusionConfig.shared
        let origOverride = cfg.backendRuntimeOverridePath
        let origDev = cfg.upstreamAgentStudioPath
        defer {
            cfg.backendRuntimeOverridePath = origOverride
            cfg.upstreamAgentStudioPath = origDev
        }
        cfg.backendRuntimeOverridePath = tmp
        // dev 指向不存在路径, 确保不干扰
        cfg.upstreamAgentStudioPath = "~/__fusion393_nonexistent_dev__"

        let result = cfg.resolveBackendStartSh(bundleURL: URL(fileURLWithPath: "/__fusion393_nonexistent_bundle__"))
        XCTAssertEqual(result, tmp, "用户覆盖 + 可执行必须优先返回")
    }

    // (2) dev 模式: ~/fusion start.sh 存在 → 返回 dev path (即便 bundle 也在)
    func test_resolveBackendPath_devModeWhenFusionExists() {
        let devDir = NSTemporaryDirectory() + "fusion393_test_dev_\(UUID().uuidString)"
        let devStart = devDir + "/start.sh"
        makeExecutable(devStart)
        // bundle 也造一个存在
        let bundleDir = NSTemporaryDirectory() + "fusion393_test_bundle_\(UUID().uuidString)"
        let bundleStart = bundleDir + "/Contents/Services/start.sh"
        makeExecutable(bundleStart)
        defer {
            try? FileManager.default.removeItem(atPath: devDir)
            try? FileManager.default.removeItem(atPath: bundleDir)
        }

        let cfg = FusionConfig.shared
        let origOverride = cfg.backendRuntimeOverridePath
        let origDev = cfg.upstreamAgentStudioPath
        defer {
            cfg.backendRuntimeOverridePath = origOverride
            cfg.upstreamAgentStudioPath = origDev
        }
        cfg.backendRuntimeOverridePath = ""  // 无覆盖
        cfg.upstreamAgentStudioPath = devDir // dev 指向临时目录

        let result = cfg.resolveBackendStartSh(bundleURL: URL(fileURLWithPath: bundleDir))
        XCTAssertEqual(result, devStart, "dev start.sh 存在时优先返回 dev (即便 bundle 也在)")
    }

    // (3) bundle 回退: 无 override 无 dev → 返回 bundle path
    func test_resolveBackendPath_bundleFallback() {
        let bundleDir = NSTemporaryDirectory() + "fusion393_test_bundle2_\(UUID().uuidString)"
        let bundleStart = bundleDir + "/Contents/Services/start.sh"
        makeExecutable(bundleStart)
        defer { try? FileManager.default.removeItem(atPath: bundleDir) }

        let cfg = FusionConfig.shared
        let origOverride = cfg.backendRuntimeOverridePath
        let origDev = cfg.upstreamAgentStudioPath
        defer {
            cfg.backendRuntimeOverridePath = origOverride
            cfg.upstreamAgentStudioPath = origDev
        }
        cfg.backendRuntimeOverridePath = ""
        cfg.upstreamAgentStudioPath = "~/__fusion393_nonexistent_dev__"

        let result = cfg.resolveBackendStartSh(bundleURL: URL(fileURLWithPath: bundleDir))
        XCTAssertEqual(result, bundleStart, "无 override 无 dev → 回退 bundle Contents/Services/start.sh")
    }

    // (4) 全无 → nil
    func test_resolveBackendPath_nilWhenNothingPresent() {
        let cfg = FusionConfig.shared
        let origOverride = cfg.backendRuntimeOverridePath
        let origDev = cfg.upstreamAgentStudioPath
        defer {
            cfg.backendRuntimeOverridePath = origOverride
            cfg.upstreamAgentStudioPath = origDev
        }
        cfg.backendRuntimeOverridePath = ""
        cfg.upstreamAgentStudioPath = "~/__fusion393_nonexistent_dev__"

        let result = cfg.resolveBackendStartSh(bundleURL: URL(fileURLWithPath: "/__fusion393_nonexistent_bundle__"))
        XCTAssertNil(result, "override/dev/bundle 均不可执行 → nil (调用方置 criticalBackendMissing)")
    }

    // (5) override 不可执行 (in-allowlist 但不存在) → 跳过 override, 回退 bundle
    func test_resolveBackendPath_invalidOverrideSkipped() {
        let bundleDir = NSTemporaryDirectory() + "fusion393_test_bundle3_\(UUID().uuidString)"
        let bundleStart = bundleDir + "/Contents/Services/start.sh"
        makeExecutable(bundleStart)
        defer { try? FileManager.default.removeItem(atPath: bundleDir) }

        let cfg = FusionConfig.shared
        let origOverride = cfg.backendRuntimeOverridePath
        let origDev = cfg.upstreamAgentStudioPath
        defer {
            cfg.backendRuntimeOverridePath = origOverride
            cfg.upstreamAgentStudioPath = origDev
        }
        // in-allowlist (home 下) 但不存在的覆盖: 通过 allowlist, isExecutableFile=false → 跳过回退 bundle
        let badDir = homeTmpDir("bad-override")
        defer { try? FileManager.default.removeItem(atPath: badDir) }
        cfg.backendRuntimeOverridePath = badDir + "/start.sh"
        cfg.upstreamAgentStudioPath = "~/__fusion393_nonexistent_dev__"

        let result = cfg.resolveBackendStartSh(bundleURL: URL(fileURLWithPath: bundleDir))
        XCTAssertEqual(result, bundleStart, "override 不可执行 → 跳过, 回退 bundle")
    }

    // (6) resetToDefaults 清空 override
    func test_resetToDefaults_clearsBackendRuntimeOverride() {
        let cfg = FusionConfig.shared
        let origOverride = cfg.backendRuntimeOverridePath
        defer { cfg.backendRuntimeOverridePath = origOverride }

        cfg.backendRuntimeOverridePath = "/tmp/some/custom/path"
        XCTAssertEqual(cfg.backendRuntimeOverridePath, "/tmp/some/custom/path")
        cfg.resetToDefaults()
        XCTAssertEqual(cfg.backendRuntimeOverridePath, "", "resetToDefaults 必须清空 backendRuntimeOverridePath")
    }
}
