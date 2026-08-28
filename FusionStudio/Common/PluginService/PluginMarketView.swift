import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Market

struct PluginMarketView: View {
    @Environment(\.studioTheme) private var theme
    let marketItems: [PluginMarketItem] = [
        PluginMarketItem(id: "theme-dark", name: I18nManager.shared.t(.psvc_market_theme_name), author: "Fusion Labs", description: I18nManager.shared.t(.psvc_market_theme_desc), version: "1.2.0", downloads: 1280, rating: 4.5, iconName: "paintpalette", isInstalled: false, hasUpdate: false),
        PluginMarketItem(id: "code-lint", name: I18nManager.shared.t(.psvc_market_lint_name), author: "DevTools", description: I18nManager.shared.t(.psvc_market_lint_desc), version: "0.8.0", downloads: 856, rating: 4.2, iconName: "checkmark.shield", isInstalled: true, hasUpdate: true),
        PluginMarketItem(id: "sim-extra", name: I18nManager.shared.t(.psvc_market_sim_name), author: "SimLab", description: I18nManager.shared.t(.psvc_market_sim_desc), version: "1.0.0", downloads: 2340, rating: 4.8, iconName: "gearshape.2.fill", isInstalled: false, hasUpdate: false),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                ForEach(marketItems) { item in
                    MarketCard(item: item)
                }
            }
            .padding()
        }
    }
}

struct MarketCard: View {
    @Environment(\.studioTheme) private var theme
    let item: PluginMarketItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                if item.hasUpdate {
                    Text(I18nManager.shared.t(.psvc_market_update_badge))
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            Text(item.name)
                .font(.headline)

            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Image(systemName: "person")
                    .font(.caption2)
                Text(item.author)
                    .font(.caption2)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("\(item.rating, specifier: "%.1f")")
                    .font(.caption2)
                Text("\u{00b7} \(item.downloads)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("v\(item.version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(item.isInstalled ? (item.hasUpdate ? I18nManager.shared.t(.psvc_market_btn_update) : I18nManager.shared.t(.psvc_market_btn_installed)) : I18nManager.shared.t(.psvc_market_btn_install)) {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(item.isInstalled && !item.hasUpdate)
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}
