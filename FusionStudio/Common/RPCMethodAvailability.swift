import Foundation
import os.log

private let rpcAvailLog = Logger(subsystem: "com.fusion.studio", category: "RPCMethodAvailability")

let kRPCMethodNotFoundCode = -32601

final class RPCMethodAvailability: ObservableObject {
    static let shared = RPCMethodAvailability()

    @Published private(set) var unavailableMethods: Set<String> = []

    private init() {}

    func isMethodAvailable(_ method: String) -> Bool {
        !unavailableMethods.contains(method)
    }

    func markUnavailable(_ method: String) {
        if unavailableMethods.insert(method).inserted {
            rpcAvailLog.info("RPC method unavailable (not implemented): \(method)")
        }
    }

    func markAvailable(_ method: String) {
        if unavailableMethods.remove(method) != nil {
            rpcAvailLog.info("RPC method became available: \(method)")
        }
    }

    func handleRPCError(_ error: Error, method: String) -> Bool {
        if let ipcError = error as? IPCError,
           case .rpcError(let code, _) = ipcError,
           code == kRPCMethodNotFoundCode {
            markUnavailable(method)
            return true
        }
        return false
    }
}
