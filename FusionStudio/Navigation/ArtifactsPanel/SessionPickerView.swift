import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct SessionPickerView: View {
    @Environment(\.studioTheme) private var theme
    @Binding var currentSession: String
    @State private var newSession = ""

    private let presetSessions = ["default", "workspace", "sandbox"]

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("Switch Session")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            ForEach(presetSessions, id: \.self) { session in
                HStack {
                    Text(session)
                        .foregroundStyle(theme.text)
                    Spacer()
                    if session == currentSession {
                        Image(systemName: "checkmark")
                            .foregroundStyle(theme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { currentSession = session }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
            }

            Divider()

            HStack {
                TextField("Custom session", text: $newSession)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !newSession.isEmpty {
                            currentSession = newSession
                            newSession = ""
                        }
                    }
                Button("Go") {
                    if !newSession.isEmpty {
                        currentSession = newSession
                        newSession = ""
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingM)
        }
        .padding(theme.spacingM)
        .frame(width: 220)
    }
}
