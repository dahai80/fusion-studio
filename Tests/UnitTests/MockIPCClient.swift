import Foundation
@testable import FusionStudio

// F-I5: mock IPCClient — override connect() (跳 socket syscall) + call() (返 canned dict + 记录 args)。
// IPCClient 是 concrete class (非 final), call(method:params:) 非 private 非 final → @testable import 可子类化 override。
// 所有 typed wrapper (IPCAgentMethods.swift 等 extension) 经 self.call(...) → 动态分派命中本 override。
// super.init 调 connect() 被本 override 吞为 no-op, 不碰 /tmp socket。
final class MockIPCClient: IPCClient {

    struct RecordedCall {
        let method: String
        let params: [String: Any]
    }

    private(set) var recordedCalls: [RecordedCall] = []

    // method → canned response。未配置且无 defaultResponse → 抛 IPCError.invalidResponse。
    var responsesByMethod: [String: [String: Any]] = [:]

    // method → 抛指定 error (优先于 response)。模拟上游 RPC 失败。
    var errorsByMethod: [String: Error] = [:]

    // method 未配置时的兜底 response (非抛错)。留 nil 则未配置 = 抛错。
    var defaultResponse: [String: Any]? = nil

    override init(socketPath: String = "/tmp/mock-fusion-studio.sock") {
        super.init(socketPath: socketPath)
    }

    override func connect() {
        // no-op: mock 不碰真 socket, super.init 调本方法被吞。
    }

    override func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        recordedCalls.append(RecordedCall(method: method, params: params))
        if let err = errorsByMethod[method] {
            throw err
        }
        if let resp = responsesByMethod[method] {
            return resp
        }
        if let def = defaultResponse {
            return def
        }
        throw IPCError.invalidResponse
    }

    // 清空记录, 复用同一 mock 实例跨多用例。
    func reset() {
        recordedCalls.removeAll()
        responsesByMethod.removeAll()
        errorsByMethod.removeAll()
        defaultResponse = nil
    }

    // 取最近一次记录的指定 method 的 call (从后往前找)。
    func lastCall(method: String) -> RecordedCall? {
        return recordedCalls.reversed().first { $0.method == method }
    }
}
