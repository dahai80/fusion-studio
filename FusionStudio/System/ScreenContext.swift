// Callers: AgentStudioView for context-aware agent suggestions, any view needing screen context.
// Affected API: ScreenContextManager ObservableObject (published screen context properties).
// Data schemas: ScreenContextInfo struct.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import Foundation
import ApplicationServices
import AppKit
import Combine
import os.log

struct ScreenContextInfo: Equatable {
    var activeAppName: String
    var windowTitle: String
    var selectedText: String
    var bundleIdentifier: String
    var timestamp: Date

    static let empty = ScreenContextInfo(
        activeAppName: "",
        windowTitle: "",
        selectedText: "",
        bundleIdentifier: "",
        timestamp: Date()
    )
}

@MainActor
class ScreenContextManager: ObservableObject {

    @Published var currentContext: ScreenContextInfo = ScreenContextInfo.empty
    @Published var isMonitoring: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "ScreenContext")
    private var timer: Timer?
    private var pollInterval: TimeInterval = 2.0

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("ScreenContextManager already monitoring, ignoring startMonitoring call")
            return
        }

        let trusted = AXIsProcessTrusted()
        if !trusted {
            logger.warning("Accessibility permission not granted — screen context will be limited")
        }

        logger.info("ScreenContextManager starting polling at interval \(self.pollInterval)s")
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { _ in
            Task { @MainActor [weak self] in
                self?.pollContext()
            }
        }
        isMonitoring = true
        pollContext()
    }

    func stopMonitoring() {
        guard isMonitoring else {
            logger.warning("ScreenContextManager not monitoring, ignoring stopMonitoring call")
            return
        }

        logger.info("ScreenContextManager stopping polling")
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    static func requestAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        // #344: TCC 审计上报 fusion-guard (Phase 5, fire-and-forget 非阻塞, 守护缺席静默)。
        // H1: macOS per-app TCC 不可跨进程委托, studio 自申请 + 上报 guard 汇聚审计。
        let resultStr = trusted ? "granted" : (AXIsProcessTrusted() ? "granted" : "denied")
        Task { await GuardBridge.shared?.reportTcc(permission: "accessibility", result: resultStr) }
        return trusted
    }

    private func pollContext() {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success else {
            logger.debug("pollContext: no focused app, AX error \(appResult.rawValue)")
            return
        }

        let focusedAppElement = focusedApp as! AXUIElement

        var appName: AnyObject?
        _ = AXUIElementCopyAttributeValue(
            focusedAppElement,
            kAXTitleAttribute as CFString,
            &appName
        )

        var focusedWindow: AnyObject?
        _ = AXUIElementCopyAttributeValue(
            focusedAppElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        var windowTitle: String = ""
        if let window = focusedWindow {
            var titleValue: AnyObject?
            _ = AXUIElementCopyAttributeValue(
                window as! AXUIElement,
                kAXTitleAttribute as CFString,
                &titleValue
            )
            windowTitle = (titleValue as? String) ?? ""
        }

        var selectedText: String = ""
        var focusedUIElement: AnyObject?
        let uiResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedUIElement
        )
        if uiResult == .success, let element = focusedUIElement {
            var selectedRangeValue: AnyObject?
            let rangeResult = AXUIElementCopyAttributeValue(
                element as! AXUIElement,
                kAXSelectedTextAttribute as CFString,
                &selectedRangeValue
            )
            if rangeResult == .success, let text = selectedRangeValue as? String {
                selectedText = text
            }
        }

        var pid: pid_t = 0
        AXUIElementGetPid(focusedAppElement, &pid)
        var bundleIdentifier: String = ""
        if pid != 0 {
            bundleIdentifier = bundleIdentifierForPID(pid)
        }

        let newContext = ScreenContextInfo(
            activeAppName: (appName as? String) ?? "",
            windowTitle: windowTitle,
            selectedText: selectedText,
            bundleIdentifier: bundleIdentifier,
            timestamp: Date()
        )

        if newContext != currentContext {
            logger.info("Screen context changed: app=\(newContext.activeAppName) window=\(newContext.windowTitle) bundle=\(newContext.bundleIdentifier)")
            currentContext = newContext
        }
    }

    private func bundleIdentifierForPID(_ pid: pid_t) -> String {
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else {
            return ""
        }
        return runningApp.bundleIdentifier ?? ""
    }
}
