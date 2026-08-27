import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

// MARK: - Page 7.6: 产物管理

struct SpaceArtifactPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @Binding var selectedArtifact: SpaceArtifact?
    @State private var artifacts: [SpaceArtifact] = []
    @State private var isLoading = false
    @State private var kindFilter: String = "all"
    @State private var showCreateDialog = false
    @State private var newArtName = ""
    @State private var newArtKind = "code"
    @State private var newArtDesc = ""

    private let kinds = ["all", "code", "doc", "visualization", "data"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_art_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadArtifacts() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingXS) {
                    ForEach(kinds, id: \.self) { kind in
                        Button(action: { kindFilter = kind }) {
                            Text(kindLabel(kind))
                                .font(.system(size: 9, weight: kindFilter == kind ? .semibold : .regular))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(kindFilter == kind ? theme.accent.opacity(0.15) : Color.clear)
                                )
                                .foregroundStyle(kindFilter == kind ? theme.accent : theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacingM)
            }

            if isLoading {
                ProgressView().padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(filteredArtifacts) { art in
                            artifactRow(art)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .onAppear { loadArtifacts() }
        .alert(i18n.t(.cw_art_createTitle), isPresented: $showCreateDialog) {
            TextField(i18n.t(.cw_snap2_namePh), text: $newArtName)
            Picker(i18n.t(.cw_art_kindPicker), selection: $newArtKind) {
                Text(i18n.t(.cw_art_kindCode)).tag("code")
                Text(i18n.t(.cw_art_kindDoc)).tag("doc")
                Text(i18n.t(.cw_art_kindViz)).tag("visualization")
                Text(i18n.t(.cw_art_kindData)).tag("data")
            }
            TextField(i18n.t(.cw_create_descPh), text: $newArtDesc)
            Button(i18n.t(.cw_create_btn)) { createArtifact() }
            Button(i18n.t(.cancel), role: .cancel) { }
        }
    }

    private var filteredArtifacts: [SpaceArtifact] {
        if kindFilter == "all" { return artifacts }
        return artifacts.filter { $0.kind == kindFilter }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "all": return i18n.t(.cw_art_kindAll)
        case "code": return i18n.t(.cw_art_kindCode)
        case "doc": return i18n.t(.cw_art_kindDoc)
        case "visualization": return i18n.t(.cw_art_kindViz)
        case "data": return i18n.t(.cw_art_kindData)
        default: return kind
        }
    }

    private func artifactIcon(_ kind: String) -> String {
        switch kind {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "shippingbox"
        }
    }

    private func artifactRow(_ art: SpaceArtifact) -> some View {
        Button(action: { selectedArtifact = art }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: artifactIcon(art.kind))
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(selectedArtifact?.id == art.id ? theme.accent : theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(art.name)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .lineLimit(1)
                    Text(kindLabel(art.kind))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if selectedArtifact?.id == art.id {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(selectedArtifact?.id == art.id ? theme.accent.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func createArtifact() {
        Task {
            do {
                _ = try await ipc.spaceArtifactCreate(
                    spaceId: spaceId, name: newArtName, kind: newArtKind, description: newArtDesc
                )
                newArtName = ""; newArtDesc = ""
                loadArtifacts()
            } catch {
                spaceLog.error("artifact.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadArtifacts() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceArtifactList(spaceId: spaceId, kind: kindFilter == "all" ? nil : kindFilter)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                await MainActor.run { artifacts = items.map { SpaceArtifact.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("artifact.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

