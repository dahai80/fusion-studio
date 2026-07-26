// Callers: ModuleDetailView routing.
// Affected API: LicenseView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 许可证类型

enum LicenseType: String, CaseIterable {
    case community = "社区版"
    case pro       = "专业版"
    case enterprise = "企业版"
    case trial     = "试用版"

    var description: String {
        switch self {
        case .community:  return "免费开源，MIT 许可证，适用于个人开发者"
        case .pro:        return "高级功能解锁，包含多模态增强、训练流水线、高级运维"
        case .enterprise: return "全功能解锁，包含团队协作、集群部署、商业授权"
        case .trial:      return "14 天全功能试用，到期后自动降级为社区版"
        }
    }
    var price: String {
        switch self {
        case .community:  return "免费"
        case .pro:        return "¥299/年"
        case .enterprise: return "¥999/年"
        case .trial:      return "免费试用 14 天"
        }
    }
    var features: [(String, Bool)] {
        switch self {
        case .community:
            return [("基础 MLX 推理", true), ("设计/编码/仿真", true), ("环境自检与修复", true), ("RAG 知识库", true), ("智能体编排", true), ("多模态生成", false), ("训练流水线", false), ("团队协作", false), ("高级运维", false), ("商业授权", false)]
        case .pro:
            return [("基础 MLX 推理", true), ("设计/编码/仿真", true), ("环境自检与修复", true), ("RAG 知识库", true), ("智能体编排", true), ("多模态生成", true), ("训练流水线", true), ("团队协作", false), ("高级运维", true), ("商业授权", false)]
        case .enterprise:
            return [("基础 MLX 推理", true), ("设计/编码/仿真", true), ("环境自检与修复", true), ("RAG 知识库", true), ("智能体编排", true), ("多模态生成", true), ("训练流水线", true), ("团队协作", true), ("高级运维", true), ("商业授权", true)]
        case .trial:
            return [("基础 MLX 推理", true), ("设计/编码/仿真", true), ("环境自检与修复", true), ("RAG 知识库", true), ("智能体编排", true), ("多模态生成", true), ("训练流水线", true), ("团队协作", true), ("高级运维", true), ("商业授权", true)]
        }
    }
}

// MARK: - 激活状态

struct ActivationStatus {
    var isActivated: Bool = false
    var licenseType: LicenseType = .community
    var activatedAt: Date?
    var expiresAt: Date?
    var deviceId: String = ""
    var licensee: String = ""
    var licenseKey: String = ""
    var isOffline: Bool = true
}

// MARK: - 授权管理器

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var status = ActivationStatus()
    @Published var showActivationSheet = false
    @Published var activationError: String?

    var isPro: Bool { status.licenseType == .pro || status.licenseType == .enterprise || status.licenseType == .trial }
    var isExpired: Bool {
        guard let expires = status.expiresAt else { return false }
        return Date() > expires
    }
    var daysRemaining: Int {
        guard let expires = status.expiresAt else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: expires).day ?? 0)
    }

    init() {
        // 默认社区版（离线激活）
        status = ActivationStatus(isActivated: true, licenseType: .community, deviceId: deviceUUID())
    }

    private func deviceUUID() -> String {
        if let uuid = UserDefaults.standard.string(forKey: "device_uuid") { return uuid }
        let uuid = UUID().uuidString.prefix(8).lowercased()
        UserDefaults.standard.set(String(uuid), forKey: "device_uuid")
        return String(uuid)
    }

    func activate(key: String, email: String) {
        // 模拟激活验证
        let keyUpper = key.uppercased().trimmingCharacters(in: .whitespaces)

        if keyUpper.hasPrefix("FS-PRO-") {
            status = ActivationStatus(isActivated: true, licenseType: .pro, activatedAt: Date(), expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()), deviceId: deviceUUID(), licensee: email, licenseKey: key, isOffline: true)
            activationError = nil
        } else if keyUpper.hasPrefix("FS-ENT-") {
            status = ActivationStatus(isActivated: true, licenseType: .enterprise, activatedAt: Date(), expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()), deviceId: deviceUUID(), licensee: email, licenseKey: key, isOffline: true)
            activationError = nil
        } else if keyUpper == "TRIAL" {
            status = ActivationStatus(isActivated: true, licenseType: .trial, activatedAt: Date(), expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date()), deviceId: deviceUUID(), licensee: email, licenseKey: key, isOffline: true)
            activationError = nil
        } else {
            activationError = "无效的激活码。格式: FS-PRO-XXXXX、FS-ENT-XXXXX 或 TRIAL"
        }
        objectWillChange.send()
    }

    func deactivate() {
        status = ActivationStatus(isActivated: true, licenseType: .community, deviceId: deviceUUID())
        activationError = nil
        objectWillChange.send()
    }

    func startTrial() {
        activate(key: "TRIAL", email: "trial@local")
    }
}

// MARK: - 授权面板

