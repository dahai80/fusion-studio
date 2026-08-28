import Foundation
import Combine
import os.log

private let guardBridgeLog = Logger(subsystem: "com.fusion.studio", category: "GuardBridge")

// #344: fusion-guard 零信任动作鉴权守护 (UDS JSON-RPC 2.0, /tmp/fusion-guard.sock)。
// 触发高危动作 (AgentBridge.executeGraph) 前调 guard.evaluate; BLOCK 不下发, L3 走人机确认弹窗,
// L4 直接终止无弹窗。TCC 权限申请结果上报 guard 审计汇聚 (H1: guard 只汇聚不代理 TCC)。

enum GuardError: Error, LocalizedError {
    case daemonDown
    case rpcError(code: Int, message: String)
    case invalidResponse
    case blocked(reason: String)
    case approvalDenied
    case approvalTimeout
    var errorDescription: String? {
        switch self {
        case .daemonDown: return "fusion-guard 守护未运行"
        case .rpcError(let c, let m): return "guard RPC 错误 (\(c)): \(m)"
        case .invalidResponse: return "guard 响应无效"
        case .blocked(let r): return "动作被安全守卫拦截: \(r)"
        case .approvalDenied: return "用户拒绝安全确认"
        case .approvalTimeout: return "安全确认超时"
        }
    }
}

// GuardVerdict (PRD §12.3; E5: BLOCK 在 result 非 error)
struct GuardVerdict: Codable {
    let action: String
    let riskLevel: String
    let reason: String
    let stage: String
    let requiresApproval: Bool
    let redactedContent: String?
    let seatbeltRequired: Bool
    let actionId: String
    let verdictEpoch: Int
    let verdictTtlSecs: Int
    let inferredCategory: String?

    enum CodingKeys: String, CodingKey {
        case action, reason, stage
        case riskLevel = "risk_level"
        case requiresApproval = "requires_approval"
        case redactedContent = "redacted_content"
        case seatbeltRequired = "seatbelt_required"
        case actionId = "action_id"
        case verdictEpoch = "verdict_epoch"
        case verdictTtlSecs = "verdict_ttl_secs"
        case inferredCategory = "inferred_category"
    }

    var isBlock: Bool { action.lowercased() == "block" }
    // L3 + requiresApproval = 走人机确认; L4 requiresApproval 恒 false (H8, 直接 block 无弹窗)
    // guard 守护返回小写 risk_level (l4), 大小写不敏感比对避免 L3 漏判 needsApproval。
    var needsApproval: Bool { requiresApproval && riskLevel.uppercased() == "L3" }

    // fail-closed 兜底 verdict: 守护不可达/超时/解析失败时构造, 调用方统一判 isBlock
    static func failClosed(reason: String) -> GuardVerdict {
        GuardVerdict(
            action: "block", riskLevel: "L4", reason: reason, stage: "client",
            requiresApproval: false, redactedContent: nil, seatbeltRequired: false,
            actionId: "", verdictEpoch: 0, verdictTtlSecs: 0, inferredCategory: nil
        )
    }
}

// MARK: - GuardBridge

final class GuardBridge: ObservableObject {

    // 跨非-View 对象 (VoiceInputManager/ScreenContext) 的便捷路径: app 注入后设 shared。
    // TCC 上报 fire-and-forget, 仅审计汇聚, 非主流程门控。
    static var shared: GuardBridge?

    @Published var isDaemonReady: Bool = false
    @Published var lastError: String?
    @Published var rulesEpoch: Int = 0
    @Published var pendingChallenge: GuardChallenge?

    struct GuardChallenge: Identifiable {
        let id = UUID()
        let actionId: String
        let action: String
        let reason: String
        let riskLevel: String
        let content: String
        let category: String?
    }

    private let socketPath: String
    private var ipc: IPCClient?
    private var approvalContinuation: CheckedContinuation<Bool, Error>?

