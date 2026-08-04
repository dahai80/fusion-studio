// IMPORTERS/CALLERS: DocSidebar workspaceBar (popover)
// AFFECTED API: DocBridge — fetchWorkspaces, createWorkspace, updateWorkspace, deleteWorkspace
// DATA SCHEMAS: DocWorkspace
// USER INSTRUCTION: "立即启动4项GUI增强 — workspace选择器"

import SwiftUI
import os.log

private let docWSLog = Logger(subsystem: "com.fusion.studio", category: "DocWorkspacePicker")

struct DocWorkspacePicker: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var bridge: DocBridge
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newDesc = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("工作空间")
                    .font(.headline)
                Spacer()
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            if bridge.workspaces.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无工作空间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("创建第一个工作空间") { showCreate = true }
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                List(bridge.workspaces) { ws in
                    workspaceRow(ws)
                }
                .listStyle(.plain)
            }

            if showCreate {
                Divider()
                VStack(spacing: 8) {
                    TextField("名称", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    TextField("描述（可选）", text: $newDesc)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("取消") {
                            showCreate = false
                            newName = ""
                            newDesc = ""
                        }
                        Button("创建") {
                            createWorkspace()
                        }
                        .disabled(newName.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 280, height: showCreate ? 360 : 280)
        .background(theme.surfacePrimary)
        .onAppear { loadWorkspaces() }
    }

    private func workspaceRow(_ ws: DocWorkspace) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ws.name)
                    .font(.subheadline)
                    .fontWeight(bridge.currentWorkspace?.id == ws.id ? .semibold : .regular)
                if let desc = ws.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if bridge.currentWorkspace?.id == ws.id {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            bridge.currentWorkspace = ws
            docWSLog.info("selected workspace: \(ws.id)")
            dismiss()
        }
        .contextMenu {
            Button("删除", role: .destructive) {
                bridge.deleteWorkspace(id: ws.id) { _ in
                    docWSLog.info("deleted workspace: \(ws.id)")
                }
            }
        }
    }

    private func loadWorkspaces() {
        bridge.fetchWorkspaces { result in
            if case .failure(let err) = result {
                docWSLog.error("fetchWorkspaces failed: \(err.localizedDescription)")
            }
        }
    }

    private func createWorkspace() {
        bridge.createWorkspace(name: newName, description: newDesc.isEmpty ? nil : newDesc) { result in
            switch result {
            case .success(let ws):
                docWSLog.info("created workspace: \(ws.id)")
                showCreate = false
                newName = ""
                newDesc = ""
            case .failure(let err):
                docWSLog.error("createWorkspace failed: \(err.localizedDescription)")
            }
        }
    }
}
