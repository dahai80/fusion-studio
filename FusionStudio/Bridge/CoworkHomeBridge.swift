// Callers: UnifiedChatView (Cowork 模式).
// Affected API: CoworkHomeBridge — 授权文件夹选择 + 工作流提交 + desk.events.* 实时进度.
// Data schemas: desk.system.set_scoped_folder/scoped_folder, desk.workflow.create/run, desk.events.subscribe/poll.
// User instruction: #217 Chat/Cowork 共用首页 + NSOpenPanel 授权文件夹选择交互 (审计 P1-1).

import Foundation
import AppKit
import SwiftUI
import os.log

private let coworkHomeLog = Logger(subsystem: "com.fusion.studio", category: "CoworkHome")

// #217: desk.events.* 事件归一化为 UI 可渲染的进度事件 (view 映射为对话气泡).
struct CoworkHomeEvent: Identifiable, Equatable {
    let id = UUID()
    let kind: Kind
    let text: String

    enum Kind: String {
        case step
        case artifact
        case done
        case error
    }

    static func == (lhs: CoworkHomeEvent, rhs: CoworkHomeEvent) -> Bool { lhs.id == rhs.id }
}

// #217: desk.events.* 原始 dict -> CoworkHomeEvent 映射 (纯函数, 可单测).
enum CoworkHomeEventMapper {
    static func map(_ raw: [String: Any]) -> CoworkHomeEvent? {
        let type = (raw["type"] as? String) ?? ""
        switch type {
        case "step", "node", "node_start", "node_end":
            let node = (raw["node"] as? String) ?? (raw["name"] as? String) ?? "?"
            let status = (raw["status"] as? String) ?? ""
            let text = status.isEmpty ? "▶ \(node)" : "▶ \(node) · \(status)"
            return CoworkHomeEvent(kind: .step, text: text)
        case "artifact", "artifact_created":
            let name = (raw["name"] as? String) ?? (raw["artifact"] as? String) ?? "artifact"
            return CoworkHomeEvent(kind: .artifact, text: "📦 \(name)")
        case "done", "completed", "workflow_done":
            return CoworkHomeEvent(kind: .done, text: "✓ done")
        case "error", "failed":
            let msg = (raw["message"] as? String) ?? (raw["error"] as? String) ?? "unknown"
            return CoworkHomeEvent(kind: .error, text: "✗ error: \(msg)")
        default:
            return nil
        }
    }
}

// #217: 首页 Chat↔Cowork 模式.
enum CoworkHomeMode: String, CaseIterable {
    case chat
    case cowork
}

@MainActor
final class CoworkHomeBridge: ObservableObject {
    @Published var scopedFolders: [String] = []
    @Published var enforce: Bool = true
    @Published var isAuthorizing = false
    @Published var isPolling = false
    @Published var lastError: String?
    @Published var lastEvent: CoworkHomeEvent?

    private(set) var subId: String?
    private var pollTask: Task<Void, Never>?

    // @StateObject 在视图 init 时构造, 无法访问 EnvironmentObject ipc;
    // 故先置空, 首次 .task 注入真实 ipc (coworkHome.ipc = ipc).
    var ipc: IPCClient

    init(ipc: IPCClient) {
        self.ipc = ipc
    }

    // 查询已注册授权文件夹 (启动/切模式时回填; 已注册则跳过 NSOpenPanel).
    func loadScopedFolder() async {
        do {
            let res = try await ipc.deskSystemGetScopedFolder()
            if let folders = res["folders"] as? [String] {
                scopedFolders = folders
            }
            if let enf = res["enforce"] as? Bool {
                enforce = enf
            }
            coworkHomeLog.info("loadScopedFolder: folders=\(self.scopedFolders.count), enforce=\(self.enforce)")
        } catch {
            coworkHomeLog.warning("loadScopedFolder failed (服务未启动?): \(error.localizedDescription)")
        }
    }

    // 确保授权文件夹就绪: 已注册直接返回 true; 空则弹 NSOpenPanel 让用户选.
    func ensureScopedFolder() async -> Bool {
        if !scopedFolders.isEmpty { return true }
        isAuthorizing = true
        defer { isAuthorizing = false }
        guard let picked = await pickFolders(), !picked.isEmpty else {
            lastError = "未选择授权文件夹"
            coworkHomeLog.warning("ensureScopedFolder: 用户取消选择")
            return false
        }
        return await setScopedFolder(folders: picked, enforce: enforce)
    }

