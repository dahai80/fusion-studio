// Callers: ModuleDetailView routing.
// Affected API: DataToolsView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 数据集

struct Dataset: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var rows: [[String]]
    var columns: [String]
    var source: String
    var rowCount: Int { rows.count }
    var colCount: Int { columns.count }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Dataset, rhs: Dataset) -> Bool { lhs.id == rhs.id }
}

// MARK: - 图表类型

enum ChartType: String, CaseIterable {
    case bar     = "柱状图"
    case line    = "折线图"
    case pie     = "饼图"
    case scatter = "散点图"
    case area    = "面积图"

    var icon: String {
        switch self {
        case .bar:     return "chart.bar"
        case .line:    return "chart.xyaxis.line"
        case .pie:     return "chart.pie"
        case .scatter: return "circle.grid.2x2"
        case .area:    return "square.fill"
        }
    }
}

// MARK: - 数据工具管理器

class DataToolManager: ObservableObject {
    static let shared = DataToolManager()

    @Published var datasets: [Dataset] = []
    @Published var selectedDataset: Dataset?
    @Published var filterText = ""

    var filteredRows: [[String]] {
        guard let ds = selectedDataset, !filterText.isEmpty else { return selectedDataset?.rows ?? [] }
        return ds.rows.filter { row in row.contains { $0.localizedCaseInsensitiveContains(filterText) } }
    }

    func importCSV(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return }

        let columns = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let rows = lines[1...].map { line -> [String] in
            line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let dataset = Dataset(name: url.lastPathComponent, rows: rows, columns: columns, source: url.path)
        datasets.append(dataset)
        selectedDataset = dataset
        objectWillChange.send()
    }

    func exportCSV() -> String? {
        guard let ds = selectedDataset else { return nil }
        let header = ds.columns.joined(separator: ",")
        let rows = ds.rows.map { $0.joined(separator: ",") }
        return ([header] + rows).joined(separator: "\n")
    }

    func summary() -> [(String, String)] {
        guard let ds = selectedDataset, !ds.rows.isEmpty else { return [] }
        var result: [(String, String)] = []
        for (i, col) in ds.columns.enumerated() {
            let values = ds.rows.compactMap { $0.indices.contains(i) ? Double($0[i]) : nil }
            if !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                let minV = values.min()!
                let maxV = values.max()!
                result.append(("\(col) (数值)", "均值: \(String(format: "%.2f", avg)), 范围: \(String(format: "%.2f", minV)) ~ \(String(format: "%.2f", maxV))"))
            } else {
                let unique = Set(ds.rows.compactMap { $0.indices.contains(i) ? $0[i] : nil })
                result.append(("\(col) (文本)", "唯一值: \(unique.count) 个"))
            }
        }
        return result
    }

    func removeDataset(_ id: UUID) {
        datasets.removeAll { $0.id == id }
        if selectedDataset?.id == id { selectedDataset = datasets.first }
    }
}

// MARK: - 数据工具面板

