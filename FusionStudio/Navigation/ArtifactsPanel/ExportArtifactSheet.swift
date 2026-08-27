import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct ExportArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel

    @State private var exportedData: String?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Export: \(artifact.name)")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if let data = exportedData {
                ScrollView {
                    Text(data)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .padding(theme.spacingM)
                }
                .frame(maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if exportedData != nil {
                    Button("Copy to Clipboard") {
                        if let data = exportedData {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(data, forType: .string)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }
                Button("Export") { doExport() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(isExporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: exportedData != nil ? 480 : 200)
    }

    private func doExport() {
        isExporting = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipcClient.artifactExport(artifactId: artifact.id)
                if let data = result["data"] as? [String: Any] {
                    exportedData = String(
                        data: try JSONSerialization.data(withJSONObject: data,
                                                          options: [.prettyPrinted, .sortedKeys]),
                        encoding: .utf8
                    )
                }
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                artifactsLog.error("doExport: \(error)")
            }
            isExporting = false
        }
    }
}

// MARK: - ImportArtifactSheet

