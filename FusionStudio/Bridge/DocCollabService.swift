import Foundation
import os.log

// ARCH-1 Phase 4 (audit-product-0907 P2-2): DocCollab 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   connectCollab/disconnectCollab/sendCollabUpdate call site 0 改)。@Published (collabConnected/
//   collabUsers) + nonisolated(unsafe) collabTask 现属 DocCollabState。WS 基础设施 reach-through:
//   bridge?.baseURL (建 WS URL) + bridge?.session (webSocketTask) + bridge?.authToken (Bearer 头)。
//   receiveCollabMessage private 留本域 (递归回调)。DispatchQueue.main.async hops 留原样, Phase 6 清。

private let docCollabLog = Logger(subsystem: "com.fusion.studio", category: "DocCollabService")

extension DocCollabState {

    func connectCollab(pageId: String) {
        docCollabLog.info("connectCollab: pageId=\(pageId)")
        guard let baseURL = bridge?.baseURL,
              let url = URL(string: baseURL.replacingOccurrences(of: "http", with: "ws") + "/collaboration?page=\(pageId)") else {
            docCollabLog.error("connectCollab: invalid WS URL")
            return
        }
        var request = URLRequest(url: url)
        if let token = bridge?.authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        IdentityService.applyIdentityHeaders(to: &request)
        collabTask = bridge?.session.webSocketTask(with: request)
        collabTask?.resume()
        DispatchQueue.main.async { self.collabConnected = true }
        docCollabLog.info("connectCollab: WS task started")
        receiveCollabMessage()
    }

    func disconnectCollab() {
        docCollabLog.info("disconnectCollab")
        collabTask?.cancel(with: .goingAway, reason: nil)
        collabTask = nil
        DispatchQueue.main.async { self.collabConnected = false; self.collabUsers = [] }
    }

    func sendCollabUpdate(data: Data) {
        guard let task = collabTask else {
            docCollabLog.warning("sendCollabUpdate: no active WS task")
            return
        }
        task.send(.data(data)) { error in
            if let error = error {
                docCollabLog.error("sendCollabUpdate failed: \(error.localizedDescription)")
            }
        }
    }

    // nonisolated: WS receive callback runs on URLSession delegate queue (non-MainActor).
    //   Body only logs + recurses + hops to main for @Published write (collabConnected).
    //   collabTask is nonisolated(unsafe). Mirrors cleanup() nonisolated pattern.
    nonisolated private func receiveCollabMessage() {
        collabTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    docCollabLog.info("collab message: \(text.prefix(100))")
                case .data(let data):
                    docCollabLog.info("collab binary: \(data.count) bytes")
                @unknown default:
                    break
                }
                self?.receiveCollabMessage()
            case .failure(let error):
                docCollabLog.error("collab receive error: \(error.localizedDescription)")
                DispatchQueue.main.async { self?.collabConnected = false }
            }
        }
    }
}

extension DocBridge {

    func connectCollab(pageId: String) { collabState.connectCollab(pageId: pageId) }

    func disconnectCollab() { collabState.disconnectCollab() }

    func sendCollabUpdate(data: Data) { collabState.sendCollabUpdate(data: data) }
}
