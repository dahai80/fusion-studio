// Callers: DocView (files tab in DocSubTab).
// Affected API: DocBridge.fetchFiles / .uploadFile / .deleteFile → REST /api/pages/:id/files, /api/files/:id on localhost:11449.
// Data schemas: DocFileUpload (id/name/mime/size/created_at from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let filesLog = Logger(subsystem: "com.fusion.studio", category: "DocFiles")

struct DocFilesPanel: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?
    @State private var uploadName = ""
    @State private var uploadContent = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let pid = selectedPageId {
                fileList
                Divider()
                uploadSection(pid)
            } else {
                emptyState
            }
        }
        .background(theme.surfacePrimary)
        .onChange(of: selectedPageId) { newId in
            if let id = newId {
                bridge.fetchFiles(pageId: id) { _ in }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "paperclip")
                .foregroundColor(theme.accent)
            Text(i18n.t(.doc_file_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(String(format: i18n.t(.doc_file_countFmt), bridge.files.count))
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var fileList: some View {
        Group {
            if bridge.files.isEmpty {
                Text(i18n.t(.doc_file_empty))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                List(bridge.files) { file in
                    HStack {
                        Image(systemName: fileIcon(file.mime ?? ""))
                            .foregroundColor(theme.accent)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name ?? i18n.t(.doc_file_unknown))
                                .font(.subheadline)
                                .lineLimit(1)
                            if let size = file.size {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Button(action: { bridge.deleteFile(id: file.id) { _ in } }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func uploadSection(_ pageId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(i18n.t(.doc_file_upload))
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.textSecondary)
            HStack {
                TextField(i18n.t(.doc_file_name), text: $uploadName)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            TextEditor(text: $uploadContent)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(height: 60)
                .padding(4)
                .background(theme.surfaceSecondary)
                .cornerRadius(6)
            HStack {
                Spacer()
                Button(i18n.t(.doc_file_uploadBtn)) {
                    uploadFile(pageId)
                }
                .buttonStyle(.borderedProminent)
                .disabled(uploadName.isEmpty)
            }
        }
        .padding(12)
        .background(theme.surfaceSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperclip")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(i18n.t(.doc_file_selPage))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fileIcon(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("video/") { return "film" }
        if mime.contains("pdf") { return "doc.richtext" }
        if mime.contains("zip") { return "doc.zipper" }
        return "doc"
    }

    private func uploadFile(_ pageId: String) {
        let name = uploadName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let ext = (name as NSString).pathExtension.lowercased()
        let mime: String
        switch ext {
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "pdf": mime = "application/pdf"
        case "txt": mime = "text/plain"
        default: mime = "application/octet-stream"
        }
        bridge.uploadFile(pageId: pageId, name: name, mime: mime, content: uploadContent) { _ in }
        uploadName = ""
        uploadContent = ""
        filesLog.info("File uploaded: \(name) to page \(pageId)")
    }
}
