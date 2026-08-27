import SwiftUI
import AppKit
import os.log

private let fcLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeView")

// MARK: - Message Content View (markdown code block rendering)

struct FCMessageContentView: View {
    let content: String
    let isStreaming: Bool
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var copiedIndex: Int? = nil

    private struct ContentSegment: Identifiable {
        let id = UUID()
        let isCode: Bool
        let language: String
        let text: String
    }

    private var segments: [ContentSegment] {
        var result: [ContentSegment] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [ContentSegment(isCode: false, language: "", text: content)]
        }
        let nsRange = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: nsRange)
        var lastEnd = content.startIndex
        for match in matches {
            let beforeIdx = content.index(content.startIndex, offsetBy: match.range.location)
            if beforeIdx > lastEnd {
                let before = String(content[lastEnd..<beforeIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty {
                    result.append(ContentSegment(isCode: false, language: "", text: before))
                }
            }
            let lang = (match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound) ?
                (Range(match.range(at: 1), in: content).map { String(content[$0]) } ?? "") : ""
            let code = (match.numberOfRanges > 2) ?
                (Range(match.range(at: 2), in: content).map { String(content[$0]) } ?? "") : ""
            result.append(ContentSegment(isCode: true, language: lang, text: code))
            lastEnd = content.index(content.startIndex, offsetBy: match.range.upperBound)
        }
        if matches.isEmpty {
            result.append(ContentSegment(isCode: false, language: "", text: content))
        } else if lastEnd < content.endIndex {
            let remaining = String(content[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                result.append(ContentSegment(isCode: false, language: "", text: remaining))
            }
        }
        if result.isEmpty {
            result.append(ContentSegment(isCode: false, language: "", text: content))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                if seg.isCode {
                    codeBlockView(seg: seg, index: index)
                } else {
                    Text(seg.text)
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                }
            }
            if isStreaming {
                Text("●")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accent)
                    .opacity(0.7)
            }
        }
    }

    private func codeBlockView(seg: ContentSegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Text(seg.language.isEmpty ? i18n.t(.fc_code) : seg.language)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(seg.text, forType: .string)
                    copiedIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedIndex = nil
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copiedIndex == index ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(copiedIndex == index ? i18n.t(.fc_copied) : i18n.t(.fc_copy))
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.separator.opacity(0.2))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(seg.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.codeBg))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(theme.separator.opacity(0.3), lineWidth: 1)
        )
    }
}
