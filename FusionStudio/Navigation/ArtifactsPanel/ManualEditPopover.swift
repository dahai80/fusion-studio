import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct ManualEditPopover: View {
    @Environment(\.studioTheme) private var theme
    @Binding var name: String
    @Binding var content: String
    let template: ArtifactTemplate

    var body: some View {
        VStack(spacing: theme.spacingM) {
            TextField("Artifact name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 200)
        }
        .padding(theme.spacingM)
        .frame(width: 400, height: 300)
    }
}

// MARK: - CreateArtifactSheet (manual fallback)

