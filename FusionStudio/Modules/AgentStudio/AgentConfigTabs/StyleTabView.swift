import SwiftUI
import Combine
import os.log

// MARK: - StyleTabView

struct StyleTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newTemplate = "default"
    @State private var newRules = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Styles")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Style", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.styles.isEmpty {
                Spacer()
                Text("No custom styles")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.styles.enumerated()), id: \.offset) { idx, style in
                        let name = style["name"] as? String ?? "Unknown"
                        let template = style["template"] as? String ?? ""
                        let sid = style["style_id"] as? String ?? style["id"] as? String ?? ""
                        StudioRow(label: name, sublabel: template, isLast: idx == bridge.configState.styles.count - 1) {
                            FusionTag("style", color: .purple)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await deleteStyle(sid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchStyles() } }
        .sheet(isPresented: $showCreateSheet) {
            createStyleSheet
        }
    }

    private var createStyleSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Style")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Template (default, formal, casual...)", text: $newTemplate)
                .textFieldStyle(.roundedBorder)
            TextField("Rules (JSON)", text: $newRules, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createStyle() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createStyle() async {
        guard !newName.isEmpty else { return }
        var rules: [String: Any] = [:]
        if let data = newRules.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            rules = json
        }
        do {
            _ = try await bridge.styleCreate(name: newName, template: newTemplate, rules: rules)
            toastManager.show(style: .success, title: "Created", message: newName)
            showCreateSheet = false
            newName = ""; newRules = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func deleteStyle(_ id: String, name: String) async {
        do {
            _ = try await bridge.styleDelete(styleId: id)
            toastManager.show(style: .info, title: "Deleted", message: name)
        } catch {
            toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
        }
    }
}
