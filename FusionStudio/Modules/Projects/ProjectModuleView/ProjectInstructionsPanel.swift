import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectInstructionsPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let projectId: String
    @State private var instructions: String = ""
    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var editMode: InstructionEditMode = .markdown
    @State private var showVersionHistory = false
    @State private var snapshots: [InstructionSnapshot] = []
    @State private var isSaving = false

    private let maxChars = 10000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                // Section header
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(theme.accent)
                    Text(i18n.t(.proj_instTitle))
                        .font(.system(size: theme.textSize, weight: .semibold))
                    Spacer()
                    if isEditing {
                        Button(i18n.t(.save)) {
                            saveInstructions()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .disabled(isSaving)
                        Button(i18n.t(.cancel)) {
                            isEditing = false
                            editedText = instructions
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textTertiary)
                    } else {
                        Button(action: { isEditing = true; editedText = instructions }) {
                            Image(systemName: "pencil")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        // GUI-15: Version history button
                        Button(action: { loadSnapshots(); showVersionHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Edit mode toggle
                if isEditing {
                    HStack {
                        ForEach(InstructionEditMode.allCases, id: \.self) { mode in
                            Button(action: { editMode = mode }) {
                                Text(mode.localLabel)
                                    .font(.system(size: 9, weight: editMode == mode ? .bold : .regular))
                                    .foregroundStyle(editMode == mode ? theme.accent : theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text(String(format: i18n.t(.proj_createCharCountFmt), editedText.count, maxChars))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(editedText.count > maxChars ? .red : theme.textTertiary)
                    }
                }

                // Content
                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(theme.textTertiary.opacity(0.2)))
                } else {
                    if instructions.isEmpty {
                        VStack(spacing: theme.spacingXS) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 20))
                                .foregroundStyle(theme.textQuaternary)
                            Text(i18n.t(.proj_instEmpty))
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textTertiary)
                            Text(i18n.t(.proj_instEmptyHint))
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textQuaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacingL)
                    } else {
                        Text(instructions)
                            .font(.system(size: theme.footnoteSize, design: editMode == .markdown ? .monospaced : .default))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(theme.spacingL)
        }
        .sheet(isPresented: $showVersionHistory) {
            // GUI-15: Instruction Version History
            InstructionVersionHistory(projectId: projectId, snapshots: snapshots)
        }
        .onAppear { loadInstructions() }
    }

    private func loadInstructions() {
        Task {
            do {
                let result = try await ipc.projectInstructionGet(projectId: projectId)
                if let content = result["content"] as? String {
                    await MainActor.run { self.instructions = content }
                }
            } catch {
                projLog.error("loadInstructions failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveInstructions() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectInstructionSave(projectId: projectId, content: editedText)
                await MainActor.run {
                    self.instructions = editedText
                    self.isEditing = false
                    self.isSaving = false
                }
                projLog.info("Instructions saved for project \(projectId)")
            } catch {
                projLog.error("saveInstructions failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func loadSnapshots() {
        Task {
            do {
                let result = try await ipc.projectInstructionSnapshots(projectId: projectId)
                if let items = result["items"] as? [[String: Any]] ?? result["snapshots"] as? [[String: Any]] {
                    await MainActor.run {
                        self.snapshots = items.compactMap { snap in
                            guard let id = snap["id"] as? String,
                                  let content = snap["content"] as? String else { return nil }
                            return InstructionSnapshot(
                                id: id,
                                label: snap["label"] as? String ?? "V1",
                                content: content,
                                createdAt: ISO8601DateFormatter().date(from: snap["created_at"] as? String ?? "") ?? Date()
                            )
                        }
                    }
                }
            } catch {
                projLog.error("loadSnapshots failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-15: Instruction Version History

