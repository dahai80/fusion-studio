import Foundation
import os.log

// L0-1 (P1-2): async 计数信号量. 旧 udsCallSemaphore = DispatchSemaphore(value:32), udsCall 在
// DispatchQueue.global worker 内 semaphore.wait() 阻塞 GCD worker 线程 — 32 并发短连满后, 第 33 个
// caller 的 GCD worker 钉死在 wait, 不能服务其他 dispatch 工作, 突发耗尽线程池.
// actor 化: acquire 在容量满时挂起 continuation (不占线程), release 唤醒一个等待者. 零线程阻塞.
// 调用点 (udsCall) 已是 async, await acquire/release 天然适配, 阻塞 I/O 仍走 DispatchQueue.global
// (Darwin.read/write 为阻塞 syscall, 需独立线程, 不上 cooperative pool).
actor AsyncSemaphore {
    private let log = Logger(subsystem: "com.fusion.studio", category: "AsyncSemaphore")
    private let capacity: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(capacity: Int) {
        self.capacity = capacity
        self.available = capacity
    }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
            // 槽位直接转交给被唤醒的等待者, available 不变.
            return
        }
        if available < capacity {
            available += 1
        } else {
            log.warning("release with available=\(self.available) >= capacity (over-release)")
        }
    }
}
