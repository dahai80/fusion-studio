import Foundation
import SwiftUI
import Combine

// MARK: - 备份条目

struct BackupEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let date: Date
    let size: Int64
    let type: BackupType
    let fileURL: URL

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    enum BackupType: String, CaseIterable {
        case config   = "配置"
        case templates = "模板"
        case workspace = "工作区"
        case full     = "完整"

        var icon: String {
            switch self {
            case .config:   return "gearshape"
            case .templates: return "doc.on.doc"
            case .workspace: return "folder"
            case .full:     return "externaldrive"
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BackupEntry, rhs: BackupEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 配置同步管理器

class ConfigSyncManager: ObservableObject {
    static let shared = ConfigSyncManager()

    @Published var backups: [BackupEntry] = []
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle

    enum SyncStatus: Equatable {
        case idle
        case syncing(String)
        case success(String)
        case failed(String)
    }

    private let fileManager = FileManager.default
    private let backupQueue = DispatchQueue(label: "com.fusion-studio.backup", qos: .utility)

    var backupDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".fusion-studio-backups")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var configDir: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".fusion-studio/config")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 备份

    /// 创建配置备份
    func createBackup(type: BackupEntry.BackupType, completion: @escaping (Bool) -> Void = { _ in }) {
        isSyncing = true
        syncStatus = .syncing("正在备份 \(type.rawValue)...")

        backupQueue.async { [weak self] in
            guard let self = self else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let dateStr = dateFormatter.string(from: Date())

            let fileName = "FusionStudio-\(type.rawValue)-\(dateStr).json"
            let fileURL = self.backupDir.appendingPathComponent(fileName)

            var backupData: [String: Any] = [
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
                "type": type.rawValue,
                "date": dateStr,
                "app": "FusionStudio"
            ]

            switch type {
            case .config:
                backupData["settings"] = self.collectSettings()
            case .templates:
                backupData["templates"] = self.collectTemplates()
            case .workspace:
                backupData["workspace"] = self.collectWorkspace()
            case .full:
                backupData["settings"] = self.collectSettings()
                backupData["templates"] = self.collectTemplates()
                backupData["workspace"] = self.collectWorkspace()
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: backupData, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: fileURL)

                let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
                let size = (attrs[.size] as? Int64) ?? 0

                DispatchQueue.main.async {
                    let entry = BackupEntry(name: fileName, date: Date(), size: size, type: type, fileURL: fileURL)
                    self.backups.append(entry)
                    self.lastSyncDate = Date()
                    self.isSyncing = false
                    self.syncStatus = .success("\(type.rawValue) 备份完成")
                    self.cleanupOldBackups()
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncStatus = .failed("备份失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    /// 恢复备份
    func restoreBackup(_ entry: BackupEntry, completion: @escaping (Bool) -> Void = { _ in }) {
        isSyncing = true
        syncStatus = .syncing("正在恢复 \(entry.name)...")

        backupQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try Data(contentsOf: entry.fileURL)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw BackupError.invalidFormat
                }

                if let settings = json["settings"] as? [String: Any] {
                    self.restoreSettings(settings)
                }
                // 模板和工作区恢复需用户确认路径，这里只记录
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncStatus = .success("恢复完成: \(entry.name)")
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncStatus = .failed("恢复失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    /// 删除备份
    func deleteBackup(_ entry: BackupEntry) {
        try? fileManager.removeItem(at: entry.fileURL)
        backups.removeAll { $0.id == entry.id }
    }

    // MARK: - 数据收集

    private func collectSettings() -> [String: Any] {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        let fusionKeys = defaults.keys.filter { $0.hasPrefix("fusion") || $0.contains("MLX") || $0.contains("mlx") }
        var settings: [String: Any] = [:]
        for key in fusionKeys {
            settings[key] = defaults[key]
        }
        // 额外常用配置
        let prefixedKeys = ["launchAtLogin", "autoStartMLX", "offlineMode", "defaultQuant", "preferredDevice", "workspacePath", "language"]
        for key in prefixedKeys {
            settings[key] = defaults[key]
        }
        return settings
    }

    private func collectTemplates() -> [[String: Any]] {
        // 导出用户自定义模板
        return []
    }

    private func collectWorkspace() -> [String: Any] {
        let workspacePath = UserDefaults.standard.string(forKey: "workspacePath") ?? "~/FusionStudio/workspace"
        let expanded = (workspacePath as NSString).expandingTildeInPath
        var info: [String: Any] = ["path": expanded]

        if fileManager.fileExists(atPath: expanded) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: expanded)
                info["contents"] = contents
                let totalSize = try contents.reduce(0) { size, item in
                    let itemPath = (expanded as NSString).appendingPathComponent(item)
                    let attrs = try fileManager.attributesOfItem(atPath: itemPath)
                    return size + (Int(attrs[.size] as? Int64 ?? 0))
                }
                info["totalSize"] = totalSize
            } catch {
                info["error"] = error.localizedDescription
            }
        }
        return info
    }

    private func restoreSettings(_ settings: [String: Any]) {
        let defaults = UserDefaults.standard
        for (key, value) in settings {
            defaults.set(value, forKey: key)
        }
    }

    // MARK: - 清理

    private func cleanupOldBackups() {
        let maxBackups = 20
        guard backups.count > maxBackups else { return }

        let sorted = backups.sorted { $0.date < $1.date }
        let toDelete = sorted.prefix(backups.count - maxBackups)
        for entry in toDelete {
            deleteBackup(entry)
        }
    }

    /// 加载已有备份列表
    func loadExistingBackups() {
        backupQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let files = try fileManager.contentsOfDirectory(
                    at: backupDir,
                    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
                )
                let entries = files.filter { $0.pathExtension == "json" }.compactMap { url -> BackupEntry? in
                    guard let attrs = try? self.fileManager.attributesOfItem(atPath: url.path),
                          let size = attrs[.size] as? Int64,
                          let date = attrs[.creationDate] as? Date else { return nil }

                    let type: BackupEntry.BackupType
                    if url.lastPathComponent.contains("完整") { type = .full }
                    else if url.lastPathComponent.contains("配置") { type = .config }
                    else if url.lastPathComponent.contains("模板") { type = .templates }
                    else if url.lastPathComponent.contains("工作区") { type = .workspace }
                    else { type = .config }

                    return BackupEntry(name: url.lastPathComponent, date: date, size: size, type: type, fileURL: url)
                }
                DispatchQueue.main.async {
                    self.backups = entries.sorted { $0.date > $1.date }
                }
            } catch {}
        }
    }

    enum BackupError: LocalizedError {
        case invalidFormat
        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "无效的备份文件格式"
            }
        }
    }
}

