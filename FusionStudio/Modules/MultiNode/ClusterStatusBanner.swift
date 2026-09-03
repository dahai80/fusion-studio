import SwiftUI
import os.log

private let bannerLog = Logger(subsystem: "com.fusion.studio", category: "ClusterStatusBanner")

struct ClusterStatusBanner: View {
    @ObservedObject var engine: MultiNodeEngine
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if engine.splitBrainDetected {
                banner(color: .red, title: i18n.t(.mn_banner_splitBrainTitle),
                       msg: i18n.t(.mn_banner_splitBrainMsg))
            } else if engine.nodesStale {
                banner(color: .orange, title: i18n.t(.mn_banner_staleTitle),
                       msg: i18n.t(.mn_banner_staleMsg))
            } else if !engine.isConnected {
                banner(color: .orange, title: i18n.t(.mn_banner_disconnectedTitle),
                       msg: engine.lastError ?? i18n.t(.mn_banner_disconnectedMsg))
            }
        }
    }

    private func banner(color: Color, title: String, msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(msg).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(color.opacity(0.12))
        .cornerRadius(6)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
