import SwiftUI
import os.log

private let contextLog = Logger(subsystem: "com.fusion.studio", category: "ScienceContextPanel")

struct ScienceContextPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge
    @State private var selectedTab: ContextTab = .papers

    enum ContextTab: String, CaseIterable {
        case papers = "Papers"
        case figures = "Figures"
        case code = "Code"
        case audit = "Audit"

        var icon: String {
            switch self {
            case .papers: return "doc.text"
            case .figures: return "chart.bar"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .audit: return "checkmark.shield"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Rectangle().fill(theme.separator).frame(height: 1)
            tabContent
        }
        .background(theme.surfaceElevated)
    }

    private var tabBar: some View {
        HStack(spacing: theme.spacingS) {
            ForEach(ContextTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? theme.accentText : theme.textSecondary)
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(selectedTab == tab ? theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceSecondary)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .papers:
            SciencePaperList()
        case .figures:
            ScienceFigureGrid()
        case .code:
            ScienceCodePreview()
        case .audit:
            ScienceAuditView()
        }
    }
}