// MARK: - 配置同步视图

struct ConfigSyncView: View {
    @StateObject private var syncManager = ConfigSyncManager.shared
    @State private var showBackupConfirm = false
    @State private var backupType: BackupEntry.BackupType = .config
    @State private var showRestoreConfirm = false
    @State private var selectedBackup: BackupEntry?

    var body: some View {
        VStack(spacing: 0) {
            // 状态栏
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.accentColor)
                Text("配置同步 & 备份")
                    .font(.headline)
                Spacer()

                if case .syncing(let msg) = syncManager.syncStatus {
                    ProgressView()
                        .controlSize(.small)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if case .success(let msg) = syncManager.syncStatus {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.caption)
                } else if case .failed(let msg) = syncManager.syncStatus {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 备份操作
                    GroupBox("创建备份") {
                        VStack(spacing: 12) {
                            Picker("备份类型", selection: $backupType) {
                                ForEach(BackupEntry.BackupType.allCases, id: \.self) { type in
                                    Label(type.rawValue, systemImage: type.icon).tag(type)
                                }
                            }

                            HStack {
                                if let last = syncManager.lastSyncDate {
                                    Text("上次备份: \(last.formatted(date: .numeric, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { showBackupConfirm = true }) {
                                    Label("立即备份", systemImage: "tray.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(syncManager.isSyncing)
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)

                    // 备份列表
                    GroupBox("备份历史") {
                        if syncManager.backups.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("暂无备份")
                                    .foregroundColor(.secondary)
                                Text("创建备份后，将显示在这里")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(syncManager.backups) { entry in
                                HStack(spacing: 10) {
                                    Image(systemName: entry.type.icon)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text("\(entry.sizeFormatted) · \(entry.date.formatted(date: .numeric, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button("恢复") {
                                        selectedBackup = entry
                                        showRestoreConfirm = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("删除") {
                                        syncManager.deleteBackup(entry)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .foregroundColor(.red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 自动备份设置
                    GroupBox("自动备份") {
                        VStack(spacing: 8) {
                            Toggle("自动备份配置", isOn: .constant(true))
                            Toggle("自动备份模板", isOn: .constant(false))
                            Picker("备份频率", selection: .constant(1)) {
                                Text("每天").tag(1)
                                Text("每3天").tag(3)
                                Text("每周").tag(7)
                            }
                            Text("自动备份保留最近 20 份，超出自动清理")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .onAppear {
            syncManager.loadExistingBackups()
        }
        .alert("确认备份", isPresented: $showBackupConfirm) {
            Button("取消", role: .cancel) {}
            Button("备份") {
                syncManager.createBackup(type: backupType)
            }
        } message: {
            Text("将创建 \(backupType.rawValue) 备份到:\n\(syncManager.backupDir.path)")
        }
        .alert("确认恢复", isPresented: $showRestoreConfirm) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                if let entry = selectedBackup {
                    syncManager.restoreBackup(entry)
                }
            }
        } message: {
            Text("恢复将覆盖当前配置，此操作不可撤销。确定继续吗？")
        }
    }
}