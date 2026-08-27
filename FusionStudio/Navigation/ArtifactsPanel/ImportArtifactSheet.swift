import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct ImportArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let onComplete: (Bool) -> Void

    @State private var importText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Import Artifact")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Text("Paste exported artifact JSON below:")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)

            TextEditor(text: $importText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 200)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Import") { doImport() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(importText.isEmpty || isImporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 380)
    }

    private func doImport() {
        isImporting = true
        errorMessage = nil
        guard let jsonData = importText.data(using: .utf8),
              let dataDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            errorMessage = "Invalid JSON"
            isImporting = false
            return
        }
        Task {
            do {
                _ = try await ipcClient.artifactImport(data: dataDict)
                artifactsLog.info("Imported artifact successfully")
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
                artifactsLog.error("doImport: \(error)")
            }
            isImporting = false
        }
    }
}

// MARK: - InjectPreviewSheet

