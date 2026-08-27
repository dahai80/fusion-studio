import SwiftUI


struct WorkflowDagCanvas: View {
    @Environment(\.studioTheme) private var theme
    let nodeCount: Int
    let status: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(theme.surfaceSecondary)

            let nodes = generateDagNodes()
            let edges = generateDagEdges(nodes: nodes)

            Canvas { context, size in
                for edge in edges {
                    var path = Path()
                    path.move(to: edge.from)
                    let ctrl1 = CGPoint(
                        x: edge.from.x + (edge.to.x - edge.from.x) * 0.4,
                        y: edge.from.y
                    )
                    let ctrl2 = CGPoint(
                        x: edge.from.x + (edge.to.x - edge.from.x) * 0.6,
                        y: edge.to.y
                    )
                    path.addCurve(to: edge.to, control1: ctrl1, control2: ctrl2)
                    context.stroke(
                        path,
                        with: .color(status == "running" ? theme.accent.opacity(0.5) : theme.textTertiary.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 1.5, dash: status == "running" ? [] : [4, 3])
                    )
                }

                for node in nodes {
                    let rect = CGRect(
                        x: node.pos.x - node.size.width / 2,
                        y: node.pos.y - node.size.height / 2,
                        width: node.size.width,
                        height: node.size.height
                    )
                    let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                    context.fill(
                        shape.path(in: rect),
                        with: .color(node.color.opacity(0.7))
                    )
                    context.stroke(
                        shape.path(in: rect),
                        with: .color(node.color),
                        lineWidth: 1
                    )
                    let text = Text(node.label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white)
                    context.draw(text, at: node.pos)
                }
            }
        }
    }

    private struct DagNode {
        let pos: CGPoint
        let size: CGSize
        let label: String
        let color: Color
    }

    private struct DagEdge {
        let from: CGPoint
        let to: CGPoint
    }

    private func generateDagNodes() -> [DagNode] {
        let count = max(nodeCount, 3)
        let labels = [I18nManager.shared.t(.spl_step_input)] + (1...(count - 2)).map { "Step \($0)" } + [I18nManager.shared.t(.spl_step_output)]
        let colors: [Color] = [.blue] + (1...(count - 2)).map { _ in theme.accent } + [.green]
        let w: CGFloat = 260
        let h: CGFloat = 120
        let padX: CGFloat = 40
        let padY: CGFloat = 20
        let usableW = w - padX * 2
        let usableH = h - padY * 2

        return (0..<count).map { i in
            let x = count == 1 ? w / 2 : padX + usableW * CGFloat(i) / CGFloat(count - 1)
            let y = h / 2 + sin(Double(i) * 0.8) * usableH * 0.3
            return DagNode(
                pos: CGPoint(x: x, y: y),
                size: CGSize(width: 44, height: 22),
                label: labels[i],
                color: colors[i]
            )
        }
    }

    private func generateDagEdges(nodes: [DagNode]) -> [DagEdge] {
        guard nodes.count >= 2 else { return [] }
        var edges: [DagEdge] = []
        for i in 0..<(nodes.count - 1) {
            edges.append(DagEdge(from: nodes[i].pos, to: nodes[i + 1].pos))
        }
        if nodes.count > 3 {
            edges.append(DagEdge(from: nodes[0].pos, to: nodes[2].pos))
        }
        return edges
    }
}

// MARK: - Page 7.7: 桌面共享
