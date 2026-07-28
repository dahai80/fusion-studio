// Callers: RAGPipelineView (settings tab). API: FusionConfig for host/port/apiKey. schema: AppStorage fields. user instruction: "完成所有待办任务"

import SwiftUI

struct KBSettingsView: View {
    @ObservedObject private var config = FusionConfig.shared
    @State private var healthStatus: String = "未检测"
    @State private var isChecking = false

    var body: some View {
        Form {
            Section("Fusion-RAG 服务") {
                HStack {
                    TextField("主机", text: $config.fusionRagHost)
                        .frame(maxWidth: 120)
                    TextField("端口", value: $config.fusionRagPort, format: .number)
                        .frame(maxWidth: 80)
                }
                SecureField("API Key (可选)", text: $config.fusionRagApiKey)
                HStack {
                    Text("服务地址: \(config.fusionRagURL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("检测连接") {
                        checkHealth()
                    }
                    .disabled(isChecking)
                }
                HStack {
                    Circle()
                        .fill(healthStatus == "正常" ? .green : (healthStatus == "未检测" ? .gray : .red))
                        .frame(width: 10, height: 10)
                    Text(healthStatus)
                        .font(.caption)
                }
            }

            Section("嵌入模型") {
                TextField("默认模型", text: $config.fusionRagEmbed)
                    .help("如 BGE-M3, text-embedding-3-small 等")
            }

            Section("高级") {
                Toggle("启用查询重写", isOn: .constant(true))
                Toggle("启用混合搜索 (BM25 + 向量)", isOn: .constant(true))
                Toggle("启用 Reranker", isOn: .constant(true))
                Toggle("启用上下文增强 (Contextualizer)", isOn: .constant(true))
            }

            Section {
                Button("重置为默认值") {
                    config.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkHealth() {
        isChecking = true
        healthStatus = "检测中..."
        Task {
            let ok = await RAGAPIClient.shared.healthCheck()
            await MainActor.run {
                healthStatus = ok ? "正常" : "无法连接"
                isChecking = false
            }
        }
    }
}