    init() {
        self.socketPath = FusionConfig.shared.expandedUpstreamPath(
            FusionConfig.shared.fusionGuardSocketPath
        )
        guardBridgeLog.info("GuardBridge init socket=\(self.socketPath, privacy: .public)")
    }

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
        guardBridgeLog.info("GuardBridge IPCClient wired")
    }

    // MARK: - 守护状态

    func checkDaemonStatus() async {
        do {
            let res = try await rpc(method: RPCMethod.guardPing)
            let pong = res["pong"] as? Bool ?? false
            let version = res["version"] as? String
            let epoch = res["rules_epoch"] as? Int ?? 0
            await MainActor.run {
                self.isDaemonReady = pong
                self.rulesEpoch = epoch
                self.lastError = nil
            }
            guardBridgeLog.info("guard.ping ok pong=\(pong, privacy: .public) version=\(version ?? "-", privacy: .public) rules_epoch=\(epoch)")
        } catch {
            await MainActor.run {
                self.isDaemonReady = false
                self.lastError = error.localizedDescription
            }
            guardBridgeLog.warning("guard.ping failed (daemon down?): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 核心拦截: executeGraph 下发前调

    func evaluate(action: String, content: String, contentType: String = "shell", categoryHint: String? = nil) async throws -> GuardVerdict {
        var params: [String: Any] = [
            "content": content,
            "caller_epoch": rulesEpoch,
            "requester": "fusion-studio",
            "action": action,
            "content_type": contentType,
        ]
        if let categoryHint = categoryHint { params["category_hint"] = categoryHint }
        do {
            let res = try await rpc(method: RPCMethod.guardEvaluate, params: params)
            guard let data = try? JSONSerialization.data(withJSONObject: res),
                  let verdict = try? JSONDecoder().decode(GuardVerdict.self, from: data) else {
                guardBridgeLog.error("guard.evaluate parse failed — fail-closed")
                return GuardVerdict.failClosed(reason: "guard 响应解析失败")
            }
            return verdict
        } catch {
            // R2 fail-closed: 守护不可达/超时/RPC 错 = block, 不绕过
            guardBridgeLog.error("guard.evaluate rpc failed (fail-closed): \(error.localizedDescription, privacy: .public)")
            return GuardVerdict.failClosed(reason: error.localizedDescription)
        }
    }

    func confirm(actionId: String, approved: Bool, approvedBy: String = "fusion-studio-user") async throws -> GuardVerdict {
        let params: [String: Any] = [
            "action_id": actionId,
            "approved": approved,
            "approved_by": approvedBy,
        ]
        let res = try await rpc(method: RPCMethod.guardConfirm, params: params)
        guard let data = try? JSONSerialization.data(withJSONObject: res),
              let verdict = try? JSONDecoder().decode(GuardVerdict.self, from: data) else {
            throw GuardError.invalidResponse
        }
        return verdict
    }

    // MARK: - TCC 审计上报 (Phase 5, fire-and-forget 非阻塞)

    func reportTcc(permission: String, result: String, reason: String = "") async {
        let params: [String: Any] = [
            "permission": permission,
            "requester": "fusion-studio",
            "result": result,
            "reason": reason,
        ]
        do {
            let res = try await rpc(method: RPCMethod.guardTccReport, params: params)
            let auditId = res["audit_id"] as? String
            guardBridgeLog.info("guard.tcc.report ok permission=\(permission, privacy: .public) result=\(result, privacy: .public) audit=\(auditId ?? "-", privacy: .public)")
        } catch {
            // 守护缺席静默: 审计非阻塞, 不影响 TCC 申请主流程
            guardBridgeLog.warning("guard.tcc.report failed (non-blocking): \(error.localizedDescription, privacy: .public)")
        }
    }

    func tccStatus() async {
        do {
            _ = try await rpc(method: RPCMethod.guardTccStatus)
        } catch {
            guardBridgeLog.warning("guard.tcc.status failed (non-blocking): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - L3 人机确认协调

    func requestApproval(actionId: String, action: String, content: String, reason: String, riskLevel: String, category: String?) async throws -> Bool {
        await MainActor.run {
            self.pendingChallenge = GuardChallenge(
                actionId: actionId, action: action, reason: reason,
                riskLevel: riskLevel, content: content, category: category
            )
        }
        guardBridgeLog.info("guard L3 approval requested action=\(action, privacy: .public) risk=\(riskLevel, privacy: .public)")
        return try await withCheckedThrowingContinuation { cont in
            self.approvalContinuation = cont
        }
    }

    // GuardChallengeModal 回调: 用户点 Approve/Reject
    func resolveApproval(approved: Bool) async {
        guard let ch = await MainActor.run(body: { self.pendingChallenge }) else {
            approvalContinuation?.resume(throwing: GuardError.approvalTimeout)
            approvalContinuation = nil
            return
        }
        do {
            if approved {
                let v = try await confirm(actionId: ch.actionId, approved: true)
                await MainActor.run { self.pendingChallenge = nil }
                approvalContinuation?.resume(returning: !v.isBlock)
            } else {
                _ = try? await confirm(actionId: ch.actionId, approved: false)
                await MainActor.run { self.pendingChallenge = nil }
                approvalContinuation?.resume(returning: false)
            }
        } catch {
            await MainActor.run { self.pendingChallenge = nil }
            approvalContinuation?.resume(throwing: error)
        }
        approvalContinuation = nil
    }

    // MARK: - UDS JSON-RPC 传输 (复用 IPCClient.udsCall, guard 2s fail-closed 超时)

    private func rpc(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        guard let ipc = ipc else {
            guardBridgeLog.error("rpc before IPCClient wired: \(method, privacy: .public)")
            throw GuardError.daemonDown
        }
        do {
            return try await ipc.udsCall(socketPath: socketPath, method: method, params: params, timeoutSecs: 2)
        } catch let ipcErr as IPCError {
            if case .disconnected = ipcErr { throw GuardError.daemonDown }
            if case .rpcError(let code, let msg) = ipcErr { throw GuardError.rpcError(code: code, message: msg) }
            throw GuardError.invalidResponse
        } catch {
            throw GuardError.daemonDown
        }
    }
}
