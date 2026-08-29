import XCTest
@testable import FusionStudio

// F-I4 #197: IPCClient 权限校验 + 错误传播 wiring 测试。
// validateSocketPermission 已 private → internal 便 @testable 直调, 验权限矩阵:
//   0666 (group/other 写位) 拒, 0600 (owner-only) 过, 0644 (other 可读非写) 过 (permBits & 0o022 == 0)。
// MockIPCClient.errorsByMethod 模拟上游 RPC 失败 → 调 bridge 方法验 BridgeError 透出 (非静默吞)。
// 本地 swift test = 0 用例 (toolchain drift Swift 6.3.3/macOS 26/Testing Library 1902 不发现 XCTest);
//   CI macOS-14/Xcode 15.x 为权威 gate (~205 用例)。详见 CLAUDE.md toolchain-drift 说明。
@MainActor
final class IPCClientPermissionTests: XCTestCase {

    // 临时文件路径 (setUp 创建, tearDown 清理)。
    private var tmpPath: String!

    override func setUp() async throws {
        try await super.setUp()
        let dir = NSTemporaryDirectory()
        tmpPath = (dir as NSString).appendingPathComponent("fusion-ipc-perm-test-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: tmpPath, contents: Data())
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tmpPath)
        tmpPath = nil
        try await super.tearDown()
    }

    // MARK: - validateSocketPermission 权限矩阵

    // 0600 owner-only → permBits & 0o022 == 0 → 过 (返 nil)。
    func testValidateSocketPermissionOwnerOnlyPasses() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpPath)
        let client = MockIPCClient()
        XCTAssertNil(client.validateSocketPermission(tmpPath))
    }

    // 0644 owner 写 + other 读 (非写) → group/other 写位均 0 → 过 (返 nil)。
    func testValidateSocketPermissionOwnerWriteOtherReadPasses() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tmpPath)
        let client = MockIPCClient()
        XCTAssertNil(client.validateSocketPermission(tmpPath))
    }

    // 0666 group+other 写位 → permBits & 0o022 != 0 → 拒 (返非 nil 原因)。
    func testValidateSocketPermissionGroupOtherWritableRejected() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: tmpPath)
        let client = MockIPCClient()
        let reason = client.validateSocketPermission(tmpPath)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.contains("0o666") ?? false || reason?.contains("0666") ?? false)
    }

    // 0664 group 写 → permBits & 0o020 != 0 → 拒。
    func testValidateSocketPermissionGroupWritableRejected() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o664], ofItemAtPath: tmpPath)
        let client = MockIPCClient()
        XCTAssertNotNil(client.validateSocketPermission(tmpPath))
    }

    // 不存在路径 → 文件 attrs 取失败 → 返 nil (非权限问题, 交 connect errno)。
    func testValidateSocketPermissionMissingPathPasses() {
        let client = MockIPCClient()
        XCTAssertNil(client.validateSocketPermission("/tmp/fusion-nonexistent-\(UUID().uuidString)"))
    }

    // MARK: - MockIPCClient 错误传播 wiring

    // errorsByMethod 配置错误 → call() 抛 → bridge 方法透出 BridgeError (非静默吞)。
    func testMockIPCClientErrorPropagatesToBridge() async {
        let mock = MockIPCClient()
        let bridge = AgentBridge()
        bridge.setIPCClient(mock)
        let thrownError = IPCError.invalidResponse
        mock.errorsByMethod[RPCMethod.agentList] = thrownError
        do {
            _ = try await bridge.fetchAgents()
            XCTFail("fetchAgents 应抛错 (MockIPCClient.errorsByMethod 配了 agentList error)")
        } catch {
            // bridge catch IPCError → BridgeError.ipcError; 验非空错 (sanitize 后仍含描述)。
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    // 未配置 response 且无 defaultResponse → call() 抛 IPCError.invalidResponse → bridge 透出。
    func testMockIPCClientUnconfiguredMethodThrows() async throws {
        let mock = MockIPCClient()
        let bridge = AgentBridge()
        bridge.setIPCClient(mock)
        // safetyCheck 走 client.safetyCheck → self.call, mock 未配 → 抛。
        do {
            _ = try await bridge.safetyCheck(content: "x")
            XCTFail("safetyCheck 应抛错 (未配 response)")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
