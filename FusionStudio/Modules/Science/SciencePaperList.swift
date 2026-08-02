import SwiftUI
import os.log

private let paperLog = Logger(subsystem: "com.fusion.studio", category: "SciencePaperList")

struct SciencePaperList: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge
    @State private var selectedPaper: SciencePaper?

    var body: some View {
        ScrollView {
            if scienceBridge.papers.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(scienceBridge.papers) { paper in
                        paperRow(paper)
                    }
                }
            }
        }
        .background(theme.surfaceElevated)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingS) {
            Spacer(minLength: 0)
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(theme.textQuaternary)
            Text("No papers found")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Text("Use Search to find papers")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textQuaternary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func paperRow(_ paper: SciencePaper) -> some View {
        let isSelected = selectedPaper?.id == paper.id
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(paper.title)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(2)

            HStack(spacing: theme.spacingS) {
                if let authors = paper.authors, !authors.isEmpty {
                    Text(authors)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                if let year = paper.year {
                    Text("\(year)")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if let score = paper.relevanceScore {
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
            }

            if let abstract = paper.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isSelected ? theme.accent.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPaper = isSelected ? nil : paper
        }
    }
}
