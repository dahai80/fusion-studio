import SwiftUI
import os.log

private let inputLog = Logger(subsystem: "com.fusion.studio", category: "CenteredChatInput")

struct CenteredChatInput: View {
    @Environment(\.studioTheme) private var theme
    @Binding var text: String
    let placeholder: String
    let isCentered: Bool
    let onSend: () -> Void
    var maxLineLimit: Int = 6
    var trailingContent: AnyView?
    var isGenerating: Bool = false

    init(text: Binding<String>,
         placeholder: String = "Message...",
         isCentered: Bool,
         onSend: @escaping () -> Void,
         maxLineLimit: Int = 6,
         trailingContent: AnyView? = nil,
         isGenerating: Bool = false) {
        self._text = text
        self.placeholder = placeholder
        self.isCentered = isCentered
        self.onSend = onSend
        self.maxLineLimit = maxLineLimit
        self.trailingContent = trailingContent
        self.isGenerating = isGenerating
    }

    var body: some View {
        if isCentered {
            centeredLayout
        } else {
            bottomLayout
        }
    }

    private var centeredLayout: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()

            TextEditor(text: $text)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .scrollContentBackground(.hidden)
                .lineLimit(3...maxLineLimit)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingM)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, theme.spacingL + 4)
                            .padding(.vertical, theme.spacingM + 4)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 80, idealHeight: 100)
                .frame(maxWidth: 520)
                .onSubmit { sendIfNotEmpty() }

            HStack(spacing: theme.spacingM) {
                if let trailing = trailingContent {
                    trailing
                }
                Button(action: sendIfNotEmpty) {
                    Image(systemName: isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isGenerating ? theme.textTertiary : (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textQuaternary : theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(!isGenerating && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomLayout: some View {
        HStack(alignment: .bottom, spacing: theme.spacingS) {
            TextEditor(text: $text)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .scrollContentBackground(.hidden)
                .lineLimit(1...maxLineLimit)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, theme.spacingM + 4)
                            .padding(.vertical, theme.spacingS + 4)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 36, idealHeight: 44)
                .onSubmit { sendIfNotEmpty() }

            if let trailing = trailingContent {
                trailing
            }

            Button(action: sendIfNotEmpty) {
                Image(systemName: isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(isGenerating ? theme.textTertiary : (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textQuaternary : theme.accent))
            }
            .buttonStyle(.plain)
            .disabled(!isGenerating && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.toolbarBg)
    }

    private func sendIfNotEmpty() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend()
    }
}
