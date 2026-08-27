import SwiftUI
import Combine
import os.log

// MARK: - MemoryTabView

struct MemoryTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showStoreSheet = false
    @State private var newContent = ""
    @State private var newScope = "default"
    @State private var newTags = ""
    @State private var newImportance: Double = 5
    @State private var newTier = ""
    @State private var recallQuery = ""
    @State private var recallScope = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Memory Store")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Store", icon: "plus") { showStoreSheet = true }
            }
            .padding(theme.spacingM)

            HStack(spacing: theme.spacingS) {
                TextField("Query memories...", text: $recallQuery)
                    .textFieldStyle(.roundedBorder)
                TextField("scope", text: $recallScope)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                FusionButton("Recall", icon: "magnifyingglass", style: .secondary) {
                    Task { await runRecall() }
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if bridge.moduleState.memoryEntries.isEmpty {
                Spacer()
                Text("No memories yet")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    ListGroup {
                        ForEach(Array(bridge.moduleState.memoryEntries.enumerated()), id: \.element.id) { idx, entry in
                            StudioRow(label: entry.content, sublabel: memorySublabel(entry), isLast: idx == bridge.moduleState.memoryEntries.count - 1) {
                                VStack(alignment: .trailing, spacing: 4) {
                                    FusionTag("L\(entry.importance)", color: importanceColor(entry.importance))
                                    if !entry.tier.isEmpty {
                                        FusionTag(entry.tier, color: .purple)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                do {
                    try await bridge.fetchRecentMemories()
                } catch {
                    agentStudioLog.warning("fetchRecentMemories failed: \(error)")
                }
            }
        }
        .sheet(isPresented: $showStoreSheet) {
            storeSheet
        }
    }

    private var storeSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Store Memory")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Content", text: $newContent, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                TextField("scope", text: $newScope)
                    .textFieldStyle(.roundedBorder)
                TextField("tier", text: $newTier)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("tags (comma separated)", text: $newTags)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Importance")
                    .font(.system(size: theme.captionSize))
                Slider(value: $newImportance, in: 1...10, step: 1)
                Text("\(Int(newImportance))")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .frame(width: 24)
            }
            HStack {
                FusionButton("Cancel") { showStoreSheet = false }
                Spacer()
                FusionButton("Store", icon: "tray.and.arrow.down", isDisabled: newContent.isEmpty) {
                    Task { await runStore() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 420)
    }

    private func runStore() async {
        guard !newContent.isEmpty else { return }
        do {
            _ = try await bridge.memoryStore(content: newContent, scope: newScope, tags: newTags, importance: Int(newImportance), tier: newTier)
            toastManager.show(style: .success, title: "Stored", message: "Memory saved to \(newScope)")
            showStoreSheet = false
            newContent = ""
            newTags = ""
            try await bridge.fetchRecentMemories()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func runRecall() async {
        do {
            let entries = try await bridge.memoryRecall(query: recallQuery, scope: recallScope)
            toastManager.show(style: .success, title: "Recall", message: "\(entries.count) memories")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func memorySublabel(_ entry: MemoryEntryModel) -> String {
        var parts: [String] = []
        if !entry.scope.isEmpty { parts.append("scope: \(entry.scope)") }
        if !entry.tags.isEmpty { parts.append("tags: \(entry.tags)") }
        if !entry.timestamp.isEmpty { parts.append(entry.timestamp) }
        return parts.joined(separator: " · ")
    }

    private func importanceColor(_ level: Int) -> TagColor {
        switch level {
        case 8...10: return .red
        case 5...7: return .orange
        case 3...4: return .blue
        default: return .gray
        }
    }
}
