// Callers: SectionContentView (case .customize).
// Affected API: CustomizePanel (Settings+Customize sidebar with item list), CustomizeSection, CustomizeItem.
// Data schemas: CustomizeSection enum (settings/customize with items arrays), CustomizeItem struct (icon/title/section).
// User instruction: "点击Customize右侧弹出页面，左侧Settings（General/Account/Privacy/billing/Capabilities/Reflect/Time and focus/claude code）和Customize（skills/connectors/plugins/memory）"

import SwiftUI
import os.log

private let customizeLog = Logger(subsystem: "com.fusion.studio", category: "CustomizePanel")

enum CustomizeSection: String, CaseIterable, Identifiable {
    case settings = "Settings"
    case customize = "Customize"

    var id: String { rawValue }

    var items: [CustomizeItem] {
        switch self {
        case .settings:
            return [
                CustomizeItem(icon: "gearshape", title: "General", section: .settings),
                CustomizeItem(icon: "person.circle", title: "Account", section: .settings),
                CustomizeItem(icon: "hand.raised", title: "Privacy", section: .settings),
                CustomizeItem(icon: "creditcard", title: "Billing", section: .settings),
                CustomizeItem(icon: "bolt.horizontal", title: "Capabilities", section: .settings),
                CustomizeItem(icon: "arrow.triangle.2.circlepath", title: "Reflect", section: .settings),
                CustomizeItem(icon: "clock", title: "Time and Focus", section: .settings),
                CustomizeItem(icon: "chevron.left.forwardslash.chevron.right", title: "Claude Code", section: .settings),
            ]
        case .customize:
            return [
                CustomizeItem(icon: "sparkles", title: "Skills", section: .customize),
                CustomizeItem(icon: "link", title: "Connectors", section: .customize),
                CustomizeItem(icon: "puzzlepiece.extension", title: "Plugins", section: .customize),
                CustomizeItem(icon: "brain", title: "Memory", section: .customize),
            ]
        }
    }
}

struct CustomizeItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let section: CustomizeSection
}

