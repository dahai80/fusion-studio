import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct InjectPreviewSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    @State private var messagesText = ""
    @State private var isSafe: Bool?
    @State private var currentTokens: Int?
    @State private var remainingTokens: Int?
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Safety Check Preview")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            TextEditor(text: $messagesText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    Group {
                        if messagesText.isEmpty {
                            Text("Paste messages JSON array here...")
                                .foregroundStyle(theme.textTertiary)
                                .padding(.top, 8).padding(.leading, 4)
                        }
                    }, alignment: .topLeading
                )

            Button("Check Safety") { runCheck() }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.accent)
                )
                .disabled(messagesText.isEmpty || isRunning)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            if let safe = isSafe {
                HStack(spacing: theme.spacingM) {
                    Label(safe ? "Safe" : "Unsafe",
                          systemImage: safe ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundStyle(safe ? .green : .red)
                    if let current = currentTokens, let remaining = remainingTokens {
                        Text("Current: \(current) tok | Remaining: \(remaining) tok")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 460)
    }

    private func runCheck() {
        isRunning = true
        errorMessage = nil
        guard let data = messagesText.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            errorMessage = "Invalid messages JSON"
            isRunning = false
            return
        }
        Task {
            do {
                let result = try await ipcClient.artifactCheckSafety(messages: messages)
                isSafe = result["safe"] as? Bool
                currentTokens = result["current_tokens"] as? Int
                remainingTokens = result["remaining_tokens"] as? Int
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("runCheck: \(error)")
            }
            isRunning = false
        }
    }
}

// MARK: - SessionPickerView

