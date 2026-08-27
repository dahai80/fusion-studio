import SwiftUI

// MARK: - Markdown Content View

struct MarkdownContentView: View {
    @Environment(\.studioTheme) private var theme

    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ForEach(parsedBlocks, id: \.id) { block in
                switch block.type {
                case .code:
                    codeBlock(block)
                case .text:
                    inlineText(block.content)
                }
            }
        }
    }

    private enum BlockType { case code, text }
    private struct ContentBlock: Identifiable {
        let id: Int
        let type: BlockType
        let content: String
        let language: String
    }

    private var parsedBlocks: [ContentBlock] {
        var blocks: [ContentBlock] = []
        var idx = 0
        let lines = content.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(ContentBlock(id: idx, type: .code, content: codeLines.joined(separator: "\n"), language: lang))
                idx += 1
                i += 1
            } else {
                var textLines: [String] = [line]
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    textLines.append(lines[i])
                    i += 1
                }
                let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(ContentBlock(id: idx, type: .text, content: text, language: ""))
                    idx += 1
                }
            }
        }
        return blocks
    }

    private func inlineText(_ text: String) -> some View {
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
        }
        return Text(text)
            .font(.system(size: theme.textSize))
            .foregroundStyle(theme.text)
            .textSelection(.enabled)
    }

    private func codeBlock(_ block: ContentBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !block.language.isEmpty {
                    Text(block.language)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(block.content, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(theme.surfaceSecondary.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingS)
            }
        }
        .background(theme.surfaceSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(theme.separator, lineWidth: 0.5)
        )
    }
}

