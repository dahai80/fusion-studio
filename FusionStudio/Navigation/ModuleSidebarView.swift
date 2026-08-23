// Callers: ContentView three-column layout.
// Affected API: ModuleSidebarView (220pt module list for active product sheet).
// Data schemas: Module enum (consumed from AppState).
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

struct ModuleSidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme
    @State private var searchText = ""

    private var filteredModules: [Module] {
        let modules = appState.selectedSheet.modules
        if searchText.isEmpty { return modules }
        return modules.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Rectangle().fill(theme.separator).frame(height: 1)
            moduleList
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
    }

    private var searchField: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.text)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var moduleList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(filteredModules) { module in
                    moduleRow(module: module)
                }
            }
            .padding(.vertical, theme.spacingXS)
        }
    }

    private func moduleRow(module: Module) -> some View {
        let isActive = appState.selectedModule == module
        return Button(action: {
            withAnimation(theme.springSnappy) {
                appState.selectedModule = module
            }
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: module.icon)
                    .font(.system(size: theme.iconS, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color(red: 0 / 255, green: 122 / 255, blue: 1.0) : theme.textTertiary)
                    .frame(width: 18)

                Text(module.localizedName)
                    .font(.system(size: theme.textSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? Color(red: 0 / 255, green: 122 / 255, blue: 1.0).opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