struct LicenseView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = LicenseManager.shared
    @State private var licenseKey = ""
    @State private var email = ""
    @State private var selectedTab: LicenseTab = .overview

    enum LicenseTab: String, CaseIterable {
        case overview = "授权概览"
        case plans    = "版本对比"
        case activate = "激活"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("商业授权", systemImage: "key.fill").font(.headline)
                Spacer()
                LicenseBadge(type: manager.status.licenseType)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(LicenseTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            switch selectedTab {
            case .overview: LicenseOverview()
            case .plans:    LicensePlansView()
            case .activate: LicenseActivateView()
            }
        }
        .sheet(isPresented: $manager.showActivationSheet) {
            ActivationSheetView()
        }
    }

    private func tabIcon(_ tab: LicenseTab) -> String {
        switch tab { case .overview: return "info.circle"; case .plans: return "list.bullet"; case .activate: return "key" }
    }
}

// MARK: - 授权概览

struct LicenseOverview: View {
    @StateObject private var manager = LicenseManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: manager.status.licenseType == .community ? "shield" : "shield.checkered")
                .font(.system(size: 64))
                .foregroundColor(manager.status.licenseType == .community ? .secondary : .green)

            Text(manager.status.licenseType.rawValue)
                .font(.largeTitle).bold()

            Text(manager.status.licenseType.description)
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider().frame(width: 200)

            GroupBox("激活信息") {
                VStack(alignment: .leading, spacing: 6) {
                    LicRow("状态", manager.isExpired ? "已过期" : "有效")
                    LicRow("版本", manager.status.licenseType.rawValue)
                    LicRow("设备 ID", manager.status.deviceId)
                    if !manager.status.licensee.isEmpty {
                        LicRow("授权人", manager.status.licensee)
                    }
                    if let activated = manager.status.activatedAt {
                        LicRow("激活时间", activated.formatted(date: .numeric, time: .shortened))
                    }
                    if let expires = manager.status.expiresAt {
                        LicRow("到期时间", expires.formatted(date: .numeric, time: .shortened))
                        LicRow("剩余天数", "\(manager.daysRemaining) 天")
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)

            if manager.status.licenseType != .community {
                Button("降级为社区版") { manager.deactivate() }
                    .buttonStyle(.bordered).foregroundColor(.red)
            }

            if !manager.isPro && !manager.isExpired {
                Button("升级到专业版") { manager.showActivationSheet = true }
                    .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
    }
}

struct LicRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).font(.system(.body, design: .monospaced)) }
    }
}

// MARK: - 版本对比

struct LicensePlansView: View {
    @Environment(\.studioTheme) private var theme
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(LicenseType.allCases, id: \.rawValue) { license in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(license.rawValue).font(.headline)
                            Spacer()
                            Text(license.price).font(.title3).fontWeight(.bold).foregroundColor(.accentColor)
                        }
                        Text(license.description).font(.caption).foregroundColor(.secondary)
                        Divider()
                        ForEach(license.features, id: \.0) { (feature, supported) in
                            HStack {
                                Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(supported ? .green : .secondary)
                                    .font(.caption)
                                Text(feature).font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(theme.surfaceSecondary)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - 激活

struct LicenseActivateView: View {
    @StateObject private var manager = LicenseManager.shared
    @State private var licenseKey = ""
    @State private var email = ""

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "key.fill").font(.system(size: 48)).foregroundColor(.accentColor)
            Text("激活 Fusion Studio").font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("激活码").font(.subheadline).foregroundColor(.secondary)
                    TextField("输入激活码", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Text("邮箱").font(.subheadline).foregroundColor(.secondary)
                    TextField("输入邮箱地址", text: $email)
                        .textFieldStyle(.roundedBorder)

                    if let error = manager.activationError {
                        Text(error).font(.caption).foregroundColor(.red)
                    }

                    Button(action: { manager.activate(key: licenseKey, email: email) }) {
                        Label("激活", systemImage: "key").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseKey.isEmpty || email.isEmpty)

                    Divider()

                    Text("没有激活码？").font(.subheadline).foregroundColor(.secondary)
                    Button("开始 14 天免费试用") { manager.startTrial() }
                        .buttonStyle(.bordered)

                    Button("购买许可证") { }
                        .buttonStyle(.bordered)
                }
                .padding(8)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - 激活弹窗

struct ActivationSheetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = LicenseManager.shared
    @State private var licenseKey = ""
    @State private var email = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("激活专业版").font(.title2).bold()
            Text("输入激活码解锁全部功能").font(.subheadline).foregroundColor(.secondary)

            TextField("激活码", text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            TextField("邮箱", text: $email)
                .textFieldStyle(.roundedBorder)

            if let error = manager.activationError {
                Text(error).font(.caption).foregroundColor(.red)
            }

            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("激活") {
                    manager.activate(key: licenseKey, email: email)
                    if manager.activationError == nil { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.isEmpty || email.isEmpty)
            }

            Divider()
            Text("或").font(.caption).foregroundColor(.secondary)
            Button("开始 14 天免费试用") {
                manager.startTrial()
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding().frame(width: 320)
    }
}

// MARK: - 授权徽章

struct LicenseBadge: View {
    let type: LicenseType
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type == .community ? "shield" : "shield.checkered")
                .font(.caption)
            Text(type.rawValue).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1)).cornerRadius(6)
    }
    private var color: Color {
        switch type { case .community: return .gray; case .pro: return .blue; case .enterprise: return .purple; case .trial: return .orange }
    }
}