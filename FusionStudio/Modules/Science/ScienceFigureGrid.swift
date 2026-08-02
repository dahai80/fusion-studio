import SwiftUI
import os.log

private let figureLog = Logger(subsystem: "com.fusion.studio", category: "ScienceFigureGrid")

struct ScienceFigureGrid: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            if scienceBridge.figures.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: theme.spacingS) {
                    ForEach(scienceBridge.figures) { figure in
                        figureCard(figure)
                    }
                }
                .padding(theme.spacingM)
            }
        }
        .background(theme.surfaceElevated)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingS) {
            Spacer(minLength: 0)
            Image(systemName: "chart.bar")
                .font(.system(size: 32))
                .foregroundStyle(theme.textQuaternary)
            Text("No figures yet")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Text("Use Visualize to generate charts")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textQuaternary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func figureCard(_ figure: ScienceFigure) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceSecondary)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        Image(systemName: figureIcon(figure.figureType))
                            .font(.system(size: 24))
                            .foregroundStyle(theme.textTertiary)
                    )
            }

            Text(figure.title)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            if let desc = figure.description {
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(theme.spacingXS)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private func figureIcon(_ type: String) -> String {
        switch type {
        case "bar": return "chart.bar.fill"
        case "line": return "chart.line.uptrend.xyaxis"
        case "pie": return "chart.pie.fill"
        case "scatter": return "circle.grid.3x3"
        case "heatmap": return "square.grid.3x3.fill"
        default: return "chart.bar"
        }
    }
}