struct CustomizePanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject private var config = FusionConfig.shared
    @State private var selectedItem: CustomizeItem? = CustomizeSection.settings.items.first
    @State private var editingApiKey = false
    @State private var apiKeyInput = ""
    @State private var editingMlxEndpoint = false
    @State private var mlxHostInput = ""
    @State private var mlxPortInput = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle().fill(theme.separator).frame(width: 1)

            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(CustomizeSection.allCases) { section in
                    sectionGroup(section)
                }
            }
            .padding(.vertical, theme.spacingM)
        }
        .frame(width: 240)
        .background(theme.surfaceSecondary)
    }

    private func sectionGroup(_ section: CustomizeSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.rawValue.uppercased())
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .kerning(0.5)
                .padding(.horizontal, theme.spacingM)
                .padding(.top, theme.spacingM)
                .padding(.bottom, theme.spacingXS)

            ForEach(section.items) { item in
                itemRow(item)
            }
        }
    }

    private func itemRow(_ item: CustomizeItem) -> some View {
        let isActive = selectedItem?.id == item.id
        return Button(action: {
            selectedItem = item
            customizeLog.info("Selected: \(item.title)")
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: item.icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                    .frame(width: 20)

                Text(item.title)
                    .font(.system(size: theme.textSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if let item = selectedItem {
                HStack {
                    Text(item.title)
                        .font(.system(size: theme.titleSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacing2XL)
                .padding(.vertical, theme.spacingL)

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        detailContent(for: item)
                    }
                    .padding(.horizontal, theme.spacing2XL)
                    .padding(.bottom, theme.spacing2XL)
                }
            } else {
                Text("Select a setting")
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 按条目分发真实设置内容；无后端实现的条目展示「即将上线」(bug6)
    @ViewBuilder
    private func detailContent(for item: CustomizeItem) -> some View {
        switch item.title {
        case "General": generalSettings
        case "Privacy": privacySettings
        case "Account": accountSettings
        default:        comingSoon(item)
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            settingRow("界面语言", "UI Language") {
                Picker("", selection: $config.language) {
                    Text("简体中文").tag("zh-CN")
                    Text("English").tag("en")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            settingRow("离线模式", "仅本地推理，不发起外部请求") {
                Toggle("", isOn: $config.offlineMode)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }
            settingRow("自动启动关键服务", "进入应用时后台拉起 mlx 等上游") {
                Toggle("", isOn: $config.upstreamAutoStartCritical)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }
        }
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            settingRow("离线模式", "启用后不发起任何外部网络请求") {
                Toggle("", isOn: $config.offlineMode)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }
            settingRow("API Key 本地存储", "密钥存放于 ~/.fusion-mlx/settings.json，不上传") {
                Image(systemName: "lock.fill").foregroundStyle(theme.successText)
            }
        }
    }

    private var accountSettings: some View {
        let configured = !config.mlxResolvedApiKey.isEmpty
        return VStack(alignment: .leading, spacing: theme.spacingM) {
            settingRow("MLX API Key", configured ? "已配置" : "未配置") {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: configured ? "checkmark.seal.fill" : "exclamationmark.triangle")
                        .foregroundStyle(configured ? theme.successText : theme.errorText)
                    Button(editingApiKey ? "取消" : "修改") {
                        if editingApiKey {
                            editingApiKey = false
                            apiKeyInput = ""
                        } else {
                            apiKeyInput = ""
                            editingApiKey = true
                        }
                        customizeLog.info("API key edit mode: \(editingApiKey)")
                    }
                    .font(.system(size: theme.captionSize))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }
            }
            if editingApiKey {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    SecureField("输入新的 API Key", text: $apiKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize, design: .monospaced))
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.inputBg)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.inputBorder, lineWidth: 1)
                        }
                    Button("保存") {
                        saveApiKey(apiKeyInput)
                        editingApiKey = false
                        apiKeyInput = ""
                    }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, theme.spacingM)
            }
            settingRow("MLX 端点覆盖", "ON 时使用下方地址，忽略环境变量 (FUSION_MLX_PORT 等)") {
                Toggle("", isOn: $config.mlxEndpointOverrideEnabled)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }
            if config.mlxEndpointOverrideEnabled {
                settingRow("MLX Host", "直连 MLX 服务地址 (默认 localhost，非 gateway)") {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: editingMlxEndpoint ? "checkmark.seal.fill" : "pencil")
                            .foregroundStyle(editingMlxEndpoint ? theme.successText : theme.accent)
                        Button(editingMlxEndpoint ? "完成" : "修改") {
                            if editingMlxEndpoint {
                                saveMlxEndpoint(mlxHostInput, mlxPortInput)
                                editingMlxEndpoint = false
                            } else {
                                mlxHostInput = config.mlxHost
                                mlxPortInput = String(config.mlxPort)
                                editingMlxEndpoint = true
                            }
                            customizeLog.info("MLX endpoint edit mode: \(editingMlxEndpoint)")
                        }
                        .font(.system(size: theme.captionSize))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                    }
                }
                if editingMlxEndpoint {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        TextField("Host (如 localhost / 127.0.0.1)", text: $mlxHostInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: theme.textSize, design: .monospaced))
                            .padding(theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.inputBg)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }
                        TextField("Port (如 11434)", text: $mlxPortInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: theme.textSize, design: .monospaced))
                            .padding(theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.inputBg)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }
                        Button("保存") {
                            saveMlxEndpoint(mlxHostInput, mlxPortInput)
                            editingMlxEndpoint = false
                        }
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .disabled(mlxHostInput.trimmingCharacters(in: .whitespaces).isEmpty
                                  || Int(mlxPortInput) == nil || (Int(mlxPortInput) ?? 0) <= 0)
                    }
                    .padding(.leading, theme.spacingM)
                }
            }
        }
    }

    private func saveApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // 审计0827 P0-4: 旧实现明文写 ~/.fusion-mlx/settings.json 默认 0644, 且清空 Keychain
        // (config.mlxApiKey="") → studio 端读 Keychain 落空, 只能退读明文文件 = HIGH-2 漏主 key。
        // 修复: (1) 主落 Keychain (studio 读源 = 优先级 1, 不再依赖明文文件);
        //       (2) 仍写 settings.json 供 fusion-mlx 守护读 (上游 _resolve_api_key 契约),
        //           但收紧权限 0600 (owner-only), 杜绝 group/other 读明文密钥。
        let settingsPath = NSHomeDirectory() + "/.fusion-mlx/settings.json"
        let url = URL(fileURLWithPath: settingsPath)
        do {
            var settings: [String: Any] = [:]
            if let data = try? Data(contentsOf: url),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = existing
            }
            var auth = settings["auth"] as? [String: Any] ?? [:]
            auth["api_key"] = trimmed
            settings["auth"] = auth
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: url, options: .atomic)
            // 收紧明文文件权限: owner-only 0600 (默认 .atomic 落 0644, 泄 group/other)。
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsPath)
            // 主落 Keychain: studio 读源走 FusionConfig.mlxResolvedApiKey 优先级 1 (Keychain),
            // 明文文件仅作 fusion-mlx 守护的回退读源, 权限已锁。
            config.mlxApiKey = trimmed
            customizeLog.info("API key saved: Keychain (primary) + settings.json 0600 (upstream daemon), config refreshed")
        } catch {
            customizeLog.error("Failed to save API key: \(error.localizedDescription)")
        }
    }

    private func saveMlxEndpoint(_ host: String, _ port: String) {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty, let portInt = Int(trimmedPort), portInt > 0 else {
            customizeLog.error("saveMlxEndpoint: invalid input host=\(trimmedHost) port=\(trimmedPort), skip")
            return
        }
        config.mlxHost = trimmedHost
        config.mlxPort = portInt
        // #380: 显式开启覆盖，使 mlxBaseURL 用 @AppStorage host:port 忽略 env
        config.mlxEndpointOverrideEnabled = true
        customizeLog.info("MLX endpoint saved: \(trimmedHost):\(portInt) override=on (env ignored)")
    }

    private func comingSoon(_ item: CustomizeItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(item.title)
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)
            Text("该模块即将上线，敬请期待")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceSecondary)
        )
    }

    private func settingRow<C: View>(_ title: String, _ desc: String, @ViewBuilder control: () -> C) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: theme.textSize, weight: .medium)).foregroundStyle(theme.text)
                Text(desc).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            control()
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceSecondary)
        )
    }
}
