// ScreenCapture: 交互式屏幕截图助手 (HIGH-4 修复)。
// 旧实现 3 处 (CodeMainView/UnifiedChatView/DesignWorkflowOrchestrator) 用 deprecated
// task.launchPath + task.launch() fire-and-forget, Process 出作用域即被回收 -> 交互式
// screencapture 中途被杀或变孤儿, 退出码永不观测。UnifiedChatView 还在 .userInitiated
// 协作线程池 waitUntilExit 阻塞, 重复调用可耗尽线程池。
//
// 修正: 单例持有 activeProcess 引用保活; executableURL + try run() 取代 deprecated launch;
// terminationHandler 回调观测退出码, 不阻塞协作线程池; run 在专用 thread (Thread) 而非
// DispatchQueue 协作线程。captureInteractive 返回 async, 退出码 0=成功。

import AppKit
import Foundation
import os.log

private let screenCaptureLog = Logger(subsystem: "com.fusion.studio", category: "ScreenCapture")

final class ScreenCapture {
    static let shared = ScreenCapture()

    private let lock = NSLock()
    private var activeProcess: Process?

    private init() {}

    // 同步保活登记: 终止旧进程并登记新 Process (NSLock 不在 async 上下文, 提取避免 Swift6 警告)。
    private func registerProcess(_ process: Process) {
        lock.lock()
        if let existing = activeProcess, existing.isRunning {
            screenCaptureLog.warning("captureInteractive: 已有活动截图进程, 终止旧 pid=\(existing.processIdentifier)")
            existing.terminate()
        }
        activeProcess = process
        lock.unlock()
    }

    // 同步清除登记: 仅当仍是同一 Process 才清空 (terminationHandler 回调, 同步上下文)。
    private func clearProcess(_ process: Process) {
        lock.lock()
        if activeProcess === process {
            activeProcess = nil
        }
        lock.unlock()
    }

    // 交互式截图: screencapture -i -c (交互选区 -> 剪贴板)。
    // async 返回退出码, 0=用户完成截图, 非0=用户取消或失败。
    // 多次调用串行: 已有活动进程则先终止旧再启新 (防止孤儿叠加)。
    func captureInteractive() async -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]

        // 保活: 单例持有引用, 防止 Swift ARC 在交互等待期回收 Process。
        registerProcess(process)

        // terminationHandler + CheckedContinuation 异步观测退出码, 不阻塞协作线程池。
        return await withCheckedContinuation { (cont: CheckedContinuation<Int32, Never>) in
            var resumed = false
            let resumeOnce: (Int32) -> Void = { code in
                if !resumed { resumed = true; cont.resume(returning: code) }
            }
            process.terminationHandler = { proc in
                screenCaptureLog.info("screencapture 退出 code=\(proc.terminationStatus)")
                ScreenCapture.shared.clearProcess(proc)
                resumeOnce(proc.terminationStatus)
            }

            do {
                try process.run()
                screenCaptureLog.info("screencapture 启动 pid=\(process.processIdentifier)")
            } catch {
                screenCaptureLog.error("screencapture 启动失败: \(error.localizedDescription, privacy: .public)")
                ScreenCapture.shared.clearProcess(process)
                resumeOnce(-1)
            }
        }
    }

    // 清理: app 退出或视图销毁时终止遗留进程, 防孤儿。
    func cleanup() {
        lock.lock()
        let proc = activeProcess
        activeProcess = nil
        lock.unlock()
        if let proc = proc, proc.isRunning {
            screenCaptureLog.warning("cleanup: 终止遗留 screencapture pid=\(proc.processIdentifier)")
            proc.terminate()
        }
    }
}
