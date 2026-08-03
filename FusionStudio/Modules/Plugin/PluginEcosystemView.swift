import SwiftUI
import os.log

private let log = Logger(subsystem: "com.fusion.studio", category: "PluginEcosystemView")

struct PluginEcosystemView: View {
    @EnvironmentObject var bridge: PluginBridge
    @Environment(\.studioTheme) private var theme
    @State private var selectedTab: Int = 0

    private let tabs = ["插件", "配置", "状态", "Token", "VRAM", "日志", "MCP"]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            tabBar
            ZStack {
                switch selectedTab {
                case 0: PluginCatalogView()
                case 1: PluginConfigView()
                case 2: PluginStatusView()
                case 3: PluginTokenDashboard()
                case 4: PluginVramView()
                case 5: PluginLogViewer()
                case 6: PluginMcpView()
                default: PluginConfigView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            bridge.checkHealth()
            bridge.listPlugins()
            log.info("PluginEcosystemView appeared")
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text("插件生态")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Circle()
                .fill(bridge.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(bridge.isConnected ? "已连接" : "未连接")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
            Button(action: { bridge.listPlugins(); bridge.listStates() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surfaceSecondary)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { idx in
                Button(action: { selectedTab = idx }) {
                    VStack(spacing: 4) {
                        Text(tabs[idx])
                            .font(.system(size: 12, weight: selectedTab == idx ? .semibold : .regular))
                            .foregroundStyle(selectedTab == idx ? theme.accent : theme.textTertiary)
                        Rectangle()
                            .fill(selectedTab == idx ? theme.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .background(theme.surfaceSecondary)
    }
}
