// Callers: DocView toolbar button, DocEditorArea version panel.
// Affected API: DocBridge fetchVersions, createVersion, fetchDiff, restoreVersion.
// Data schemas: DocVersion, DocDiffLine, DocDiffResult (from DocBridge.swift).
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let versionLog = Logger(subsystem: "com.fusion.studio", category: "DocVersion")

struct DocVersionView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var bridge: DocBridge
    let pageId: String
    @State private var selectedV1: DocVersion?
    @State private var selectedV2: DocVersion?
    @State private var diffResult: DocDiffResult?
    @State private var showDiff = false

    var body: some View {
        VStack(spacing: 0) {
            versionHeader
            Divider()
            if showDiff, diffResult != nil {
                diffPanel
            } else {
                versionList
            }
        }
        .background(theme.surfacePrimary)
        .frame(minWidth: 280, minHeight: 400)
        .onAppear {
            bridge.fetchVersions(pageId: pageId)
        }
    }

    private var versionHeader: some View {
        HStack {
            Text(i18n.t(.doc_ver_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { createSnapshot() }) {
                Label(i18n.t(.doc_ver_snapshot), systemImage: "camera")
                    .font(.caption)
            }
            .help(i18n.t(.doc_ver_snapshotHelp))
            Button(action: { compareSelected() }) {
                Label(i18n.t(.doc_ver_compare), systemImage: "arrow.left.arrow.right")
                    .font(.caption)
            }
            .disabled(selectedV1 == nil || selectedV2 == nil)
            .help(i18n.t(.doc_ver_compareHelp))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var versionList: some View {
        List {
            if bridge.versions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(i18n.t(.doc_ver_empty))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(bridge.versions) { version in
                    versionRow(version)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func versionRow(_ version: DocVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(version.title ?? String(format: i18n.t(.doc_ver_versionFmt), version.version ?? 0))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if let date = version.created_at {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            let isV1 = selectedV1?.id == version.id
            let isV2 = selectedV2?.id == version.id

            if isV1 {
                Text("V1")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(3)
            }
            if isV2 {
                Text("V2")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selectVersion(version)
        }
        .contextMenu {
            Button(i18n.t(.doc_ver_setV1)) {
                selectedV1 = version
            }
            Button(i18n.t(.doc_ver_setV2)) {
                selectedV2 = version
            }
            Divider()
            Button(i18n.t(.doc_ver_restore)) {
                restoreVersion(version)
            }
        }
    }

    private var diffPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { showDiff = false; diffResult = nil }) {
                    Image(systemName: "chevron.left")
                }
                Text(i18n.t(.doc_ver_compareTitle))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: i18n.t(.doc_ver_diffFmt), diffResult?.v1 ?? 0, diffResult?.v2 ?? 0))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let diff = diffResult?.diff {
                        ForEach(Array(diff.enumerated()), id: \.offset) { _, line in
                            diffLineRow(line)
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    private func diffLineRow(_ line: DocDiffLine) -> some View {
        let bgColor: Color = {
            switch line.type {
            case "add": return Color.green.opacity(0.15)
            case "remove": return Color.red.opacity(0.15)
            default: return Color.clear
            }
        }()
        let prefix: String = {
            switch line.type {
            case "add": return "+ "
            case "remove": return "- "
            default: return "  "
            }
        }()
        let textColor: Color = {
            switch line.type {
            case "add": return Color.green
            case "remove": return Color.red
            default: return .primary
            }
        }()

        return HStack(spacing: 0) {
            Text(prefix)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 20)
            Text(line.line)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(textColor)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(bgColor)
    }

    // MARK: - Actions

    private func selectVersion(_ version: DocVersion) {
        if selectedV1 == nil {
            selectedV1 = version
        } else if selectedV2 == nil {
            selectedV2 = version
        } else {
            selectedV1 = selectedV2
            selectedV2 = version
        }
    }

    private func createSnapshot() {
        if let page = bridge.currentPage {
            bridge.createVersion(pageId: page.id, title: page.title, content: page.content)
            versionLog.info("Snapshot created for page \(page.id)")
        }
    }

    private func compareSelected() {
        guard let v1 = selectedV1, let v2 = selectedV2 else { return }
        bridge.fetchDiff(pageId: pageId, v1: v1.version ?? 0, v2: v2.version ?? 0) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let diff):
                    self.diffResult = diff
                    self.showDiff = true
                case .failure(let error):
                    versionLog.error("Diff failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func restoreVersion(_ version: DocVersion) {
        bridge.restoreVersion(pageId: pageId, versionId: version.id)
        versionLog.info("Restore version \(version.id) for page \(pageId)")
    }
}
