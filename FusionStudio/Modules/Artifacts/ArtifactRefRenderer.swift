import SwiftUI
import os.log

private let log = Logger(subsystem: "com.fusion.studio", category: "ArtifactRefRenderer")

struct ArtifactRefRenderer: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let artifactId: String
    @State private var content: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(theme.danger)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.danger)
                }
                .padding(8)
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
        }
        .frame(maxHeight: 300)
        .background(theme.cardBackground)
        .cornerRadius(8)
        .onAppear { loadContent() }
    }

    private func loadContent() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let result = try await ipc.artifactLoad(artifactId: artifactId)
                DispatchQueue.main.async {
                    self.content = result["content"] as? String ?? ""
                    self.isLoading = false
                }
            } catch {
                log.error("ArtifactRefRenderer load failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMsg = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
