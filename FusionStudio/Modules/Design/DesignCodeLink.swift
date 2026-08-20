// Callers: DesignBridge (auto-activate on project open), DesignView (lifecycle bind).
// Affected API: DesignCodeLink.activate/deactivate/handleFileChange.
// Data schemas: DesignCodeLink @MainActor ObservableObject, watches .fusion-design/ dir via FileWatcher.
// User instruction: "启动 Phase 4" — Task #46 Design↔Code 双向绑定

import Foundation
import Combine
import os.log

private let codeLinkLog = Logger(subsystem: "com.fusion.studio", category: "DesignCodeLink")

@MainActor
class DesignCodeLink: ObservableObject {
    static let shared = DesignCodeLink()

    @Published var isActive: Bool = false
    @Published var lastSyncDirection: SyncDirection?
    @Published var conflictMessage: String?

    enum SyncDirection: String {
        case designToFile = "design→file"
        case fileToDesign = "file→design"
    }

    private var fileWatcher: FileWatcher?
    private var cancellables = Set<AnyCancellable>()
    private var lastDesignWriteTime: [String: Date] = [:]
    private var debounceTask: Task<Void, Never>?

    private init() {}

    // MARK: - Activate watching

    func activate(designBridge: DesignBridge, projectId: String? = nil) {
        guard let rootPath = resolveRootPath(projectId: projectId) else {
            codeLinkLog.warning("DesignCodeLink: no project root, cannot activate")
            return
        }

        let watchPath = (rootPath as NSString).appendingPathComponent(".fusion-design")
        let fm = FileManager.default
        if !fm.fileExists(atPath: watchPath) {
            try? fm.createDirectory(atPath: watchPath, withIntermediateDirectories: true)
        }

        fileWatcher = FileWatcher()
        fileWatcher?.startWatching(paths: [watchPath], latency: 0.5)

        fileWatcher?.$fileChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                for event in events {
                    self.handleFileChange(event, designBridge: designBridge)
                }
            }
            .store(in: &cancellables)

        isActive = true
        codeLinkLog.info("DesignCodeLink: activated, watching \(watchPath)")
    }

    // MARK: - Deactivate

    func deactivate() {
        fileWatcher?.stopWatching()
        fileWatcher = nil
        cancellables.removeAll()
        isActive = false
        codeLinkLog.info("DesignCodeLink: deactivated")
    }

    // MARK: - Mark design-originated write (prevent echo)

    func markDesignWrite(artifactName: String) {
        lastDesignWriteTime[artifactName] = Date()
    }

    // MARK: - Handle file change from FileWatcher

    private func handleFileChange(_ event: FileChangeEvent, designBridge: DesignBridge) {
        let filePath = event.path
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ["html", "htm", "jsx", "tsx", "svg", "css", "swift"].contains(ext) else { return }

        let fileName = (filePath as NSString).lastPathComponent
        let artifactName = sanitizeToArtifactName(fileName)

        if let lastWrite = lastDesignWriteTime[artifactName],
           Date().timeIntervalSince(lastWrite) < 2.0 {
            codeLinkLog.info("DesignCodeLink: skipping echo from design write — \(artifactName)")
            return
        }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                codeLinkLog.error("DesignCodeLink: failed to read changed file — \(filePath)")
                return
            }

            if content != designBridge.currentArtifactCode {
                let type = DesignArtifactExporter.shared.typeFromExtension(ext)
                designBridge.currentArtifactCode = content
                designBridge.currentArtifactType = type
                designBridge.artifactSaved = false
                lastSyncDirection = .fileToDesign
                codeLinkLog.info("DesignCodeLink: file→design sync, \(content.count) chars from \(fileName)")

                if let lastDesign = lastDesignWriteTime[artifactName],
                   Date().timeIntervalSince(lastDesign) < 10.0 {
                    conflictMessage = String(format: I18nManager.shared.t(.design_cl_conflictFmt), fileName)
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        conflictMessage = nil
                    }
                }
            }
        }
    }

    // MARK: - Push design to file

    func pushDesignToFile(designBridge: DesignBridge, projectId: String? = nil) {
        guard !designBridge.currentArtifactCode.isEmpty else { return }

        let result = DesignArtifactExporter.shared.exportPage(
            title: designBridge.currentArtifactTitle,
            code: designBridge.currentArtifactCode,
            type: designBridge.currentArtifactType,
            projectId: projectId
        )

        if result.success {
            markDesignWrite(artifactName: designBridge.currentArtifactTitle)
            lastSyncDirection = .designToFile
            codeLinkLog.info("DesignCodeLink: design→file sync, path=\(result.path)")
        } else {
            codeLinkLog.error("DesignCodeLink: design→file failed — \(result.error ?? "unknown")")
        }
    }

    // MARK: - Private helpers

    private func resolveRootPath(projectId: String?) -> String? {
        if let pid = projectId,
           let project = FusionProjectManager.shared.projects.first(where: { $0.id == pid }) {
            return project.rootPath
        }
        return FusionProjectManager.shared.activeProject?.rootPath
    }

    private func sanitizeToArtifactName(_ fileName: String) -> String {
        let nameWithoutExt = fileName.components(separatedBy: ".").dropLast().joined(separator: ".")
        return nameWithoutExt
            .replacingOccurrences(of: "_v\\d+$", with: "", options: .regularExpression)
    }
}
