import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct EditContentSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel
    let onComplete: (Bool) -> Void

    @State private var content = ""
    @State private var changeLog = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Edit: \(artifact.name)")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Form {
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 250)
                TextField("Change log (optional)", text: $changeLog)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Save New Version") { saveVersion() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(content.isEmpty || isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 440)
        .onAppear { loadCurrentContent() }
    }

    private func loadCurrentContent() {
        Task {
            do {
                let result = try await ipcClient.artifactGetContent(artifactId: artifact.id)
                if let c = result["content"] as? String { content = c }
            } catch {
                artifactsLog.error("loadCurrentContent: \(error)")
            }
        }
    }

    private func saveVersion() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipcClient.artifactUpdate(
                    artifactId: artifact.id, content: content,
                    changeLog: changeLog.isEmpty ? nil : changeLog,
                    projectId: FusionProjectManager.shared.activeProject?.id
                )
                artifactsLog.info("Updated artifact \(self.artifact.id)")
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("saveVersion: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - VersionHistorySheet

