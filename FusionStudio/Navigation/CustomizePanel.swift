// Callers: SectionContentView (case .customize).
// Affected API: CustomizePanel (Settings+Customize sidebar with item list), CustomizeSection, CustomizeItem.
// Data schemas: CustomizeSection enum (settings/customize with items arrays), CustomizeItem struct (icon/title/section).
// User instruction: "点击Customize右侧弹出页面，左侧Settings（General/Account/Privacy/billing/Capabilities/Reflect/Time and focus/claude code）和Customize（skills/connectors/plugins/memory）"

import SwiftUI
import os.log

private let customizeLog = Logger(subsystem: "com.fusion.studio", category: "CustomizePanel")

enum CustomizeSection: String, CaseIterable, Identifiable {
    case settings = "Settings"
    case customize = "Customize"

    var id: String { rawValue }

    var items: [CustomizeItem] {
        switch self {
        case .settings:
            return [
                CustomizeItem(icon: "gearshape", title: "General", section: .settings),
                CustomizeItem(icon: "person.circle", title: "Account", section: .settings),
                CustomizeItem(icon: "hand.raised", title: "Privacy", section: .settings),
                CustomizeItem(icon: "creditcard", title: "Billing", section: .settings),
                CustomizeItem(icon: "bolt.horizontal", title: "Capabilities", section: .settings),
                CustomizeItem(icon: "arrow.triangle.2.circlepath", title: "Reflect", section: .settings),
                CustomizeItem(icon: "clock", title: "Time and Focus", section: .settings),
                CustomizeItem(icon: "chevron.left.forwardslash.chevron.right", title: "Claude Code", section: .settings),
            ]
        case .customize:
            return [
                CustomizeItem(icon: "sparkles", title: "Skills", section: .customize),
                CustomizeItem(icon: "link", title: "Connectors", section: .customize),
                CustomizeItem(icon: "puzzlepiece.extension", title: "Plugins", section: .customize),
                CustomizeItem(icon: "brain", title: "Memory", section: .customize),
            ]
        }
    }
}

struct CustomizeItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let section: CustomizeSection
}

struct CustomizePanel: View {
    @Environment(\.studioTheme) private var theme
    @State private var selectedItem: CustomizeItem? = CustomizeSection.settings.items.first

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle().fill(theme.separator).frame(width: 1)

            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(CustomizeSection.allCases) { section in
                    sectionGroup(section)
                }
            }
            .padding(.vertical, theme.spacingM)
        }
        .frame(width: 240)
        .background(theme.surfaceSecondary)
    }

    private func sectionGroup(_ section: CustomizeSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.rawValue.uppercased())
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .kerning(0.5)
                .padding(.horizontal, theme.spacingM)
                .padding(.top, theme.spacingM)
                .padding(.bottom, theme.spacingXS)

            ForEach(section.items) { item in
                itemRow(item)
            }
        }
    }

    private func itemRow(_ item: CustomizeItem) -> some View {
        let isActive = selectedItem?.id == item.id
        return Button(action: {
            selectedItem = item
            customizeLog.info("Selected: \(item.title)")
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: item.icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                    .frame(width: 20)

                Text(item.title)
                    .font(.system(size: theme.textSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if let item = selectedItem {
                HStack {
                    Text(item.title)
                        .font(.system(size: theme.titleSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacing2XL)
                .padding(.vertical, theme.spacingL)

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        ForEach(1...3, id: \.self) { _ in
                            settingPlaceholder(item)
                        }
                    }
                    .padding(.horizontal, theme.spacing2XL)
                    .padding(.bottom, theme.spacing2XL)
                }
            } else {
                Text("Select a setting")
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingPlaceholder(_ item: CustomizeItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Option")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)

            HStack {
                Text("Configure \(item.title) settings here")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Toggle("", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceSecondary)
        )
    }
}
