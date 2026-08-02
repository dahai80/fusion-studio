// Callers: DocView toolbar button, DocSidebar office tab.
// Affected API: DocBridge checkOfficeStatus, createOfficeDocument, importOfficeDocument.
// Data schemas: DocOfficeStatus (from DocBridge.swift).
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let officeLog = Logger(subsystem: "com.fusion.studio", category: "DocOffice")

struct DocOfficeView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var docName = ""
    @State private var selectedFormat = "docx"
    @State private var importPath = ""

    let formats = [
        ("docx", "Word 文档", "doc.richtext"),
        ("xlsx", "Excel 表格", "tablecells"),
        ("pptx", "PowerPoint 演示", "play.rectangle"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            officeHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    officeStatusCard
                    createSection
                    importSection
                }
                .padding(16)
            }
        }
        .background(theme.surfacePrimary)
        .onAppear {
            bridge.checkOfficeStatus()
        }
    }

    private var officeHeader: some View {
        HStack {
            Text("Office 操控")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var officeStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(theme.accent)
                Text("OfficeCLI 状态")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Circle()
                    .fill(bridge.officeStatus?.available == true ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            if let status = bridge.officeStatus {
                if let ver = status.version {
                    Text("版本: \(ver)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                if let fmts = status.formats {
                    Text("支持格式: \(fmts.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            } else {
                Text("检测中...")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("创建文档")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                ForEach(formats, id: \.0) { fmt in
                    formatButton(fmt.0, label: fmt.1, icon: fmt.2)
                }
            }

            HStack {
                TextField("文件名", text: $docName)
                    .textFieldStyle(.roundedBorder)
                Button("创建") {
                    if !docName.isEmpty {
                        bridge.createOfficeDocument(format: selectedFormat, name: docName)
                        officeLog.info("Create office doc: \(docName).\(selectedFormat)")
                        docName = ""
                    }
                }
                .disabled(docName.isEmpty)
            }
        }
    }

    private func formatButton(_ format: String, label: String, icon: String) -> some View {
        Button(action: { selectedFormat = format }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(selectedFormat == format ? theme.accent : .secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(selectedFormat == format ? theme.accent : theme.textSecondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selectedFormat == format ? theme.accentSoft : theme.surfaceSecondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("导入文档")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack {
                TextField("文件路径", text: $importPath)
                    .textFieldStyle(.roundedBorder)
                Button("导入") {
                    if !importPath.isEmpty {
                        bridge.importOfficeDocument(filePath: importPath)
                        officeLog.info("Import office doc: \(importPath)")
                        importPath = ""
                    }
                }
                .disabled(importPath.isEmpty)
            }
        }
    }
}