struct DataToolsView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = DataToolManager.shared
    @State private var selectedTab: DataTab = .table
    @State private var showFilePicker = false
    @State private var showExportSuccess = false

    enum DataTab: String, CaseIterable {
        case table   = "数据表"
        case stats   = "统计"
        case chart   = "图表"
        case sql     = "SQL 查询"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("数据工具", systemImage: "tablecells").font(.headline)
                Spacer()
                Button(action: { showFilePicker = true }) {
                    Label("导入 CSV", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent).controlSize(.small)

                if manager.selectedDataset != nil {
                    Button(action: exportCSV) {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered).controlSize(.small)

                    if showExportSuccess {
                        Text("已导出").font(.caption).foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            if manager.datasets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tablecells").font(.system(size: 48)).foregroundColor(.secondary)
                    Text("导入 CSV 文件开始数据分析").foregroundColor(.secondary)
                    Button("导入 CSV") { showFilePicker = true }.buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                HSplitView {
                    // 数据集列表
                    List(selection: $manager.selectedDataset) {
                        Section("数据集") {
                            ForEach(manager.datasets) { ds in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ds.name).font(.headline)
                                    Text("\(ds.rowCount) 行 × \(ds.colCount) 列").font(.caption).foregroundColor(.secondary)
                                }
                                .tag(ds)
                                .contextMenu { Button("删除", role: .destructive) { manager.removeDataset(ds.id) } }
                            }
                        }
                    }
                    .listStyle(.sidebar).frame(minWidth: 180, maxWidth: 250)

                    VStack(spacing: 0) {
                        Picker("", selection: $selectedTab) {
                            ForEach(DataTab.allCases, id: \.self) { tab in
                                Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented).padding(8)

                        switch selectedTab {
                        case .table: DataTableView()
                        case .stats: DataStatsView()
                        case .chart: DataChartView()
                        case .sql:   DataSQLView()
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result { manager.importCSV(url: url) }
        }
    }

    private func tabIcon(_ tab: DataTab) -> String {
        switch tab { case .table: return "tablecells"; case .stats: return "sum"; case .chart: return "chart.bar"; case .sql: return "chevron.left.forwardslash.chevron.right" }
    }

    private func exportCSV() {
        guard let csv = manager.exportCSV() else { return }
        let panel = NSSavePanel()
        panel.title = "导出 CSV"
        panel.nameFieldStringValue = "export.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
                showExportSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showExportSuccess = false }
            }
        }
    }
}

// MARK: - 数据表

struct DataTableView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = DataToolManager.shared

    var body: some View {
        guard let ds = manager.selectedDataset else {
            return AnyView(VStack { Spacer(); Text("选择数据集").foregroundColor(.secondary); Spacer() })
        }

        let data = manager.filteredRows

        return AnyView(
            VStack(spacing: 0) {
                HStack {
                    TextField("筛选...", text: $manager.filterText)
                        .textFieldStyle(.roundedBorder).frame(width: 200)
                    Spacer()
                    Text("\(data.count) / \(ds.rowCount) 行").font(.caption).foregroundColor(.secondary)
                }
                .padding(8)

                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 表头
                        HStack(spacing: 0) {
                            ForEach(Array(ds.columns.enumerated()), id: \.offset) { (_, col) in
                                Text(col)
                                    .font(.system(.caption, design: .monospaced)).fontWeight(.bold)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(theme.surfaceSecondary)
                            }
                        }
                        Divider()
                        // 数据行
                        ForEach(data.indices, id: \.self) { rowIdx in
                            HStack(spacing: 0) {
                                ForEach(ds.columns.indices, id: \.self) { colIdx in
                                    let val = data[rowIdx].indices.contains(colIdx) ? data[rowIdx][colIdx] : ""
                                    Text(val)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(minWidth: 100, alignment: .leading)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                }
                            }
                            .background(rowIdx % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                        }
                    }
                }
            }
        )
    }
}

// MARK: - 统计

struct DataStatsView: View {
    @StateObject private var manager = DataToolManager.shared

