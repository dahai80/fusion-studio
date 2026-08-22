// Callers: ModuleDetailView routing.
// Affected API: LicenseView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 许可证类型

enum LicenseType: String, CaseIterable {
    case community
    case pro
    case enterprise
    case trial

    var localizedName: String {
        switch self {
        case .community:  return I18nManager.shared.t(.lic_type_community)
        case .pro:        return I18nManager.shared.t(.lic_type_pro)
        case .enterprise: return I18nManager.shared.t(.lic_type_enterprise)
        case .trial:      return I18nManager.shared.t(.lic_type_trial)
        }
    }
    var description: String {
        switch self {
        case .community:  return I18nManager.shared.t(.lic_desc_community)
        case .pro:        return I18nManager.shared.t(.lic_desc_pro)
        case .enterprise: return I18nManager.shared.t(.lic_desc_enterprise)
        case .trial:      return I18nManager.shared.t(.lic_desc_trial)
        }
    }
    var price: String {
        switch self {
        case .community:  return I18nManager.shared.t(.lic_price_community)
        case .pro:        return I18nManager.shared.t(.lic_price_pro)
        case .enterprise: return I18nManager.shared.t(.lic_price_enterprise)
        case .trial:      return I18nManager.shared.t(.lic_price_trial)
        }
    }
    var features: [(String, Bool)] {
        switch self {
        case .community:
            return [(I18nManager.shared.t(.lic_feat_mlx), true), (I18nManager.shared.t(.lic_feat_design_code_sim), true), (I18nManager.shared.t(.lic_feat_env_check), true), (I18nManager.shared.t(.lic_feat_rag), true), (I18nManager.shared.t(.lic_feat_orchestrate), true), (I18nManager.shared.t(.lic_feat_multimodal), false), (I18nManager.shared.t(.lic_feat_training), false), (I18nManager.shared.t(.lic_feat_team_collab), false), (I18nManager.shared.t(.lic_feat_ops), false), (I18nManager.shared.t(.lic_feat_commercial), false)]
        case .pro:
            return [(I18nManager.shared.t(.lic_feat_mlx), true), (I18nManager.shared.t(.lic_feat_design_code_sim), true), (I18nManager.shared.t(.lic_feat_env_check), true), (I18nManager.shared.t(.lic_feat_rag), true), (I18nManager.shared.t(.lic_feat_orchestrate), true), (I18nManager.shared.t(.lic_feat_multimodal), true), (I18nManager.shared.t(.lic_feat_training), true), (I18nManager.shared.t(.lic_feat_team_collab), false), (I18nManager.shared.t(.lic_feat_ops), true), (I18nManager.shared.t(.lic_feat_commercial), false)]
        case .enterprise:
            return [(I18nManager.shared.t(.lic_feat_mlx), true), (I18nManager.shared.t(.lic_feat_design_code_sim), true), (I18nManager.shared.t(.lic_feat_env_check), true), (I18nManager.shared.t(.lic_feat_rag), true), (I18nManager.shared.t(.lic_feat_orchestrate), true), (I18nManager.shared.t(.lic_feat_multimodal), true), (I18nManager.shared.t(.lic_feat_training), true), (I18nManager.shared.t(.lic_feat_team_collab), true), (I18nManager.shared.t(.lic_feat_ops), true), (I18nManager.shared.t(.lic_feat_commercial), true)]
        case .trial:
            return [(I18nManager.shared.t(.lic_feat_mlx), true), (I18nManager.shared.t(.lic_feat_design_code_sim), true), (I18nManager.shared.t(.lic_feat_env_check), true), (I18nManager.shared.t(.lic_feat_rag), true), (I18nManager.shared.t(.lic_feat_orchestrate), true), (I18nManager.shared.t(.lic_feat_multimodal), true), (I18nManager.shared.t(.lic_feat_training), true), (I18nManager.shared.t(.lic_feat_team_collab), true), (I18nManager.shared.t(.lic_feat_ops), true), (I18nManager.shared.t(.lic_feat_commercial), true)]
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
            activationError = I18nManager.shared.t(.lic_err_invalid)
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
        case overview
        case plans
        case activate

        var localizedName: String {
            switch self {
            case .overview: return I18nManager.shared.t(.lic_tab_overview)
            case .plans:    return I18nManager.shared.t(.lic_tab_plans)
            case .activate: return I18nManager.shared.t(.lic_tab_activate)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(I18nManager.shared.t(.lic_header), systemImage: "key.fill").font(.headline)
                Spacer()
                LicenseBadge(type: manager.status.licenseType)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(LicenseTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
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

            Text(manager.status.licenseType.localizedName)
                .font(.largeTitle).bold()

            Text(manager.status.licenseType.description)
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider().frame(width: 200)

            GroupBox(I18nManager.shared.t(.lic_label_activation_info)) {
                VStack(alignment: .leading, spacing: 6) {
                    LicRow(I18nManager.shared.t(.lic_label_status), manager.isExpired ? I18nManager.shared.t(.lic_val_expired) : I18nManager.shared.t(.lic_val_valid))
                    LicRow(I18nManager.shared.t(.lic_label_version), manager.status.licenseType.localizedName)
                    LicRow(I18nManager.shared.t(.lic_label_device_id), manager.status.deviceId)
                    if !manager.status.licensee.isEmpty {
                        LicRow(I18nManager.shared.t(.lic_label_licensee), manager.status.licensee)
                    }
                    if let activated = manager.status.activatedAt {
                        LicRow(I18nManager.shared.t(.lic_label_activated_at), activated.formatted(date: .numeric, time: .shortened))
                    }
                    if let expires = manager.status.expiresAt {
                        LicRow(I18nManager.shared.t(.lic_label_expires_at), expires.formatted(date: .numeric, time: .shortened))
                        LicRow(I18nManager.shared.t(.lic_label_days_remaining), I18nManager.shared.tf(.lic_fmt_days, manager.daysRemaining))
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)

            if manager.status.licenseType != .community {
                Button(I18nManager.shared.t(.lic_btn_deactivate)) { manager.deactivate() }
                    .buttonStyle(.bordered).foregroundColor(.red)
            }

            if !manager.isPro && !manager.isExpired {
                Button(I18nManager.shared.t(.lic_btn_upgrade_pro)) { manager.showActivationSheet = true }
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
                            Text(license.localizedName).font(.headline)
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
            Text(I18nManager.shared.t(.lic_form_activate_title)).font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(I18nManager.shared.t(.lic_form_code_label)).font(.subheadline).foregroundColor(.secondary)
                    TextField(I18nManager.shared.t(.lic_form_code_ph), text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Text(I18nManager.shared.t(.lic_form_email_label)).font(.subheadline).foregroundColor(.secondary)
                    TextField(I18nManager.shared.t(.lic_form_email_ph), text: $email)
                        .textFieldStyle(.roundedBorder)

                    if let error = manager.activationError {
                        Text(error).font(.caption).foregroundColor(.red)
                    }

                    Button(action: { manager.activate(key: licenseKey, email: email) }) {
                        Label(I18nManager.shared.t(.lic_btn_activate), systemImage: "key").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseKey.isEmpty || email.isEmpty)

                    Divider()

                    Text(I18nManager.shared.t(.lic_no_code)).font(.subheadline).foregroundColor(.secondary)
                    Button(I18nManager.shared.t(.lic_btn_start_trial)) { manager.startTrial() }
                        .buttonStyle(.bordered)

                    Button(I18nManager.shared.t(.lic_btn_buy)) { }
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
            Text(I18nManager.shared.t(.lic_sheet_title)).font(.title2).bold()
            Text(I18nManager.shared.t(.lic_sheet_desc)).font(.subheadline).foregroundColor(.secondary)

            TextField(I18nManager.shared.t(.lic_form_code_ph), text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            TextField(I18nManager.shared.t(.lic_form_email_ph), text: $email)
                .textFieldStyle(.roundedBorder)

            if let error = manager.activationError {
                Text(error).font(.caption).foregroundColor(.red)
            }

            HStack {
                Button(I18nManager.shared.t(.lic_btn_cancel)) { dismiss() }.buttonStyle(.bordered)
                Button(I18nManager.shared.t(.lic_btn_activate)) {
                    manager.activate(key: licenseKey, email: email)
                    if manager.activationError == nil { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.isEmpty || email.isEmpty)
            }

            Divider()
            Text(I18nManager.shared.t(.lic_or)).font(.caption).foregroundColor(.secondary)
            Button(I18nManager.shared.t(.lic_btn_start_trial)) {
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
            Text(type.localizedName).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1)).cornerRadius(6)
    }
    private var color: Color {
        switch type { case .community: return .gray; case .pro: return .blue; case .enterprise: return .purple; case .trial: return .orange }
    }
}
