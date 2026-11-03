import SwiftUI
import os.log

// #431 P3-1: 模板画廊 (plan §6.6 templates gallery)。
//   7 个 starter flow (纯本地可跑型优先 — local 后端零依赖可执行);
//   首次启动播种到 flow store templates/; 画廊 sheet 一键实例化到画布;
//   空态 placeholder 快速入口 + saveAsTemplate (store 已有, 此处接 UI)。

private let tplLog = Logger(subsystem: "com.fusion.studio", category: "FlowTemplates")

enum FlowTemplates {
    // MARK: - 7 starter flows

    static func all() -> [(name: String, description: String, build: () -> WorkflowGraph)] {
        [
            ("Summarizer", "Text in, LLM summary out",
             summarizer),
            ("Classify & Route", "Question classifier branching to two ends",
             classifyRoute),
            ("RAG Ask", "Knowledge retrieval feeding LLM answer",
             ragAsk),
            ("Human Approval", "human_input checkpoint then condition gate",
             humanApproval),
            ("Loop Report", "Auto-counter loop capped, then end",
             loopReport),
            ("Template Letter", "Template rendering state values",
             templateLetter),
            ("Sub-Flow Compose", "Call another flow from library as a tool",
             subFlowCompose),
        ]
    }

    static func build(_ name: String) -> WorkflowGraph? {
        all().first { $0.name == name }?.build()
    }

    private static func graph(_ name: String, _ nodes: [WorkflowNode], _ edges: [WorkflowEdge]) -> WorkflowGraph {
        var g = WorkflowGraph(name: name)
        g.nodes = nodes
        g.edges = edges
        return g
    }

    private static func chain(_ name: String, _ specs: [(NodeTypeKey, [String: JSONValue], GraphPoint)]) -> WorkflowGraph {
        let nodes = specs.map { WorkflowNode(type: $0.0, position: $0.2, config: $0.1) }
        var edges: [WorkflowEdge] = []
        for i in 1..<nodes.count {
            let srcOut = NodeRegistry.shared.definition(for: nodes[i - 1].type)?.outputs.first?.key ?? "out"
            edges.append(WorkflowEdge(sourceNode: nodes[i - 1].id, sourcePort: srcOut,
                                      targetNode: nodes[i].id, targetPort: "in"))
        }
        return graph(name, nodes, edges)
    }

    static func summarizer() -> WorkflowGraph {
        chain("Summarizer", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.llm, ["system_prompt": .string("Summarize the input in 3 bullet points."),
                    "temperature": .string("0.3")], GraphPoint(x: 300, y: 160)),
            (.end, ["output_key": .string("summary")], GraphPoint(x: 540, y: 160)),
        ])
    }

    static func classifyRoute() -> WorkflowGraph {
        chain("Classify & Route", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.questionClassifier, ["classes": .string("question,complaint"),
                                   "model": .string("")], GraphPoint(x: 300, y: 160)),
            (.end, ["output_key": .string("route")], GraphPoint(x: 540, y: 160)),
        ])
    }

    static func ragAsk() -> WorkflowGraph {
        chain("RAG Ask", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.knowledgeRetrieval, ["collection": .string("kb-main"),
                                   "top_k": .string("5")], GraphPoint(x: 300, y: 160)),
            (.llm, ["system_prompt": .string("Answer strictly from the retrieved context.")],
             GraphPoint(x: 540, y: 160)),
            (.end, ["output_key": .string("answer")], GraphPoint(x: 780, y: 160)),
        ])
    }

    static func humanApproval() -> WorkflowGraph {
        chain("Human Approval", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.humanInput, ["question": .string("Approve this request?"),
                           "answer_key": .string("approval")], GraphPoint(x: 300, y: 160)),
            (.condition, ["expression": .string("approval equals approved")], GraphPoint(x: 540, y: 160)),
            (.end, ["output_key": .string("result")], GraphPoint(x: 780, y: 160)),
        ])
    }

    static func loopReport() -> WorkflowGraph {
        chain("Loop Report", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.loop, ["max_iterations": .string("5"),
                     "state_key": .string("loop_i")], GraphPoint(x: 300, y: 160)),
            (.end, ["output_key": .string("report")], GraphPoint(x: 540, y: 160)),
        ])
    }

    static func templateLetter() -> WorkflowGraph {
        chain("Template Letter", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.template, ["template": .string("Dear {{user}},\nYour request {{request}} is processed."),
                         "output_key": .string("letter")], GraphPoint(x: 300, y: 160)),
            (.end, ["output_key": .string("letter")], GraphPoint(x: 540, y: 160)),
        ])
    }

    static func subFlowCompose() -> WorkflowGraph {
        chain("Sub-Flow Compose", [
            (.start, [:], GraphPoint(x: 80, y: 160)),
            (.subFlow, ["flow_name": .string("Summarizer")], GraphPoint(x: 300, y: 160)),
            (.end, ["output_key": .string("result")], GraphPoint(x: 540, y: 160)),
        ])
    }

    // 首次启动播种 (已有模板不覆盖)
    static func seedIfEmpty(into store: WorkflowFlowStore) {
        guard let existing = try? store.listTemplates(), existing.isEmpty else { return }
        NodeRegistry.shared.bootstrapFullSet()
        var seeded = 0
        for t in all() {
            do {
                try store.saveAsTemplate(t.build(), templateName: t.name)
                seeded += 1
            } catch {
                tplLog.error("template seed failed \(t.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        tplLog.info("templates seeded: \(seeded)/\(all().count)")
    }
}

// MARK: - Gallery sheet (#431)

struct TemplateGallerySheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let flowStore: WorkflowFlowStore
    let onPick: (WorkflowGraph) -> Void

    @State private var templates: [WorkflowGraph] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("Templates")
                .font(.system(size: theme.textSize, weight: .semibold))
            if templates.isEmpty {
                Text("No templates yet — save any flow as a template from the toolbar.")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                List(templates) { t in
                    Button {
                        var picked = t
                        picked.id = UUID() // 实例化: 新 flow, 不共享模板 id
                        picked.backendId = nil
                        picked.pendingCheckpoint = nil
                        tplLog.info("template instantiated: \(t.name, privacy: .public)")
                        onPick(picked)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.text)
                            Text("\(t.nodes.count) nodes · \(t.edges.count) edges")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding(theme.spacingM)
        .frame(width: 380, height: 420)
        .task {
            guard !loaded else { return }
            loaded = true
            FlowTemplates.seedIfEmpty(into: flowStore)
            templates = (try? flowStore.listTemplates()) ?? []
        }
    }
}