    // NSOpenPanel 选目录 (MainActor modal). 返回绝对路径数组; 取消返回 nil.
    func pickFolders() async -> [String]? {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = true
            panel.title = I18nManager.shared.t(.cw_home_pick_title)
            panel.prompt = I18nManager.shared.t(.cw_home_pick_confirm)
            panel.message = I18nManager.shared.t(.cw_home_pick_prompt)
            let resp = panel.runModal()
            guard resp == .OK, !panel.urls.isEmpty else { return nil }
            return panel.urls.map { $0.path }
        }
    }

    // 下发授权文件夹到 ScopedFolderManager.
    func setScopedFolder(folders: [String], enforce: Bool) async -> Bool {
        do {
            let res = try await ipc.deskSystemSetScopedFolder(folders: folders, enforce: enforce)
            if let set = res["set"] as? Bool, set {
                scopedFolders = (res["folders"] as? [String]) ?? folders
                if let enf = res["enforce"] as? Bool { self.enforce = enf }
                lastError = nil
                coworkHomeLog.info("setScopedFolder ok: folders=\(self.scopedFolders)")
                return true
            }
            let err = (res["error"] as? String) ?? "set_scoped_folder 返回未确认"
            lastError = err
            coworkHomeLog.error("setScopedFolder rejected: \(err)")
            return false
        } catch {
            lastError = error.localizedDescription
            coworkHomeLog.error("setScopedFolder failed: \(error.localizedDescription)")
            return false
        }
    }

    // 提交工作流: desk.workflow.create(prompt) -> desk.workflow.run(workflow) -> 开启事件轮询.
    func submitWorkflow(prompt: String) async -> Bool {
        do {
            let created = try await ipc.deskWorkflowCreate(prompt: prompt)
            guard let workflow = created["workflow"] as? [String: Any], !workflow.isEmpty else {
                lastError = (created["error"] as? String) ?? "workflow.create 未返回 workflow"
                coworkHomeLog.error("submitWorkflow create empty: \(self.lastError ?? "")")
                return false
            }
            let run = try await ipc.deskWorkflowRun(workflow: workflow)
            if let err = run["error"] as? String {
                lastError = err
                coworkHomeLog.error("submitWorkflow run rejected: \(err)")
                return false
            }
            coworkHomeLog.info("submitWorkflow ok, start polling")
            startPolling()
            return true
        } catch {
            lastError = error.localizedDescription
            coworkHomeLog.error("submitWorkflow failed: \(error.localizedDescription)")
            return false
        }
    }

    // 订阅 desk.events 并轮询, 每个 event 经映射后 publish 到 lastEvent (view 映射为气泡).
    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            do {
                let sub = try await self.ipc.deskEventsSubscribe()
                self.subId = (sub["sub_id"] as? String) ?? (sub["id"] as? String)
                guard let sid = self.subId, !sid.isEmpty else {
                    self.lastError = "events.subscribe 未返回 sub_id"
                    coworkHomeLog.warning("startPolling: no sub_id")
                    self.isPolling = false
                    return
                }
                coworkHomeLog.info("polling started sub_id=\(sid)")
                while !Task.isCancelled {
                    do {
                        let polled = try await self.ipc.deskEventsPoll(subId: sid)
                        let events = (polled["events"] as? [[String: Any]]) ?? []
                        var sawTerminal = false
                        for raw in events {
                            if let ev = CoworkHomeEventMapper.map(raw) {
                                self.lastEvent = ev
                                if ev.kind == .done || ev.kind == .error { sawTerminal = true }
                            }
                        }
                        if sawTerminal { break }
                    } catch {
                        coworkHomeLog.warning("poll iteration error (transient): \(error.localizedDescription)")
                    }
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            } catch {
                coworkHomeLog.error("startPolling subscribe failed: \(error.localizedDescription)")
            }
            self.isPolling = false
            coworkHomeLog.info("polling stopped")
        }
    }

    // 停止轮询 (view 消失/切模式). 上游无 unsubscribe RPC, 仅本地 cancel.
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        subId = nil
        if isPolling {
            isPolling = false
            coworkHomeLog.info("stopPolling: cancelled")
        }
    }
}
