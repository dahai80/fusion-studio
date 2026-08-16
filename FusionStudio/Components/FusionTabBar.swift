// Callers: AgentStudioView, SettingsView
// Affected API: FusionTabBar view, FusionTabItem struct
// Data schemas: FusionTabItem (title: String, icon: String, badge: Int?)
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI
import os.log

private let fusionTabBarLog = os.Logger(subsystem: "com.fusion.studio", category: "FusionTabBar")

struct FusionTabItem: Equatable {
    let title: String
    let icon: String
    let badge: Int?

    init(title: String, icon: String, badge: Int? = nil) {
        self.title = title
        self.icon = icon
        self.badge = badge
    }
}

struct FusionTabBar: View {
    @Binding var selected: Int
    let tabs: [FusionTabItem]

    @Environment(\.studioTheme) var theme
    @State private var indicatorWidth: CGFloat = 0
    @State private var indicatorOffset: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                scrollButton(direction: .leading)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                                tabButton(for: tab, at: index)
                                    .id("tab_\(index)")
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: TabBarIndicatorPreferenceKey.self,
                                    value: TabBarIndicatorData(offset: indicatorOffset, width: indicatorWidth)
                                )
                            }
                        )
                    }
                    .onAppear {
                        scrollProxy = proxy
                        fusionTabBarLog.info("FusionTabBar ScrollViewProxy captured")
                    }
                }

                scrollButton(direction: .trailing)
            }

            Rectangle()
                .fill(theme.accent)
                .frame(width: indicatorWidth, height: 2)
                .offset(x: indicatorOffset)
                .animation(theme.springSnappy, value: selected)
        }
        .onChange(of: selected) { _, newIndex in
            fusionTabBarLog.info("FusionTabBar selected changed to \(newIndex)")
            // 选中超出可见区时滚动到位
            withAnimation(theme.springSnappy) {
                scrollProxy?.scrollTo("tab_\(newIndex)", anchor: .center)
            }
        }
    }

    private enum ScrollDirection {
        case leading, trailing
    }

    private func scrollButton(direction: ScrollDirection) -> some View {
        let disabled: Bool
        let icon: String
        let targetIndex: Int
        switch direction {
        case .leading:
            disabled = selected <= 0
            icon = "chevron.left"
            targetIndex = max(0, selected - 1)
        case .trailing:
            disabled = selected >= tabs.count - 1
            icon = "chevron.right"
            targetIndex = min(tabs.count - 1, selected + 1)
        }
        return Button {
            fusionTabBarLog.info("FusionTabBar scroll \(String(describing: direction), privacy: .public) tapped -> index \(targetIndex)")
            withAnimation(theme.springSnappy) {
                selected = targetIndex
                scrollProxy?.scrollTo("tab_\(targetIndex)", anchor: .center)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: theme.iconS, weight: .semibold))
                .foregroundStyle(disabled ? theme.textTertiary : theme.textSecondary)
                .frame(width: 24, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(direction == .leading ? "上一个" : "下一个")
    }

    private func tabButton(for tab: FusionTabItem, at index: Int) -> some View {
        let isSelected = selected == index
        return Button {
            fusionTabBarLog.info("FusionTabBar tab tapped: \(tab.title, privacy: .public) at index \(index)")
            selected = index
        } label: {
            HStack(spacing: theme.spacingS) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: theme.iconM, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)

                    if let badge = tab.badge, badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(theme.accentDestructive))
                            .offset(x: 6, y: -4)
                    }
                }
                Text(tab.title)
                    .font(.system(size: theme.textSize, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            if index == selected {
                                indicatorWidth = geo.size.width
                                indicatorOffset = geo.frame(in: .global).minX - geo.frame(in: .named("tabContainer")).minX
                            }
                        }
                        .onChange(of: selected) { _, newSelected in
                            if index == newSelected {
                                withAnimation(theme.springSnappy) {
                                    indicatorWidth = geo.size.width
                                    indicatorOffset = geo.frame(in: .global).minX - geo.frame(in: .named("tabContainer")).minX
                                }
                            }
                        }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TabBarIndicatorData: Equatable {
    let offset: CGFloat
    let width: CGFloat
}

private struct TabBarIndicatorPreferenceKey: PreferenceKey {
    static let defaultValue = TabBarIndicatorData(offset: 0, width: 0)
    static func reduce(value: inout TabBarIndicatorData, nextValue: () -> TabBarIndicatorData) {
        value = nextValue()
    }
}
