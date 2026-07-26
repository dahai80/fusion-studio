// Callers: ModuleDetailView routing.
// Affected API: AutoUpdateManager (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Combine

// MARK: - 版本信息

struct AppVersion: Codable, Equatable {
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let htmlUrl: String
    let assets: [ReleaseAsset]

    struct ReleaseAsset: Codable, Equatable {
        let name: String
        let browserDownloadUrl: String
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
            case size
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
        case assets
    }

    var isNewerThan: Bool {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return tagName.compare(current, options: .numeric) == .orderedDescending
    }

    var downloadURL: String? {
        assets.first?.browserDownloadUrl
    }
}

// MARK: - 更新状态

enum UpdateState: Equatable {
    case idle
    case checking
    case available(AppVersion)
    case upToDate
    case downloading(Double)
    case error(String)
}

// MARK: - 自动更新管理器

class AutoUpdateManager: ObservableObject {
    static let shared = AutoUpdateManager()

    @Published var state: UpdateState = .idle
    @Published var showUpdateSheet = false
    @Published var lastCheckDate: Date?

    private let repoOwner = "dahai80"
    private let repoName = "fusion-studio"
    private let versionURL: String

    private var cancellables = Set<AnyCancellable>()

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    init() {
        self.versionURL = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    }

    /// 检查更新
    func checkForUpdates(force: Bool = false) {
        // 非强制检查时，距离上次检查不足1小时跳过
        if !force, let last = lastCheckDate, Date().timeIntervalSince(last) < 3600 {
            return
        }

        state = .checking

        guard let url = URL(string: versionURL) else {
            state = .error("无效的版本检查地址")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: AppVersion.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.state = .error("检查更新失败: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] version in
                self?.lastCheckDate = Date()
                if version.isNewerThan {
                    self?.state = .available(version)
                    self?.showUpdateSheet = true
                } else {
                    self?.state = .upToDate
                }
            }
            .store(in: &cancellables)
    }

    /// 下载并安装更新
    func downloadAndInstall(_ version: AppVersion) {
        guard let urlString = version.downloadURL, let url = URL(string: urlString) else {
            state = .error("无法获取下载地址")
            return
        }

        state = .downloading(0)

        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.state = .error("下载失败: \(error.localizedDescription)")
                    return
                }

                guard let tempURL = tempURL else {
                    self.state = .error("下载文件丢失")
                    return
                }

                // 移动到下载目录
                let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let destURL = downloadsDir.appendingPathComponent("FusionStudio-\(version.tagName).dmg")

                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    self.state = .upToDate

                    // 提示用户安装
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "更新已下载"
                        alert.informativeText = "Fusion Studio \(version.tagName) 已下载到「下载」文件夹。请关闭当前应用，打开 DMG 安装新版本。"
                        alert.addButton(withTitle: "打开下载文件夹")
                        alert.addButton(withTitle: "稍后")
                        if alert.runModal() == .alertFirstButtonReturn {
                            NSWorkspace.shared.activateFileViewerSelecting([destURL])
                        }
                    }
                } catch {
                    self.state = .error("保存文件失败: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    /// 跳过此版本
    func skipVersion(_ version: AppVersion) {
        UserDefaults.standard.set(version.tagName, forKey: "skipped_version")
        state = .upToDate
        showUpdateSheet = false
    }

    /// 重置检查状态
    func reset() {
        state = .idle
        showUpdateSheet = false
    }
}

// MARK: - 更新设置视图

struct UpdateSettingsView: View {
    @StateObject private var updateManager = AutoUpdateManager.shared
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @AppStorage("checkInterval") private var checkInterval = 24.0

    var body: some View {
        Form {
            Section("版本信息") {
                DetailRow("当前版本", updateManager.currentVersion)
                DetailRow("构建号", updateManager.currentBuild)
            }

            Section("更新设置") {
                Toggle("自动检查更新", isOn: $autoCheckUpdates)
                if autoCheckUpdates {
                    Picker("检查间隔", selection: $checkInterval) {
                        Text("每天").tag(24.0)
                        Text("每3天").tag(72.0)
                        Text("每周").tag(168.0)
                    }
                }
            }

            Section {
                Button(action: { updateManager.checkForUpdates(force: true) }) {
                    HStack {
                        Spacer()
                        if case .checking = updateManager.state {
                            ProgressView()
                                .controlSize(.small)
                            Text("检查中...")
                        } else {
                            Label("检查更新", systemImage: "arrow.clockwise")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateManager.state == .checking)

                if case .available(let version) = updateManager.state {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("发现新版本: \(version.tagName)")
                        Spacer()
                        Button("下载") {
                            updateManager.downloadAndInstall(version)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("跳过") {
                            updateManager.skipVersion(version)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if case .downloading(let progress) = updateManager.state {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("下载中... \(Int(progress * 100))%")
                            .font(.caption)
                        ProgressView(value: progress)
                    }
                }

                if case .error(let msg) = updateManager.state {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if let last = updateManager.lastCheckDate {
                    Text("上次检查: \(last.formatted(date: .numeric, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 更新弹窗

struct UpdateSheetView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var updateManager = AutoUpdateManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if case .available(let version) = updateManager.state {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("发现新版本")
                    .font(.largeTitle)
                    .bold()

                Text("Fusion Studio \(version.tagName)")
                    .font(.title2)
                    .foregroundColor(.secondary)

                ScrollView {
                    Text(version.body)
                        .font(.body)
                        .padding()
                }
                .frame(height: 200)
                .background(theme.surfaceSecondary)
                .cornerRadius(8)

                if let url = version.downloadURL {
                    HStack(spacing: 12) {
                        Button("稍后") {
                            updateManager.skipVersion(version)
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button("下载更新") {
                            updateManager.downloadAndInstall(version)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ProgressView()
                Text("正在检查更新...")
            }
        }
        .padding()
        .frame(width: 400, height: 450)
    }
}