// Callers: SectionContentView (case .projects).
// Affected API: ProjectsPanel (project list with sort/search/New Project), ProjectSortOption enum.
// Data schemas: ProjectWorkspace.recentProjects (RecentProject with name/path/gitURL/lastOpened).
// User instruction: "点击Projects。顶端左侧Projects，右侧搜索按钮，Sort by：last updated/Date created/Alphabetical；New Project按钮"

import SwiftUI
import os.log

private let projectsLog = Logger(subsystem: "com.fusion.studio", category: "ProjectsPanel")

enum ProjectSortOption: String, CaseIterable {
    case lastUpdated = "Last Updated"
    case dateCreated = "Date Created"
    case alphabetical = "Alphabetical"
}

struct ProjectsPanel: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var searchText = ""
    @State private var sortOption: ProjectSortOption = .lastUpdated

    private var sortedProjects: [RecentProject] {
        var result = workspace.recentProjects
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOption {
        case .lastUpdated:
            return result.sorted { $0.lastOpened > $1.lastOpened }
        case .dateCreated:
            return result
        case .alphabetical:
            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)

            if sortedProjects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedProjects) { project in
                            projectRow(project)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Text("Projects")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Spacer()

            Button(action: { }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Search Projects")

            Menu {
                ForEach(ProjectSortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Sort by:")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Text(sortOption.rawValue)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Button(action: { workspace.openLocalFolder() }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconXS))
                    Text("New Project")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            Text("Looking to start a project?")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Text("Upload materials, set custom instructions, and organize conversations in one space.")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button(action: { workspace.openLocalFolder() }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                    Text("New Project")
                        .font(.system(size: theme.textSize, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectRow(_ project: RecentProject) -> some View {
        Button(action: { workspace.openRecent(project) }) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        Text(project.path)
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)

                        if project.gitURL != nil {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textQuaternary)
                        }
                    }
                }

                Spacer()

                Text(relativeTime(project.lastOpened))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
