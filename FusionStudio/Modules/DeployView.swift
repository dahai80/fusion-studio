import SwiftUI
import os.log

struct DeployView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var selectedTab: DeployTab = .export

    private let logger = Logger(subsystem: "com.fusion.studio", category: "DeployView")

    enum DeployTab: String, CaseIterable {
        case export = "Export"
        case import_ = "Import"
        case formats = "Formats"
    }

    var body: some View {
        VStack(spacing: 0) {
            deployToolbar
            Divider()
            Picker("Tab", selection: $selectedTab) {
                ForEach(DeployTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            Group {
                switch selectedTab {
                case .export:
                    DeployExportView()
                case .import_:
                    DeployImportView()
                case .formats:
                    DeployFormatsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            Task { await loadFormats() }
        }
    }

    private var deployToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await loadFormats() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Spacer()
        }
        .padding(8)
    }

    private func loadFormats() async {
        do {
            _ = try await bridge.fetchDeployFormats()
        } catch {
            logger.error("loadFormats: \(error)")
        }
    }
}

struct DeployExportView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var graphId: String = ""
    @State private var format: String = "json"
    @State private var filepath: String = ""
    @State private var withServer: Bool = true
    @State private var port: Int = 8000
    @State private var isExporting: Bool = false
    @State private var exportResult: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "DeployExportView")

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Export Graph") {
                VStack(spacing: 8) {
                    TextField("Graph ID", text: $graphId)
                        .textFieldStyle(.roundedBorder)
                    Picker("Format", selection: $format) {
                        ForEach(bridge.moduleState.deployFormats) { f in
                            Text("\(f.format) - \(f.description)").tag(f.format)
                        }
                        Text("JSON").tag("json")
                        Text("YAML").tag("yaml")
                        Text("Python").tag("python")
                    }
                    TextField("Output filepath (optional)", text: $filepath)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Toggle("With Server", isOn: $withServer)
                        if withServer {
                            Stepper("Port: \(port)", value: $port, in: 1024...65535)
                                .frame(width: 160)
                        }
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Button("Export") {
                            Task { await exportGraph() }
                        }
                        .disabled(graphId.isEmpty || isExporting)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)

            if let result = exportResult {
                GroupBox("Export Result") {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.hasPrefix("Error") ? .red : .green)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private func exportGraph() async {
        isExporting = true
        exportResult = nil
        do {
            let result = try await bridge.deployExport(graphId: graphId, format: format, filepath: filepath, withServer: withServer, port: port)
            if let path = result["filepath"] as? String {
                exportResult = "Exported to: \(path)"
            } else if let status = result["status"] as? String {
                exportResult = "Status: \(status)"
            } else {
                exportResult = "Export completed"
            }
        } catch {
            exportResult = "Error: \(error.localizedDescription)"
            logger.error("exportGraph: \(error)")
        }
        isExporting = false
    }
}

struct DeployImportView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var filepath: String = ""
    @State private var isImporting: Bool = false
    @State private var importResult: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "DeployImportView")

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Import Graph") {
                VStack(spacing: 8) {
                    TextField("Filepath to import", text: $filepath)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Import") {
                            Task { await importGraph() }
                        }
                        .disabled(filepath.isEmpty || isImporting)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)

            if let result = importResult {
                GroupBox("Import Result") {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.hasPrefix("Error") ? .red : .green)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private func importGraph() async {
        isImporting = true
        importResult = nil
        do {
            let graph = try await bridge.deployImport(filepath: filepath)
            importResult = "Imported graph: \(graph.name) (\(graph.id))"
        } catch {
            importResult = "Error: \(error.localizedDescription)"
            logger.error("importGraph: \(error)")
        }
        isImporting = false
    }
}

struct DeployFormatsView: View {
    @EnvironmentObject var bridge: AgentBridge

    var body: some View {
        Group {
            if bridge.moduleState.deployFormats.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No formats available")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(bridge.moduleState.deployFormats) { fmt in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fmt.format)
                                .font(.headline)
                            Text(fmt.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
    }
}
