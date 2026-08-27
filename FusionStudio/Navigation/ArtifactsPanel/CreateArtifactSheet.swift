import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct CreateArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let sessionId: String
    let onComplete: (ArtifactModel?) -> Void

    @State private var name = ""
    @State private var type = "code"
    @State private var kind: ArtifactKind = .code
    @State private var content = ""
    @State private var summary = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let types = ["code", "markdown", "html", "react", "data"]

    init(sessionId: String, onComplete: @escaping (ArtifactModel?) -> Void) {
        self.sessionId = sessionId
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Create Artifact")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text($0.capitalized) }
                }
                TextField("Summary (optional)", text: $summary)
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 200)
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
                Button("Create") { createArtifact() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(name.isEmpty || (content.isEmpty && type != "code") || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 480)
    }

    private func createArtifact() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipcClient.artifactCreate(
                    sessionId: sessionId, name: name, type: type,
                    kind: kind.rawValue,
                    content: content, summary: summary.isEmpty ? nil : summary,
                    projectId: FusionProjectManager.shared.activeProject?.id
                )
                artifactsLog.info("Created artifact: \(self.name)")
                onComplete(nil)
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("createArtifact: \(error)")
            }
            isCreating = false
        }
    }
}

// MARK: - EditContentSheet

