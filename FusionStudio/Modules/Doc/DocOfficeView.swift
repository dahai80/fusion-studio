// Callers: DocView toolbar button, DocSidebar office tab.
// Affected API: DocBridge checkOfficeStatus, createOfficeDocument, importOfficeDocument, exportOffice, previewOffice, mergeOffice, importOfficeDir, executeOfficeCommand.
// Data schemas: DocOfficeStatus (from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let officeLog = Logger(subsystem: "com.fusion.studio", category: "DocOffice")

struct DocOfficeView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var docName = ""
    @State private var selectedFormat = "docx"
    @State private var importPath = ""
    @State private var exportPageId = ""
    @State private var exportFormat = "docx"
    @State private var mergeTemplate = ""
    @State private var mergeData = ""
    @State private var commandFile = ""
    @State private var commandAction = ""
    @State private var importDirPath = ""
    @State private var previewResult = ""

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
                    exportSection
                    mergeSection
                    commandSection
                    importDirSection
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

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("导出页面")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack {
                TextField("页面 ID", text: $exportPageId)
                    .textFieldStyle(.roundedBorder)
                Picker("格式", selection: $exportFormat) {
                    ForEach(["docx", "pdf", "html", "md"], id: \.self) { f in
                        Text(f).tag(f)
                    }
                }
                .frame(width: 80)
                Button("导出") {
                    if !exportPageId.isEmpty {
                        bridge.exportOffice(pageId: exportPageId, format: exportFormat) { result in
                            if case .success(let resp) = result {
                                officeLog.info("Exported: \(resp)")
                            }
                        }
                        exportPageId = ""
                    }
                }
                .disabled(exportPageId.isEmpty)
            }
        }
    }

    private var mergeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("模板合并")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack {
                TextField("模板名", text: $mergeTemplate)
                    .textFieldStyle(.roundedBorder)
                TextField("数据 JSON", text: $mergeData)
                    .textFieldStyle(.roundedBorder)
                Button("合并") {
                    if !mergeTemplate.isEmpty, let data = try? JSONSerialization.jsonObject(with: Data(mergeData.utf8)) as? [String: Any] {
                        bridge.mergeOffice(template: mergeTemplate, data: data) { result in
                            if case .success(let resp) = result {
                                officeLog.info("Merged: \(resp)")
                            }
                        }
                        mergeTemplate = ""
                        mergeData = ""
                    }
                }
                .disabled(mergeTemplate.isEmpty)
            }
        }
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Office 命令")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack {
                TextField("文件", text: $commandFile)
                    .textFieldStyle(.roundedBorder)
                TextField("命令", text: $commandAction)
                    .textFieldStyle(.roundedBorder)
                Button("执行") {
                    if !commandFile.isEmpty, !commandAction.isEmpty {
                        bridge.executeOfficeCommand(file: commandFile, command: commandAction) { result in
                            if case .success(let resp) = result {
                                officeLog.info("Command result: \(resp)")
                            }
                        }
                        commandFile = ""
                        commandAction = ""
                    }
                }
                .disabled(commandFile.isEmpty || commandAction.isEmpty)
            }
        }
    }

    private var importDirSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("批量导入目录")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack {
                TextField("目录路径", text: $importDirPath)
                    .textFieldStyle(.roundedBorder)
                Button("导入") {
                    if !importDirPath.isEmpty {
                        bridge.importOfficeDir(dirPath: importDirPath) { _ in }
                        officeLog.info("Import dir: \(importDirPath)")
                        importDirPath = ""
                    }
                }
                .disabled(importDirPath.isEmpty)
            }
        }
    }
}
