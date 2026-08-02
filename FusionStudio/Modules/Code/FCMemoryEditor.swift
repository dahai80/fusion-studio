import SwiftUI
import Foundation
import os.log

private let memoryLog = Logger(subsystem: "com.fusion.studio", category: "FCMemory")

enum FCMemoryTier: String, CaseIterable {
    case global = "global"
    case project = "project"
    case directory = "directory"

    var label: String {
        switch self {
        case .global: return "全局"
        case .project: return "项目"
        case .directory: return "目录"
        }
    }

    var icon: String {
        switch self {
        case .global: return "globe"
        case .project: return "folder"
        case .directory: return "folder.badge.gearshape"
        }
    }
}

struct FCMemoryEntry: Identifiable {
    let id = UUID()
    let tier: FCMemoryTier
    var path: String
    var content: String
    var exists: Bool
}

class FCMemoryStore: ObservableObject {
    static let shared = FCMemoryStore()

    @Published var entries: [FCMemoryEntry] = []
    @Published var isLoading = false

    private let fm = FileManager.default

    func loadAll(projectRoot: String? = nil) {
        isLoading = true
        let root = projectRoot ?? ProjectWorkspace.shared.projectRoot?.path ?? ""

        var results: [FCMemoryEntry] = []

        let globalPath = NSHomeDirectory() + "/.fusion/FUSION.md"
        results.append(loadEntry(tier: .global, path: globalPath))

        if !root.isEmpty {
            let projectPath = root + "/FUSION.md"
            results.append(loadEntry(tier: .project, path: projectPath))
        }

        DispatchQueue.main.async {
            self.entries = results
            self.isLoading = false
            memoryLog.info("loaded \(results.count) memory entries")
        }
    }

    func save(entry: FCMemoryEntry) {
        let dir = (entry.path as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        do {
            try entry.content.write(toFile: entry.path, atomically: true, encoding: .utf8)
            memoryLog.info("saved memory to \(entry.path)")
        } catch {
            memoryLog.error("failed to save memory: \(error.localizedDescription)")
        }
    }

    func initProjectMemory(projectRoot: String) {
        let path = projectRoot + "/FUSION.md"
        guard !fm.fileExists(atPath: path) else { return }
        let template = "# Project Memory\n\n## Architecture\n\n## Conventions\n\n## Key Decisions\n"
        try? template.write(toFile: path, atomically: true, encoding: .utf8)
        memoryLog.info("initialized project FUSION.md at \(projectRoot)")
        loadAll(projectRoot: projectRoot)
    }

    private func loadEntry(tier: FCMemoryTier, path: String) -> FCMemoryEntry {
        let exists = fm.fileExists(atPath: path)
        let content: String
        if exists {
            content = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        } else {
            content = ""
        }
        return FCMemoryEntry(tier: tier, path: path, content: content, exists: exists)
    }
}

struct FCMemoryPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var store = FCMemoryStore.shared
    @State private var selectedTier: FCMemoryTier = .project
    @State private var editText = ""

    var body: some View {
        VStack(spacing: theme.spacingS) {
            HStack {
                Text("Memory (FUSION.md)")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                ForEach(FCMemoryTier.allCases, id: \.self) { tier in
                    Button(action: { selectedTier = tier; loadSelected() }) {
                        HStack(spacing: 3) {
                            Image(systemName: tier.icon)
                                .font(.system(size: 9))
                            Text(tier.label)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(selectedTier == tier ? theme.accent : theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedTier == tier ? theme.accent.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.isLoading {
                ProgressView().scaleEffect(0.6)
            } else {
                TextEditor(text: $editText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .scrollContentBackground(.hidden)
                    .background(theme.codeBg)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                            .stroke(theme.separator.opacity(0.3), lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Button("Save") {
                        saveSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(theme.spacingM)
        .frame(minHeight: 200, maxHeight: 400)
        .onAppear {
            store.loadAll()
            loadSelected()
        }
    }

    private func loadSelected() {
        if let entry = store.entries.first(where: { $0.tier == selectedTier }) {
            editText = entry.content
        } else {
            editText = ""
        }
    }

    private func saveSelected() {
        if let idx = store.entries.firstIndex(where: { $0.tier == selectedTier }) {
            store.entries[idx].content = editText
            store.save(entry: store.entries[idx])
        }
    }
}
