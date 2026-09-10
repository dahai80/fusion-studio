import Foundation
import os.log

// L0-1 (P0-4): IPC 熔断器状态隔离. 旧实现 circuitOpen/circuitConsecutiveFailures/
// circuitHalfOpenProbing/circuitOpenedAt 为 IPCClient 裸 var, 同时被 queue (callOnce/timeout)
// 与 readQueue (handleResponse/drainPending) 两个串行队列并发读写 = Swift UB (数据竞态).
// 审计0902 §2.6 注释称 "跑在串行 queue 无需锁" — readQueue 打破该假设.
//
// 修复: 状态收进 CircuitBreaker, 所有访问经 single NSLock 串行化. 消除跨队列竞态.
// 设计决策 (ruling): 不用 actor. 熔断检查/计数在 queue.async 与 readQueue 同步闭包内调用
// (continuation resume 前需同步判定 fast-fail/probe), actor 需 await 会破坏 sync 控制流 +
// 续体时序. NSLock 保正确性同时保调用点签名不变 (250+ call site 零改动). 与 plan "actor" 偏离,
// 根因: sync 调用点约束. 正确性等价 (单锁串行化 = actor 语义).
final class CircuitBreaker {
    private let log = Logger(subsystem: "com.fusion.studio", category: "CircuitBreaker")
    let threshold: Int
    let recoverySec: Double
    private let lock = NSLock()
    private var _consecutiveFailures: Int = 0
    private var _open: Bool = false
    private var _openedAt: Double = 0
    private var _halfOpenProbing: Bool = false

    init(threshold: Int = 5, recoverySec: Double = 30) {
        self.threshold = threshold
        self.recoverySec = recoverySec
    }

    var isOpen: Bool {
        lock.lock(); defer { lock.unlock() }
        return _open
    }

    var consecutiveFailures: Int {
        lock.lock(); defer { lock.unlock() }
        return _consecutiveFailures
    }

    // half-open 探测闸: 开路满 recoverySec 后放一个 call 穿透试探.
    // 返 true = 已转 half-open 放行该 call; false = 仍 fast-fail.
    // 探测在途时后续 call fast-fail (返 false), 仅发起探测的那一个 call 穿透,
    // 等 recordSuccess/Failure 解除在途标志后才放下一个 (审计0830 P2-IPC-2: 防批量重放雪崩).
    func allowProbe() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if _halfOpenProbing { return false }
        let now = Date().timeIntervalSince1970
        if _open && now - _openedAt >= recoverySec {
            _halfOpenProbing = true
            return true
        }
        return false
    }

    // 成功复位 (half-open 探测成功 or 正常成功清连续失败).
    func recordSuccess() {
        lock.lock(); defer { lock.unlock() }
        if _open || _halfOpenProbing {
            log.info("circuit closed (recovered) failures=\(self._consecutiveFailures, privacy: .public)")
        }
        _consecutiveFailures = 0
        _open = false
        _halfOpenProbing = false
    }

    // 失败计数 + 达阈值开路. half-open 探测失败立即重开并续计时.
    // 一次断连事件一个失败信号 (drainPending 排空多 pending 只调一次).
    func recordFailure() {
        lock.lock(); defer { lock.unlock() }
        _consecutiveFailures += 1
        _halfOpenProbing = false
        if _consecutiveFailures >= threshold && !_open {
            _open = true
            _openedAt = Date().timeIntervalSince1970
            log.error("circuit OPEN failures=\(self._consecutiveFailures, privacy: .public) — fast-fail pending calls until backend recovers")
        } else if _open {
            _openedAt = Date().timeIntervalSince1970
        }
    }
}
