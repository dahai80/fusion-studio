import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 5: Polling timer mechanics 迁入。MultiNodeEngine 留 startPolling/stopPolling
//   (协调器 — 调 8 域 fetch 方法, 跨域) + 1 行 stub schedulePoll/reschedulePoll 转发。
//   Polling 域 0 @Published — 纯 timer/单飞/失败计数域。
//   inflight 单飞保护 + 指数退避 (worstConsecutiveFailures) 全在本域, self-contained。
//   releaseInflight 已在 MultiNodePollingState (Phase 1)。

private let mnPollingLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodePollingService")

extension MultiNodePollingState {

    func schedulePoll(interval: TimeInterval, label: String, action: @escaping () -> Void) {
        // F-R10: 指数退避轮询。失败时 interval × 2^min(consecutiveFailures,5), 封顶 60s; 成功复位 base。
        // 单发递归 Timer 每轮重算 delay (固定 repeats Timer 无法动态调 interval)。单飞保护防慢响应风暴。
        var runOnce: (() -> Void)?
        runOnce = { [weak self] in
            guard let self = self else { return }
            self.inflightLock.lock()
            let already = self.inflightFetches.contains(label)
            if !already { self.inflightFetches.insert(label) }
            self.inflightLock.unlock()
            guard !already else {
                mnPollingLog.debug("Poll skip (in-flight): \(label)")
                self.reschedulePoll(interval: interval, label: label, action: action, runOnce: runOnce!)
                return
            }
            action()
            self.inflightLock.lock()
            self.inflightFetches.remove(label)
            self.inflightLock.unlock()
            self.reschedulePoll(interval: interval, label: label, action: action, runOnce: runOnce!)
        }
        action()
        reschedulePoll(interval: interval, label: label, action: action, runOnce: runOnce!)
    }

    func reschedulePoll(interval: TimeInterval, label: String, action: @escaping () -> Void, runOnce: @escaping () -> Void) {
        // F-R10: delay = base × 2^min(consecutiveFailures,5), 封顶 60s。consecutiveFailures=0 复位 base。
        // 审计0827 §3.5: 取 worstConsecutiveFailures (4 路最差值) 避免单路复位让全局 backoff 立归 base。
        let backoff = TimeInterval(min(worstConsecutiveFailures, 5))
        let delay = min(interval * pow(2.0, backoff), 60.0)
        if delay > interval {
            mnPollingLog.info("Poll backoff \(label): \(interval)s -> \(Int(delay))s (failures=\(self.worstConsecutiveFailures))")
        }
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            runOnce()
        }
        // 审计0827 §2.3 (P1): pollTimers 单发 timer 已 fire (isValid=false) 仍留数组,
        // 每轮 +1 无 prune, 长跑累积 (4 pollers × N cycles)。append 前剔失效项保数组紧致。
        pollTimers = pollTimers.filter { $0.isValid }
        pollTimers.append(timer)
    }
}
