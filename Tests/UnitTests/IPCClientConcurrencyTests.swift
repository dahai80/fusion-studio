import XCTest
@testable import FusionStudio

// L0-1 (P0-3/4/5): IPCClient 并发正确性测试.
// CircuitBreaker 单锁串行化 (P0-4), fd 代际所有权 (P0-5), 幂等分类 (P0-3).
// 本地 swift test = 0 用例 (toolchain drift); CI macOS-14/Xcode 15.x 为权威 gate.
final class IPCClientConcurrencyTests: XCTestCase {

    // P0-4: 熔断器连续失败达阈值开路, 成功复位, half-open 仅放一个探测.
    func test_circuit_breaker_open_after_threshold_failures() {
        let cb = CircuitBreaker(threshold: 3, recoverySec: 30)
        XCTAssertFalse(cb.isOpen)
        cb.recordFailure()
        cb.recordFailure()
        XCTAssertFalse(cb.isOpen, "2 failures < threshold 3 should not open")
        cb.recordFailure()
        XCTAssertTrue(cb.isOpen, "3 failures >= threshold should open circuit")
    }

    func test_circuit_breaker_success_resets() {
        let cb = CircuitBreaker(threshold: 2, recoverySec: 30)
        cb.recordFailure()
        cb.recordFailure()
        XCTAssertTrue(cb.isOpen)
        cb.recordSuccess()
        XCTAssertFalse(cb.isOpen, "success should close circuit")
        XCTAssertEqual(cb.consecutiveFailures, 0)
    }

    // P2-IPC-2: half-open 探测在途时, 后续 allowProbe 返 false (防批量重放雪崩).
    func test_circuit_breaker_half_open_single_probe() {
        let cb = CircuitBreaker(threshold: 1, recoverySec: 0.01)
        cb.recordFailure()
        XCTAssertTrue(cb.isOpen)
        // 等 recovery 窗口过.
        Thread.sleep(forTimeInterval: 0.02)
        XCTAssertTrue(cb.allowProbe(), "first probe after recovery window should pass")
        XCTAssertFalse(cb.allowProbe(), "probe in-flight: subsequent calls fast-fail")
        // 探测失败重开, 续计时.
        cb.recordFailure()
        XCTAssertTrue(cb.isOpen)
    }

    // P0-3: 幂等读可重试, 非幂等变更类不重试.
    func test_is_idempotent_read_verbs() {
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.ping))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.rpcDiscover))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.mlxStatus))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.envHealthCheck))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.agentList))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.taskList))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.taskGet))
        XCTAssertTrue(RPCMethod.isIdempotent(RPCMethod.memoryListRecent))
    }

    func test_is_idempotent_mutations_not_retried() {
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.taskSubmit))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.agentExecute))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.agentCreate))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.agentDelete))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.cronRegister))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.envRepairAll))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.mlxStart))
        XCTAssertFalse(RPCMethod.isIdempotent(RPCMethod.graphExecute))
    }

    // P1-1: udsCall timeoutSecs 默认 nil (method-aware). 显式值覆盖.
    func test_udsCall_nil_timeout_default() async {
        // 验证签名接受 nil (默认) — 不连真 socket, 仅验不因默认值崩.
        // 无 sock 时 fast-fail disconnected, 不阻塞.
        let client = IPCClient(socketPath: "/tmp/nonexistent-ipc-concurrency-test.sock")
        do {
            _ = try await client.udsCall(socketPath: "/tmp/nonexistent-uds-test.sock", method: RPCMethod.ping)
            XCTFail("expected failure on missing socket")
        } catch {
            // 期望抛错 (disconnected/invalidRequest), 非挂起.
        }
    }

    // P0-5: clearSocketFd 自增 generation, 旧 gen 失效.
    func test_socket_fd_generation_invalidates_old() {
        let client = IPCClient(socketPath: "/tmp/nonexistent-gen-test.sock")
        client.setSocketFd(42)
        let (fd1, gen1) = client.currentFdGeneration()
        XCTAssertEqual(fd1, 42)
        let oldFd = client.clearSocketFd()
        XCTAssertEqual(oldFd, 42)
        let (fd2, gen2) = client.currentFdGeneration()
        XCTAssertEqual(fd2, -1)
        XCTAssertNotEqual(gen1, gen2, "generation must bump on clear")
    }

    func test_socket_fd_generation_bumps_on_set() {
        let client = IPCClient(socketPath: "/tmp/nonexistent-gen-set-test.sock")
        client.setSocketFd(10)
        let (_, gen1) = client.currentFdGeneration()
        client.setSocketFd(20)
        let (fd2, gen2) = client.currentFdGeneration()
        XCTAssertEqual(fd2, 20)
        XCTAssertNotEqual(gen1, gen2, "generation must bump on new set")
    }
}
