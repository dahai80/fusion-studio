import SwiftUI
import os.log

private let sessionListLog = Logger(subsystem: "com.fusion.studio", category: "ScienceSessionList")

struct ScienceSessionList: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge
    @State private var hoveredSessionId: String?

    var body: some View {
        VStack(spacing: 0) {
            sessionListHeader
            Rectangle().fill(theme.separator).frame(height: 1)
            pipelineSection
            Rectangle().fill(theme.separator).frame(height: 1)
            sessionListView
            Rectangle().fill(theme.separator).frame(height: 1)
            toolsSection
        }
        .background(theme.sidebarBg)
    }

    private var sessionListHeader: some View {
        HStack {
            Image(systemName: "flask")
                .font(.system(size: 14))
                .foregroundStyle(theme.accent)
            Text("Science")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button {
                scienceBridge.createSession(title: "New Research") { result in
                    if case .failure(let error) = result {
                        sessionListLog.error("Create session failed: \(error.localizedDescription)")
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var pipelineSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("PIPELINES")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingL)
                .padding(.top, theme.spacingS)

            ForEach(sciencePipelineTemplates) { pipeline in
                pipelineRow(pipeline)
            }
        }
        .padding(.bottom, theme.spacingS)
    }

    private func pipelineRow(_ pipeline: SciencePipelineTemplate) -> some View {
        Button {
        } label: {
            HStack(spacing: theme.spacingS) {
                Image(systemName: pipeline.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
                    .frame(width: 20)
                Text(pipeline.name)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingXS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if scienceBridge.sessions.isEmpty {
                    emptyState
                } else {
                    ForEach(scienceBridge.sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "flask")
                .font(.system(size: 24))
                .foregroundStyle(theme.textQuaternary)
            Text("No sessions")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func sessionRow(_ session: ScienceSession) -> some View {
        let isActive = session.id == scienceBridge.currentSession?.id
        let isHovered = hoveredSessionId == session.id
        return Button {
            scienceBridge.selectSession(session)
        } label: {
            HStack(spacing: theme.spacingS) {
                Circle()
                    .fill(isActive ? theme.accent : theme.textTertiary)
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title.isEmpty ? "Untitled" : session.title)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(relativeDate(session.updatedAt))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.10) : (isHovered ? theme.separator.opacity(0.3) : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSessionId = hovering ? session.id : nil
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("DATABASES")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingL)
                .padding(.top, theme.spacingS)

            if scienceBridge.databases.isEmpty {
                Text("No databases available")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
                    .padding(.horizontal, theme.spacingL)
            } else {
                ForEach(scienceBridge.databases) { db in
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "cylinder")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                        Text(db.name)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Spacer()
                        if let count = db.paperCount {
                            Text("\(count)")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, theme.spacingS)
    }

    private func relativeDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
