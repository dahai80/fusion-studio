import Foundation
import os.log

// ARCH-1 Phase 8 (审计product-0906 P1): DesignFileSync 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignFileSyncPanel.enableFileSync/disableFileSync/syncArtifactToFile/syncFileToArtifact 0 改)。
//   syncArtifactToFile/syncFileToArtifact 跨域读 artifact (currentArtifactCode/Type/Title/artifactId) +
//   写 artifact (currentArtifactCode/artifactSaved) 经 self.bridge?.artifactState.X reach-through。
//   ipcClient (artifactSync RPC, setIPCClient 注入本域) + sanitizeFileName (artifact 跨域 bridge?.artifactState.X)。
//   enableFileSync/disableFileSync 纯本域状态。

private let designFileSyncLog = Logger(subsystem: "com.fusion.studio", category: "DesignFileSyncService")

extension DesignFileSyncState {

    func enableFileSync(to folderPath: String) {
        syncFolderPath = folderPath
        isFileSyncEnabled = true
        designFileSyncLog.info("DesignFileSync: file sync enabled to \(folderPath)")
    }

    func disableFileSync() {
        isFileSyncEnabled = false
        syncFolderPath = ""
        designFileSyncLog.info("DesignFileSync: file sync disabled")
    }

    func syncArtifactToFile() async {
        guard isFileSyncEnabled, !syncFolderPath.isEmpty,
              let code = bridge?.artifactState.currentArtifactCode, !code.isEmpty else {
            designFileSyncLog.warning("DesignFileSync: syncArtifactToFile — preconditions not met")
            return
        }

        let artifactType = bridge?.artifactState.currentArtifactType ?? "html"
        let artifactTitle = bridge?.artifactState.currentArtifactTitle ?? ""
        let ext = artifactType == "react" ? "jsx" : artifactType
        let fileName = artifactTitle.isEmpty ? "design.\(ext)" : "\((bridge?.artifactState.sanitizeFileName(artifactTitle)) ?? "design").\(ext)"
        let filePath = (syncFolderPath as NSString).appendingPathComponent(fileName)
        // 审计0827 #2: LLM 产物 fileName 经 syncFolderPath 拼 — 防 LLM 注入 ../ 或 symlink 越界写白名单外, validateFilePath 拒则跳过同步。
        guard SecurityManager.shared.validateFilePath(filePath) else {
            designFileSyncLog.warning("DesignFileSync: syncArtifactToFile reject path outside whitelist — \(filePath, privacy: .public)")
            return
        }

        let artifactId = bridge?.artifactState.artifactId ?? ""
        if let ipc = ipcClient, !artifactId.isEmpty {
            do {
                let result = try await ipc.artifactSync(artifactId: artifactId, filePath: filePath, direction: "artifact_to_file")
                designFileSyncLog.info("DesignFileSync: artifact synced via API — \(result)")
            } catch {
                designFileSyncLog.warning("DesignFileSync: API sync failed, falling back to file write — \(error.localizedDescription)")
                do {
                    try code.write(toFile: filePath, atomically: true, encoding: .utf8)
                    designFileSyncLog.info("DesignFileSync: artifact synced to file \(filePath) (fallback)")
                } catch {
                    designFileSyncLog.error("DesignFileSync: file sync failed — \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try code.write(toFile: filePath, atomically: true, encoding: .utf8)
                designFileSyncLog.info("DesignFileSync: artifact synced to file \(filePath)")
            } catch {
                designFileSyncLog.error("DesignFileSync: file sync failed — \(error.localizedDescription)")
            }
        }
    }

    func syncFileToArtifact() async {
        guard isFileSyncEnabled, !syncFolderPath.isEmpty else {
            designFileSyncLog.warning("DesignFileSync: syncFileToArtifact — preconditions not met")
            return
        }

        let artifactType = bridge?.artifactState.currentArtifactType ?? "html"
        let artifactTitle = bridge?.artifactState.currentArtifactTitle ?? ""
        let ext = artifactType == "react" ? "jsx" : artifactType
        let fileName = artifactTitle.isEmpty ? "design.\(ext)" : "\((bridge?.artifactState.sanitizeFileName(artifactTitle)) ?? "design").\(ext)"
        let filePath = (syncFolderPath as NSString).appendingPathComponent(fileName)
        // 审计0827 #2: 防 LLM 注入 ../ 或 symlink 越界读白名单外文件, validateFilePath 拒则跳过同步。
        guard SecurityManager.shared.validateFilePath(filePath) else {
            designFileSyncLog.warning("DesignFileSync: syncFileToArtifact reject path outside whitelist — \(filePath, privacy: .public)")
            return
        }

        let artifactId = bridge?.artifactState.artifactId ?? ""
        let currentCode = bridge?.artifactState.currentArtifactCode ?? ""
        if let ipc = ipcClient, !artifactId.isEmpty {
            do {
                let result = try await ipc.artifactSync(artifactId: artifactId, filePath: filePath, direction: "file_to_artifact")
                if let content = result["content"] as? String, content != currentCode {
                    bridge?.artifactState.currentArtifactCode = content
                    bridge?.artifactState.artifactSaved = false
                    designFileSyncLog.info("DesignFileSync: file synced to artifact via API (\(content.count) chars)")
                }
                return
            } catch {
                designFileSyncLog.warning("DesignFileSync: API sync failed, falling back to file read — \(error.localizedDescription)")
            }
        }

        guard FileManager.default.fileExists(atPath: filePath) else {
            designFileSyncLog.info("DesignFileSync: no file to sync at \(filePath)")
            return
        }

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            if content != currentCode {
                bridge?.artifactState.currentArtifactCode = content
                bridge?.artifactState.artifactSaved = false
                designFileSyncLog.info("DesignFileSync: file synced to artifact (\(content.count) chars)")
            }
        } catch {
            designFileSyncLog.error("DesignFileSync: file→artifact sync failed — \(error.localizedDescription)")
        }
    }
}
