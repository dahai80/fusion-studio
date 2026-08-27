import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct RAGConfigSheet: View {
    let projectId: String
    @Binding var ragMode: RAGMode
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var ragTopK: Int = 5
    @State private var ragThreshold: Double = 0.5
    @State private var isSaving = false
    @State private var showScopeSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text(i18n.t(.proj_ragConfigTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_ragConfigMode))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $ragMode) {
                    Text(i18n.t(.proj_createRagAuto)).tag(RAGMode.AUTO)
                    Text(i18n.t(.proj_createRagManual)).tag(RAGMode.MANUAL)
                    Text(i18n.t(.proj_inputRagOff)).tag(RAGMode.OFF)
                }
                .pickerStyle(.segmented)
                .font(.system(size: theme.captionSize))
            }

            if ragMode != .OFF {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(String(format: i18n.t(.proj_ragConfigTopKFmt), ragTopK))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                    }
                    Slider(value: Binding(
                        get: { Double(ragTopK) },
                        set: { ragTopK = Int($0) }
                    ), in: 1...20, step: 1)
                    .tint(theme.accent)
                }

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(String(format: i18n.t(.proj_ragConfigThresholdFmt), String(format: "%.2f", ragThreshold)))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                    }
                    Slider(value: $ragThreshold, in: 0.1...0.99, step: 0.05)
                        .tint(theme.accent)
                }
            }

            if ragMode == .MANUAL {
                Button(action: { showScopeSelector = true }) {
                    Label(i18n.t(.proj_ragConfigSelectScope), systemImage: "folder.badge.plus")
                }
                .font(.system(size: theme.footnoteSize))
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Button(i18n.t(.save)) { saveConfig() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                    .disabled(isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 420)
        .onAppear { loadCurrentConfig() }
        .sheet(isPresented: $showScopeSelector) {
            RAGScopeSelector(projectId: projectId, ragMode: $ragMode)
        }
    }

    private func loadCurrentConfig() {
        Task {
            do {
                let r = try await ipc.projectRagConfigGet(projectId: projectId)
                let topK = r["top_k"] as? Int ?? r["rag_top_k"] as? Int ?? 5
                let threshold = r["threshold"] as? Double ?? r["rag_threshold"] as? Double ?? 0.5
                await MainActor.run { ragTopK = topK; ragThreshold = threshold }
            } catch {
                projLog.error("RAGConfigSheet load failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveConfig() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectRagConfigSet(projectId: projectId, ragMode: ragMode.rawValue,
                                                       ragTopK: ragTopK, ragThreshold: ragThreshold)
                projLog.info("RAGConfig saved for project \(projectId)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("RAGConfig save failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - GUI-9: Project Settings Panel

