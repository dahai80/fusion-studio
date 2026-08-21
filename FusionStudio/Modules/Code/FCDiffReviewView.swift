import SwiftUI

struct FCDiffReviewView: View {
    @Environment(\.studioTheme) private var theme
    let original: String
    let modified: String
    let language: String
    let fileName: String

    @State private var viewMode: DiffViewMode = .split
    @State private var showLineNumbers = true
    @StateObject private var i18n = I18nManager.shared

    enum DiffViewMode: String, CaseIterable {
        case split = "Split"
        case unified = "Unified"

        var localLabel: String {
            switch self {
            case .split: return I18nManager.shared.t(.fc_diff_split)
            case .unified: return I18nManager.shared.t(.fc_diff_unified)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            diffToolbar
            Divider()
            switch viewMode {
            case .split:
                splitDiffView
            case .unified:
                unifiedDiffView
            }
        }
    }

    private var diffToolbar: some View {
        HStack(spacing: theme.spacingS) {
            Text(fileName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            Spacer()

            Picker("", selection: $viewMode) {
                ForEach(DiffViewMode.allCases, id: \.self) { mode in
                    Text(mode.localLabel).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Toggle(i18n.t(.fc_diff_line_numbers), isOn: $showLineNumbers)
                .toggleStyle(.checkbox)
                .font(.system(size: 10))
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.toolbarBg)
    }

    private var splitDiffView: some View {
        HStack(spacing: 1) {
            diffPane(title: i18n.t(.fc_original), content: original, color: theme.redDot.opacity(0.1))
            Divider()
            diffPane(title: i18n.t(.fc_modified), content: modified, color: theme.greenDot.opacity(0.1))
        }
    }

    private func diffPane(title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color)

            ScrollView {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var unifiedDiffView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let origLines = original.components(separatedBy: "\n")
                let modLines = modified.components(separatedBy: "\n")
                let maxLines = max(origLines.count, modLines.count)

                ForEach(0..<maxLines, id: \.self) { idx in
                    let origLine = idx < origLines.count ? origLines[idx] : nil
                    let modLine = idx < modLines.count ? modLines[idx] : nil

                    HStack(spacing: 0) {
                        if showLineNumbers {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                                .frame(width: 36, alignment: .trailing)
                                .padding(.trailing, 8)
                        }

                        if let mod = modLine, let orig = origLine {
                            if mod == orig {
                                Text(mod)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.text)
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        Text("-")
                                            .foregroundStyle(.red)
                                        Text(orig)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.red.opacity(0.8))
                                    }
                                    .padding(.vertical, 1)
                                    .padding(.horizontal, 4)
                                    .background(Color.red.opacity(0.08))

                                    HStack(spacing: 4) {
                                        Text("+")
                                            .foregroundStyle(.green)
                                        Text(mod)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.green.opacity(0.8))
                                    }
                                    .padding(.vertical, 1)
                                    .padding(.horizontal, 4)
                                    .background(Color.green.opacity(0.08))
                                }
                            }
                        } else if let orig = origLine {
                            HStack(spacing: 4) {
                                Text("-")
                                    .foregroundStyle(.red)
                                Text(orig)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 4)
                            .background(Color.red.opacity(0.08))
                        } else if let mod = modLine {
                            HStack(spacing: 4) {
                                Text("+")
                                    .foregroundStyle(.green)
                                Text(mod)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 4)
                            .background(Color.green.opacity(0.08))
                        }

                        Spacer()
                    }
                }
            }
            .padding(8)
        }
    }
}