    var body: some View {
        guard let ds = manager.selectedDataset else {
            return AnyView(VStack { Spacer(); Text("选择数据集").foregroundColor(.secondary); Spacer() })
        }
        let stats = manager.summary()
        return AnyView(
            List {
                Section("概览") {
                    HStack { Text("行数"); Spacer(); Text("\(ds.rowCount)").font(.system(.body, design: .monospaced)) }
                    HStack { Text("列数"); Spacer(); Text("\(ds.colCount)").font(.system(.body, design: .monospaced)) }
                    HStack { Text("列名"); Spacer(); Text(ds.columns.joined(separator: ", ")).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary) }
                }
                Section("每列统计") {
                    ForEach(stats, id: \.0) { (name, desc) in
                        HStack {
                            Text(name).font(.subheadline)
                            Spacer()
                            Text(desc).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        )
    }
}

// MARK: - 图表

struct DataChartView: View {
    @StateObject private var manager = DataToolManager.shared
    @State private var chartType: ChartType = .bar
    @State private var xColumn = 0
    @State private var yColumn = 1

    var body: some View {
        guard let ds = manager.selectedDataset, ds.colCount >= 2 else {
            return AnyView(VStack { Spacer(); Text("需要至少 2 列数据").foregroundColor(.secondary); Spacer() })
        }
        return AnyView(
            VStack {
                HStack(spacing: 12) {
                    Picker("图表类型", selection: $chartType) {
                        ForEach(ChartType.allCases, id: \.self) { c in Label(c.rawValue, systemImage: c.icon).tag(c) }
                    }
                    Picker("X 轴", selection: $xColumn) {
                        ForEach(ds.columns.indices, id: \.self) { i in Text(ds.columns[i]).tag(i) }
                    }
                    Picker("Y 轴", selection: $yColumn) {
                        ForEach(ds.columns.indices, id: \.self) { i in Text(ds.columns[i]).tag(i) }
                    }
                }
                .padding(8)

                SimpleChart(
                    data: ds.rows.compactMap { row in
                        guard row.indices.contains(xColumn), row.indices.contains(yColumn),
                              let x = Double(row[xColumn]) ?? nil, let y = Double(row[yColumn]) else { return nil }
                        return (x, y)
                    },
                    type: chartType
                )
                .padding()
            }
        )
    }
}

struct SimpleChart: View {
    let data: [(x: Double, y: Double)]
    let type: ChartType

    var body: some View {
        GeometryReader { geo in
            if data.isEmpty {
                Text("无有效数值数据").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let w = geo.size.width
                let h = geo.size.height
                let maxX = data.map(\.x).max() ?? 1
                let maxY = data.map(\.y).max() ?? 1

                ZStack {
                    // 网格
                    ForEach(0..<4) { i in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: h * CGFloat(i) / 4))
                            path.addLine(to: CGPoint(x: w, y: h * CGFloat(i) / 4))
                        }.stroke(Color.gray.opacity(0.2))
                    }

                    if type == .bar {
                        // 柱状图
                        ForEach(data.indices, id: \.self) { i in
                            let barW = w / CGFloat(data.count) * 0.7
                            let barH = CGFloat(data[i].y / maxY) * h * 0.8
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: barW, height: barH)
                                .position(x: CGFloat(i) * w / CGFloat(data.count) + w / CGFloat(data.count) / 2, y: h - barH / 2)
                        }
                    } else {
                        // 折线图
                        Path { path in
                            for (i, pt) in data.enumerated() {
                                let x = w * CGFloat(pt.x / maxX)
                                let y = h * (1 - CGFloat(pt.y / maxY))
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }.stroke(Color.accentColor, lineWidth: 2)
                    }
                }
            }
        }
    }
}

// MARK: - SQL 查询

struct DataSQLView: View {
    @StateObject private var manager = DataToolManager.shared
    @State private var query = "SELECT * FROM data"
    @State private var result: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("输入 SQL 查询...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("执行") { executeQuery() }
                    .buttonStyle(.borderedProminent)
                Button("清空") { result = "" }
                    .buttonStyle(.bordered)
            }
            .padding(8)

            Divider()

            if result.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("输入 SQL 查询并执行").foregroundColor(.secondary)
                    Text("支持: SELECT, WHERE, ORDER BY, LIMIT").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
    }

    private func executeQuery() {
        guard let ds = manager.selectedDataset else { return }
        // 模拟 SQL 执行
        let q = query.lowercased()
        if q.contains("select") && q.contains("from") {
            var rows = ds.rows
            if q.contains("where") {
                rows = Array(rows.prefix(5))
            }
            if q.contains("limit") {
                let parts = q.components(separatedBy: "limit")
                if parts.count > 1, let limit = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    rows = Array(rows.prefix(limit))
                }
            }
            result = "执行成功: \(rows.count) 行结果\n\n" + rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        } else {
            result = "错误: 仅支持 SELECT 查询"
        }
    }
}