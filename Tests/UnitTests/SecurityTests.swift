import XCTest
@testable import FusionStudio

// HIGH-3: 验证 validateFilePath 拒绝 symlink 穿越攻击。
// 攻击者在允许前缀目录内放指向 /etc 等敏感路径的 symlink, 旧实现仅 standardizingPath
// 不解析 symlink -> 白名单前缀匹配成功 -> 放行越权读。修正后 resolvingSymlinksInPath
// 取真实 inode 路径, 敏感目标被拒。
final class SecurityPathTests: XCTestCase {

    private let tmpRoot = "/tmp/fusion-security-test-\(UUID().uuidString)"
    private let manager = FileManager.default

    override func setUp() {
        super.setUp()
        try? manager.createDirectory(atPath: tmpRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? manager.removeItem(atPath: tmpRoot)
        super.tearDown()
    }

    // 合法路径: 在 /tmp 允许前缀内 -> true
    func testAllowedTmpPathAccepted() {
        let allowedPath = tmpRoot + "/legit.txt"
        XCTAssertTrue(SecurityManager.shared.validateFilePath(allowedPath),
                      "合法 /tmp 路径应被放行")
    }

    // symlink 穿越攻击: 在 /tmp 放指向 /etc/passwd 的 symlink -> 必须 false
    func testSymlinkToSensitivePathRejected() throws {
        let symlinkPath = tmpRoot + "/escape-to-etc"
        try? manager.removeItem(atPath: symlinkPath)
        try manager.createSymbolicLink(atPath: symlinkPath, withDestinationPath: "/etc")
        defer { try? manager.removeItem(atPath: symlinkPath) }

        XCTAssertFalse(SecurityManager.shared.validateFilePath(symlinkPath),
                       "指向 /etc 的 symlink 必须被拒绝 (HIGH-3 symlink 穿越修复)")
    }

    // symlink 指向允许目录内合法文件 -> 仍应放行 (不误伤)
    func testSymlinkWithinAllowedDirAccepted() throws {
        let realFile = tmpRoot + "/real.txt"
        manager.createFile(atPath: realFile, contents: Data("x".utf8))
        let symlinkPath = tmpRoot + "/link-to-real"
        try manager.createSymbolicLink(atPath: symlinkPath, withDestinationPath: realFile)
        defer {
            try? manager.removeItem(atPath: symlinkPath)
            try? manager.removeItem(atPath: realFile)
        }

        XCTAssertTrue(SecurityManager.shared.validateFilePath(symlinkPath),
                      "允许目录内 symlink 应被放行, 不误伤合法用例")
    }

    // 显式 .. 穿越 -> false (基础防线, 与 symlink 修正正交)
    func testDotDotTraversalRejected() {
        let escaped = tmpRoot + "/../../../../etc/passwd"
        XCTAssertFalse(SecurityManager.shared.validateFilePath(escaped),
                       "含 .. 的路径必须被拒绝")
    }
}
