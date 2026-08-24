// Callers: ModuleDetailView routing.
// Affected API: ConfigSyncManager (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

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
        case config   = "config"
        case templates = "templates"
        case workspace = "workspace"
        case full     = "full"

        var icon: String {
            switch self {
            case .config:   return "gearshape"
            case .templates: return "doc.on.doc"
            case .workspace: return "folder"
            case .full:     return "externaldrive"
            }
        }

        var localizedName: String {
            switch self {
            case .config:    return I18nManager.shared.t(.csm_type_config)
            case .templates: return I18nManager.shared.t(.csm_type_templates)
            case .workspace: return I18nManager.shared.t(.csm_type_workspace)
            case .full:      return I18nManager.shared.t(.csm_type_full)
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
        syncStatus = .syncing(I18nManager.shared.tf(.csm_status_backing_up_fmt, type.localizedName))

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
                    self.syncStatus = .success(I18nManager.shared.tf(.csm_status_backup_done_fmt, type.localizedName))
                    self.cleanupOldBackups()
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncStatus = .failed(I18nManager.shared.tf(.csm_status_backup_failed_fmt, error.localizedDescription))
                    completion(false)
                }
            }
        }
    }

    /// 恢复备份
    func restoreBackup(_ entry: BackupEntry, completion: @escaping (Bool) -> Void = { _ in }) {
        isSyncing = true
        syncStatus = .syncing(I18nManager.shared.tf(.csm_status_restoring_fmt, entry.name))

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
                    self.syncStatus = .success(I18nManager.shared.tf(.csm_status_restore_done_fmt, entry.name))
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncStatus = .failed(I18nManager.shared.tf(.csm_status_restore_failed_fmt, error.localizedDescription))
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
                    if url.lastPathComponent.contains("full") { type = .full }
                    else if url.lastPathComponent.contains("config") { type = .config }
                    else if url.lastPathComponent.contains("templates") { type = .templates }
                    else if url.lastPathComponent.contains("workspace") { type = .workspace }
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
            case .invalidFormat: return I18nManager.shared.t(.csm_err_invalid_format)
            }
        }
    }
}

// MARK: - 配置同步视图

struct ConfigSyncView: View {
    @Environment(\.studioTheme) private var theme
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
                Text(I18nManager.shared.t(.csm_title))
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
            .background(theme.surfaceSecondary)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 备份操作
                    GroupBox(I18nManager.shared.t(.csm_group_create)) {
                        VStack(spacing: 12) {
                            Picker(I18nManager.shared.t(.csm_pick_type), selection: $backupType) {
                                ForEach(BackupEntry.BackupType.allCases, id: \.self) { type in
                                    Label(type.localizedName, systemImage: type.icon).tag(type)
                                }
                            }

                            HStack {
                                if let last = syncManager.lastSyncDate {
                                    Text(I18nManager.shared.tf(.csm_last_backup_fmt, last.formatted(date: .numeric, time: .shortened)))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { showBackupConfirm = true }) {
                                    Label(I18nManager.shared.t(.csm_btn_backup_now), systemImage: "tray.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(syncManager.isSyncing)
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)

                    // 备份列表
                    GroupBox(I18nManager.shared.t(.csm_group_history)) {
                        if syncManager.backups.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text(I18nManager.shared.t(.csm_empty))
                                    .foregroundColor(.secondary)
                                Text(I18nManager.shared.t(.csm_empty_hint))
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

                                    Button(I18nManager.shared.t(.csm_btn_restore)) {
                                        selectedBackup = entry
                                        showRestoreConfirm = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button(I18nManager.shared.t(.csm_btn_delete)) {
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
                    GroupBox(I18nManager.shared.t(.csm_group_auto)) {
                        VStack(spacing: 8) {
                            Toggle(I18nManager.shared.t(.csm_toggle_config), isOn: .constant(true))
                            Toggle(I18nManager.shared.t(.csm_toggle_templates), isOn: .constant(false))
                            Picker(I18nManager.shared.t(.csm_pick_freq), selection: .constant(1)) {
                                Text(I18nManager.shared.t(.csm_freq_daily)).tag(1)
                                Text(I18nManager.shared.t(.csm_freq_3days)).tag(3)
                                Text(I18nManager.shared.t(.csm_freq_weekly)).tag(7)
                            }
                            Text(I18nManager.shared.t(.csm_auto_keep_hint))
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
        .alert(I18nManager.shared.t(.csm_alert_backup_title), isPresented: $showBackupConfirm) {
            Button(I18nManager.shared.t(.csm_btn_cancel), role: .cancel) {}
            Button(I18nManager.shared.t(.csm_btn_backup)) {
                syncManager.createBackup(type: backupType)
            }
        } message: {
            Text(I18nManager.shared.tf(.csm_confirm_backup_msg_fmt, backupType.localizedName, syncManager.backupDir.path))
        }
        .alert(I18nManager.shared.t(.csm_alert_restore_title), isPresented: $showRestoreConfirm) {
            Button(I18nManager.shared.t(.csm_btn_cancel), role: .cancel) {}
            Button(I18nManager.shared.t(.csm_btn_restore), role: .destructive) {
                if let entry = selectedBackup {
                    syncManager.restoreBackup(entry)
                }
            }
        } message: {
            Text(I18nManager.shared.t(.csm_confirm_restore_msg))
        }
    }
}