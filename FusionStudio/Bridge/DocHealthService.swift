import Foundation
import os.log

// ARCH-1 Phase 2 (audit-product-0907 P2-2): DocHealth 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   checkHealth call site 0 改)。@Published (isConnected/lastError) + stored (reconnectTimer/
//   reconnectAttempt) 现属 DocHealthState; scheduleReconnect + handleError 留 DocBridge (协调器,
//   handleError 汇入中央错漏斗, scheduleReconnect 经 computed forward self.reconnectTimer 写 healthState)。
//   本域 checkHealth 成功路径自清 reconnectTimer/reconnectAttempt (域自身 stored, 直接 self.X)。

private let docHealthLog = Logger(subsystem: "com.fusion.studio", category: "DocHealthService")

extension DocHealthState {

    func checkHealth() {
        struct HealthResp: Decodable { var status: String? }
        bridge?.get("/api/health") { [weak self] (result: Result<HealthResp, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.lastError = nil
                    self?.reconnectTimer?.invalidate()
                    self?.reconnectTimer = nil
                    self?.reconnectAttempt = 0
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "health")
            }
        }
    }
}

extension DocBridge {

    func checkHealth() { healthState.checkHealth() }
}
