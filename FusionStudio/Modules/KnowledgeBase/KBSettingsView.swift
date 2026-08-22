// Callers: RAGPipelineView (settings tab). API: FusionConfig for host/port/apiKey. schema: AppStorage fields. user instruction: "完成所有待办任务"

import SwiftUI

struct KBSettingsView: View {
    @ObservedObject private var config = FusionConfig.shared
    @State private var healthStatus: String = "unknown"
    @State private var isChecking = false

    private var healthStatusText: String {
        switch healthStatus {
        case "ok": return I18nManager.shared.t(.kbc_status_ok)
        case "checking": return I18nManager.shared.t(.kbc_status_checking)
        case "error": return I18nManager.shared.t(.kbc_status_unreachable)
        default: return I18nManager.shared.t(.kbc_status_unknown)
        }
    }

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.kbc_section_rag_service)) {
                HStack {
                    TextField(I18nManager.shared.t(.kbc_field_host), text: $config.fusionRagHost)
                        .frame(maxWidth: 120)
                    TextField(I18nManager.shared.t(.kbc_field_port), value: $config.fusionRagPort, format: .number)
                        .frame(maxWidth: 80)
                }
                SecureField(I18nManager.shared.t(.kbc_field_api_key_optional), text: $config.fusionRagApiKey)
                HStack {
                    Text(String(format: I18nManager.shared.t(.kbc_label_service_url), config.fusionRagURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(I18nManager.shared.t(.kbc_btn_check_conn)) {
                        checkHealth()
                    }
                    .disabled(isChecking)
                }
                HStack {
                    Circle()
                        .fill(healthStatus == "ok" ? .green : (healthStatus == "unknown" ? .gray : .red))
                        .frame(width: 10, height: 10)
                    Text(healthStatusText)
                        .font(.caption)
                }
            }

            Section(I18nManager.shared.t(.kbc_section_embed_model)) {
                TextField(I18nManager.shared.t(.kbc_field_default_model), text: $config.fusionRagEmbed)
                    .help(I18nManager.shared.t(.kbc_help_embed_model))
            }

            Section(I18nManager.shared.t(.kbc_section_advanced)) {
                Toggle(I18nManager.shared.t(.kbc_toggle_rewrite), isOn: .constant(true))
                Toggle(I18nManager.shared.t(.kbc_toggle_hybrid_search), isOn: .constant(true))
                Toggle(I18nManager.shared.t(.kbc_toggle_reranker), isOn: .constant(true))
                Toggle(I18nManager.shared.t(.kbc_toggle_contextualizer), isOn: .constant(true))
            }

            Section {
                Button(I18nManager.shared.t(.kbc_btn_reset_defaults)) {
                    config.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkHealth() {
        isChecking = true
        healthStatus = "checking"
        Task {
            let ok = await RAGAPIClient.shared.healthCheck()
            await MainActor.run {
                healthStatus = ok ? "ok" : "error"
                isChecking = false
            }
        }
    }
}
