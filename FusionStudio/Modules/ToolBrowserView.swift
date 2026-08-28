// Callers: AgentStudioView tools tab, sidebar shortcut.
// Affected API: ToolBrowserView — tool browsing/config/enable-disable UI.
// Data schemas: ToolInfo (name/description/parameters/category/enabled), loaded via AgentBridge.fetchTools().
// User instruction: "继续Phase 3" — P3-2 工具浏览器

import SwiftUI
import os.log

struct ToolInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let parameters: [String: Any]
    let category: String
    let enabled: Bool

    var paramKeys: [String] {
        (parameters["properties"] as? [String: Any])?.keys.map { String($0) } ?? []
    }
}

struct ToolBrowserView: View {
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var tools: [ToolInfo] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @State private var selectedTool: ToolInfo?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var testInput: String = ""
    @State private var testOutput: String = ""
    @State private var showRegisterSheet: Bool = false
    @State private var regName: String = ""
    @State private var regDesc: String = ""
    @State private var regParams: String = "{}"
    @State private var regCode: String = ""
    @State private var regBusy: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "ToolBrowser")

    private var categories: [String] {
        let cats = Set(tools.map(\.category))
        return ["All"] + cats.sorted()
    }

    private var filteredTools: [ToolInfo] {
        var result = tools
        if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        HSplitView {
            toolListView
                .frame(minWidth: 260, maxWidth: 360)
            toolDetailView
                .frame(minWidth: 400)
        }
        .navigationTitle("Tools")
        .onAppear {
            Task { await loadTools() }
        }
        .sheet(isPresented: $showRegisterSheet) {
            VStack(spacing: theme.spacingM) {
                Text("Register Dynamic Tool").font(.headline)
                TextField("Name", text: $regName)
                    .textFieldStyle(.roundedBorder)
                TextField("Description", text: $regDesc)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $regParams)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .frame(height: 80)
                    .border(theme.textTertiary)
                TextEditor(text: $regCode)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .frame(height: 80)
                    .border(theme.textTertiary)
                HStack {
                    Button("Cancel") { showRegisterSheet = false }
                    Button("Register") { Task { await registerTool() } }
                        .disabled(regName.isEmpty || regBusy)
                }
            }
            .padding()
            .frame(width: 400)
        }
    }

    private var toolListView: some View {
        VStack(spacing: 0) {
            searchField
            categoryPicker
            if isLoading {
                ProgressView().padding()
            } else if let errMsg = errorMessage {
                Text(errMsg)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.errorText)
                    .padding()
            }
            List(filteredTools, selection: Binding(
                get: { selectedTool?.id },
                set: { id in
                    selectedTool = id.flatMap { tid in filteredTools.first(where: { $0.id == tid }) }
                }
            )) { tool in
                toolRow(tool)
                    .tag(tool.id)
            }
            .listStyle(.sidebar)
            Button {
                showRegisterSheet = true
            } label: {
                Label("Register Tool", systemImage: "plus")
                    .font(.system(size: theme.smallTextSize))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
            TextField("Search tools...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.smallTextSize))
        }
        .padding(theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingS) {
                ForEach(categories, id: \.self) { cat in
                    FusionButton(cat, style: selectedCategory == cat ? .primary : .secondary, size: .small) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = cat
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
        }
        .background(theme.surfaceSecondary)
    }

    private func toolRow(_ tool: ToolInfo) -> some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(tool.enabled ? theme.greenDot : theme.textTertiary)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(size: theme.smallTextSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(tool.description)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var toolDetailView: some View {
        Group {
            if let tool = selectedTool {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingL) {
                        toolHeader(tool)
                        toolParameters(tool)
                        toolTestPanel(tool)
                        if tool.category == "dynamic" || tool.category == "plugin" {
                            Button(role: .destructive) {
                                Task { await unregisterTool(tool.name) }
                            } label: {
                                Label("Unregister Tool", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(theme.spacingL)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "wrench.and.screwvariant")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.textTertiary)
                    Text("Select a tool to view details")
                        .font(.system(size: theme.bodySize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.surfacePrimary)
    }

    private func toolHeader(_ tool: ToolInfo) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text(tool.name)
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton(tool.enabled ? "Enabled" : "Disabled",
                             style: tool.enabled ? .primary : .secondary,
                             size: .small) {}
                    .disabled(true)
            }
            Text(tool.description)
                .font(.system(size: theme.bodySize))
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: theme.spacingS) {
                Label(tool.category, systemImage: "folder")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                Label("\(tool.paramKeys.count) params", systemImage: "slider.horizontal.3")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func toolParameters(_ tool: ToolInfo) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Parameters")
                .font(.system(size: theme.smallTextSize, weight: .semibold))
                .foregroundStyle(theme.text)
            if tool.paramKeys.isEmpty {
                Text("No parameters")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ForEach(tool.paramKeys, id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.system(size: theme.smallTextSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        Spacer()
                        paramTypeLabel(tool, key: key)
                    }
                    .padding(theme.spacingS)
                    .background(theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
        }
    }

    private func paramTypeLabel(_ tool: ToolInfo, key: String) -> some View {
        let props = tool.parameters["properties"] as? [String: Any]
        let prop = props?[key] as? [String: Any]
        let typeStr = prop?["type"] as? String ?? "any"
        let required = (tool.parameters["required"] as? [String])?.contains(key) ?? false
        return HStack(spacing: 4) {
            Text(typeStr)
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(theme.accent)
            if required {
                Text("*")
                    .font(.system(size: theme.captionSize, weight: .bold))
                    .foregroundStyle(theme.redDot)
            }
        }
    }

    private func toolTestPanel(_ tool: ToolInfo) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Test")
                .font(.system(size: theme.smallTextSize, weight: .semibold))
                .foregroundStyle(theme.text)
            TextEditor(text: $testInput)
                .font(.system(size: theme.smallTextSize, design: .monospaced))
                .frame(height: 80)
                .padding(theme.spacingXS)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .overlay {
                    if testInput.isEmpty {
                        Text("Enter JSON input...")
                            .font(.system(size: theme.smallTextSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                            .padding(theme.spacingS)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
            if !testOutput.isEmpty {
                Text("Output")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                Text(testOutput)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .padding(theme.spacingS)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
    }

    private func loadTools() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rawTools = try await bridge.fetchTools()
            tools = rawTools.compactMap { dict -> ToolInfo? in
                guard let name = dict["name"] as? String else { return nil }
                return ToolInfo(
                    id: name,
                    name: name,
                    description: dict["description"] as? String ?? "",
                    parameters: dict["parameters"] as? [String: Any] ?? [:],
                    category: dict["category"] as? String ?? "built-in",
                    enabled: dict["enabled"] as? Bool ?? true
                )
            }
            logger.info("Loaded \(tools.count) tools")
        } catch {
            errorMessage = BridgeError.sanitize(error)
            logger.error("fetchTools failed: \(error.localizedDescription)")
        }
    }

    private func unregisterTool(_ name: String) async {
        do {
            _ = try await bridge.ipcClient!.toolDynamicUnregister(name: name)
            logger.info("Unregistered tool: \(name)")
            await loadTools()
            selectedTool = nil
        } catch {
            errorMessage = BridgeError.sanitize(error)
            logger.error("toolDynamicUnregister failed: \(error.localizedDescription)")
        }
    }

    private func registerTool() async {
        regBusy = true
        defer { regBusy = false }
        guard let paramsData = regParams.data(using: .utf8),
              let paramsObj = try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any] else {
            errorMessage = "Invalid JSON parameters"
            return
        }
        do {
            _ = try await bridge.ipcClient!.toolDynamicRegister(
                name: regName, description: regDesc, parameters: paramsObj, code: regCode
            )
            logger.info("Registered tool: \(regName)")
            showRegisterSheet = false
            regName = ""; regDesc = ""; regParams = "{}"; regCode = ""
            await loadTools()
        } catch {
            errorMessage = BridgeError.sanitize(error)
            logger.error("toolDynamicRegister failed: \(error.localizedDescription)")
        }
    }
}
