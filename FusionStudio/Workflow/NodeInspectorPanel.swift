import SwiftUI
import os.log

// #425 P1-5: 类型驱动 inline InspectorPanel (plan §7.2)。
//   由 NodeDefinition.configSchema 渲染表单: string/int/bool/dropdown/secret/multiline/modelHandle。
//   secret 值仅存 Keychain, 持久化 JSON 里是 "<keychain:KEY>" 占位符 (langflow strip_secret_field_values 模式)。
//   advanced 字段折叠; showIfKey/showIfValue 动态字段; 卡片 summary = 首个非 advanced 字段值。

private let inspectorLog = Logger(subsystem: "com.fusion.studio", category: "NodeInspector")

enum SecretStore {
    // Keychain account 前缀避免与其他模块键冲突
    private static let prefix = "fusion.flow.secret."

    static func read(_ key: String) -> String? {
        KeychainStore.get(prefix + key)
    }

    static func write(_ key: String, _ value: String) {
        let ok = KeychainStore.set(prefix + key, value)
        if !ok {
            inspectorLog.error("keychain write failed key=\(key, privacy: .public)")
        }
    }

    // 持久化 JSON 中的占位符 (落盘前 secret 真值已被替换)
    static func placeholder(_ key: String) -> String { "<keychain:\(key)>" }

    static func isPlaceholder(_ v: String) -> Bool { v.hasPrefix("<keychain:") }
}

enum SecretStripper {
    // 落盘/同步前: config 中 secret 字段真值 → Keychain + 占位符 (验收: secret 绝不出现在持久化 JSON)
    static func strip(config: [String: JSONValue], schema: [ConfigField]) -> [String: JSONValue] {
        var out = config
        for field in schema where field.type == .secret {
            guard let v = out[field.key]?.stringValue, !v.isEmpty, !SecretStore.isPlaceholder(v) else { continue }
            SecretStore.write(field.key, v)
            out[field.key] = .string(SecretStore.placeholder(field.key))
            inspectorLog.info("secret field stripped to keychain: \(field.key, privacy: .public)")
        }
        return out
    }

    // 读回表单: 占位符 → Keychain 真值 (UI 编辑用, 不落盘)
    static func unmask(config: [String: JSONValue], schema: [ConfigField]) -> [String: JSONValue] {
        var out = config
        for field in schema where field.type == .secret {
            if let v = out[field.key]?.stringValue, SecretStore.isPlaceholder(v) {
                let key = String(v.dropFirst("<keychain:".count).dropLast())
                out[field.key] = .string(SecretStore.read(key) ?? "")
            }
        }
        return out
    }

    // 卡片 summary: secret 永不显示真值
    static func summary(config: [String: JSONValue], schema: [ConfigField]) -> String {
        for field in schema where !field.advanced {
            if let v = config[field.key]?.stringValue, !v.isEmpty {
                if field.type == .secret {
                    return "\(field.label): ••••"
                }
                return "\(field.label): \(v)"
            }
        }
        return ""
    }
}

// MARK: - Inspector view

struct NodeInspectorPanel: View {
    @Environment(\.studioTheme) private var theme
    let node: WorkflowNode
    let definition: (any NodeDefinition.Type)?
    let onChange: (WorkflowNode) -> Void

    @State private var showAdvanced = false
    @State private var secretDrafts: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                if let def = definition {
                    header(def)
                    ForEach(visibleFields(def), id: \.key) { field in
                        fieldRow(field, def: def)
                    }
                    if hasAdvanced(def) {
                        Button(showAdvanced ? "Hide advanced" : "Show advanced") {
                            showAdvanced.toggle()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.captionSize))
                        if showAdvanced {
                            ForEach(advancedFields(def), id: \.key) { field in
                                fieldRow(field, def: def)
                            }
                        }
                    }
                } else {
                    Text("No node definition for type '\(node.type.rawValue)'")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingM)
        }
        .frame(width: 280)
        .background(theme.contentBg)
    }

    private func header(_ def: any NodeDefinition.Type) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: def.icon)
                .foregroundStyle(theme.accent)
            Text(def.displayName)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
        }
    }

    private func visibleFields(_ def: any NodeDefinition.Type) -> [ConfigField] {
        def.configSchema.filter { !$0.advanced && isDynamicVisible($0, def) }
    }

    private func advancedFields(_ def: any NodeDefinition.Type) -> [ConfigField] {
        def.configSchema.filter { $0.advanced && isDynamicVisible($0, def) }
    }

    private func hasAdvanced(_ def: any NodeDefinition.Type) -> Bool {
        !advancedFields(def).isEmpty
    }

    private func isDynamicVisible(_ field: ConfigField, _ def: any NodeDefinition.Type) -> Bool {
        guard let key = field.showIfKey, let expected = field.showIfValue else { return true }
        return node.config[key]?.stringValue == expected
    }

    @ViewBuilder
    private func fieldRow(_ field: ConfigField, def: any NodeDefinition.Type) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(field.label + (field.required ? " *" : ""))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            let binding = Binding<String>(
                get: { node.config[field.key]?.stringValue ?? "" },
                set: { update(field: field, value: $0) }
            )

            switch field.type {
            case .bool:
                Toggle("", isOn: Binding<Bool>(
                    get: { node.config[field.key]?.stringValue == "true" },
                    set: { update(field: field, value: $0 ? "true" : "false") }
                ))
                .labelsHidden()
            case .dropdown:
                Picker("", selection: binding) {
                    Text("-").tag("")
                    ForEach(field.options ?? [], id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
            case .secret:
                SecureField("", text: Binding<String>(
                    get: { secretDrafts[field.key] ?? "" },
                    set: { secretDrafts[field.key] = $0; update(field: field, value: $0) }
                ))
                .textFieldStyle(.roundedBorder)
            case .multiline:
                TextEditor(text: binding)
                    .frame(minHeight: 60)
                    .font(.system(size: theme.footnoteSize))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(theme.separator, lineWidth: 0.5)
                    )
            case .int:
                TextField("0", text: binding)
                    .textFieldStyle(.roundedBorder)
            default:
                TextField("", text: binding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func update(field: ConfigField, value: String) {
        var n = node
        n.config[field.key] = .string(value)
        // secret 即时落 Keychain + 占位符 (不进任何持久化路径)
        if field.type == .secret, !value.isEmpty {
            SecretStore.write(field.key, value)
            n.config[field.key] = .string(SecretStore.placeholder(field.key))
        }
        onChange(n)
        inspectorLog.info("config updated node=\(node.id.uuidString.prefix(8)) field=\(field.key, privacy: .public)")
    }
}

// MARK: - Config validation (#427 复用; P1 用于 executor 前置校验)

enum ConfigValidator {
    static func validate(config: [String: JSONValue], schema: [ConfigField]) -> [String] {
        var errors: [String] = []
        for field in schema {
            guard field.required else { continue }
            let v = config[field.key]?.stringValue ?? ""
            if v.isEmpty, field.type != .secret {
                errors.append("missing required field: \(field.key)")
            }
        }
        return errors
    }
}
