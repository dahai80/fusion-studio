import SwiftUI

// MARK: - Workflow & Artifact Marketplace (D8)

struct SpaceMarketplaceView: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTab = 0
    @State private var workflows: [MarketplaceItem] = []
    @State private var artifacts: [MarketplaceItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_mkt_title))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingM)

            Picker(i18n.t(.cw_mkt_type), selection: $selectedTab) {
                Text(i18n.t(.cw_mkt_typeWorkflow)).tag(0)
                Text(i18n.t(.cw_mkt_typeArtifact)).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, theme.spacingM)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: theme.spacingS),
                    GridItem(.flexible(), spacing: theme.spacingS)
                ], spacing: theme.spacingS) {
                    ForEach(selectedTab == 0 ? workflows : artifacts) { item in
                        marketplaceCard(item)
                    }
                }
                .padding(theme.spacingM)
            }
        }
        .frame(width: 560, height: 480)
        .onAppear { loadSampleData() }
    }

    private func marketplaceCard(_ item: MarketplaceItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: item.icon)
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.accent)
                Spacer()
                Text(i18n.t(item.category))
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(theme.accent)
            }
            Text(i18n.t(item.name))
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(i18n.t(item.description))
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(2)
            HStack {
                Label("\(item.useCount)", systemImage: "arrow.down.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button(i18n.t(.cw_mkt_install)) { }
                    .font(.system(size: 9, weight: .medium))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceSecondary)
        )
    }

    private func loadSampleData() {
        workflows = [
            MarketplaceItem(name: "spl_mkt_name_code_review", description: "spl_mkt_desc_code_review", icon: "arrow.triangle.branch", category: "spl_mkt_cat_dev", useCount: 128),
            MarketplaceItem(name: "spl_mkt_name_doc_gen", description: "spl_mkt_desc_doc_gen", icon: "doc.text", category: "spl_mkt_cat_doc", useCount: 95),
            MarketplaceItem(name: "spl_mkt_name_data_analysis", description: "spl_mkt_desc_data_analysis", icon: "chart.bar", category: "spl_mkt_cat_data", useCount: 73),
            MarketplaceItem(name: "spl_mkt_name_multi_translate", description: "spl_mkt_desc_multi_translate", icon: "globe", category: "spl_mkt_cat_translate", useCount: 61),
        ]
        artifacts = [
            MarketplaceItem(name: "spl_mkt_name_react_dashboard", description: "spl_mkt_desc_react_dashboard", icon: "shippingbox", category: "spl_mkt_cat_frontend", useCount: 256),
            MarketplaceItem(name: "spl_mkt_name_api_doc", description: "spl_mkt_desc_api_doc", icon: "doc.text", category: "spl_mkt_cat_doc", useCount: 189),
            MarketplaceItem(name: "spl_mkt_name_data_viz", description: "spl_mkt_desc_data_viz", icon: "chart.bar", category: "spl_mkt_cat_viz", useCount: 142),
            MarketplaceItem(name: "spl_mkt_name_cli_scaffold", description: "spl_mkt_desc_cli_scaffold", icon: "terminal", category: "spl_mkt_cat_tool", useCount: 98),
        ]
    }
}

private struct MarketplaceItem: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let icon: String
    let category: String
    let useCount: Int
}

typealias SpaceSnapshotView = SpaceSnapshotPanel
typealias SpaceArtifactView = SpaceArtifactPanel
typealias SpaceWorkflowView = SpaceWorkflowPanel
typealias SpaceDesktopView = SpaceDesktopPanel
typealias SpaceChatPlaceholder = SpaceSharedChat
