import Foundation
import os.log

// ARCH-1 Phase 7 (审计product-0906 P1): DesignVersion 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignVersionPanel.loadVersionHistory/diffVersions 0 改)。
//   loadVersionHistory 读 artifactId (artifact 跨域) 经 self.bridge?.artifactState.artifactId reach-through;
//   读 ipcClient (version RPC, setIPCClient 注入本域)。
//   diffVersions 调 skillDiff (skill 跨域) 经 self.bridge?.skillDiff reach-through。
//   rollbackToVersion 留 DesignBridge (跨域协调器: artifact + chat + loadVersionHistory)。

private let designVersionLog = Logger(subsystem: "com.fusion.studio", category: "DesignVersionService")

extension DesignVersionState {

    func loadVersionHistory() async {
        guard let artifactId = bridge?.artifactState.artifactId, !artifactId.isEmpty, let ipc = ipcClient else { return }
        isLoadingHistory = true
        do {
            let result = try await ipc.artifactVersionList(artifactId: artifactId)
            if let versions = result["versions"] as? [[String: Any]] {
                versionHistory = versions
            } else if let versions = result["data"] as? [[String: Any]] {
                versionHistory = versions
            }
            designVersionLog.info("DesignVersion: loaded \(self.versionHistory.count) versions for \(artifactId)")
        } catch {
            designVersionLog.error("DesignVersion loadVersionHistory: \(error)")
        }
        isLoadingHistory = false
    }

    func diffVersions(oldJSON: String, newJSON: String) async {
        isDiffing = true
        versionDiffEntries = await (bridge?.skillDiff(oldJSON: oldJSON, newJSON: newJSON) ?? [])
        isDiffing = false
        designVersionLog.info("DesignVersion: version diff completed, \(self.versionDiffEntries.count) changes")
    }
}
