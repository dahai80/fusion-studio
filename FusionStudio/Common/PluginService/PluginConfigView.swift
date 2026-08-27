import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Config View (#79)

struct PluginConfigView: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var editingKey: String?
    @State private var editingValue: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(I18nManager.shared.t(.psvc_cfg_title))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { Task { await pm.fetchEcosystemConfig() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(I18nManager.shared.t(.psvc_cfg_refresh))
                }

                if pm.ecosystemConfig.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(I18nManager.shared.t(.psvc_cfg_empty))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(Array(pm.ecosystemConfig.keys.sorted()), id: \.self) { key in
                        configRow(key: key, value: pm.ecosystemConfig[key])
                    }
                }
            }
            .padding(16)
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchEcosystemConfig() } }
    }

    private func configRow(key: String, value: Any?) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(theme.accent)
                .frame(width: 200, alignment: .leading)
            Spacer()
            if editingKey == key {
                TextField(I18nManager.shared.t(.psvc_cfg_value_ph), text: $editingValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 200)
                Button(I18nManager.shared.t(.psvc_cfg_save)) {
                    let val: Any = editingValue.lowercased() == "true" ? true :
                                  editingValue.lowercased() == "false" ? false :
                                  (Int(editingValue) as Any?) ?? editingValue
                    Task { await pm.setEcosystemConfig(key, value: val) }
                    editingKey = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(I18nManager.shared.t(.psvc_tmpl_cancel)) { editingKey = nil }
                    .controlSize(.small)
            } else {
                Text(String(describing: value ?? ""))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                Button(I18nManager.shared.t(.psvc_cfg_edit)) {
                    editingKey = key
                    editingValue = String(describing: value ?? "")
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }
}
