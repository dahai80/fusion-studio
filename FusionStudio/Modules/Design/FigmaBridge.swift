// Callers: DesignChatPanel (Figma import button), DesignBridge (importFromFigma)
// Affected API: FigmaBridge.fetchDesign(_:), Figma-Context-MCP protocol (future)
// Data schemas: FigmaDesignData (nodes/colors/typography/spacing/components), FigmaNode (id/name/type/boundingBox)
// User instruction: "继续完成遗留和defer的任务" — Phase 3 Task #15 Figma integration stub

import AppKit
import Foundation
import os.log

private let figmaLog = Logger(subsystem: "com.fusion.studio", category: "FigmaBridge")

struct FigmaNode: Identifiable {
    let id: String
    var name: String
    var type: String
    var boundingBox: [String: Double]?
    var children: [FigmaNode]?
    var styles: [String: String]?
}

struct FigmaDesignData {
    var fileKey: String
    var fileName: String
    var nodes: [FigmaNode]
    var colors: [String]
    var typography: [String: String]
    var spacing: [String: Double]
    var components: [String]
    var rawJSON: [String: Any]?
}

@MainActor
class FigmaBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var availableFiles: [String] = []
    @Published var importError: String?
    @Published var isImporting: Bool = false

    private var accessToken: String = ""
    private var mcpEndpoint: String = ""

    func configure(accessToken: String, mcpEndpoint: String = "") {
        self.accessToken = accessToken
        self.mcpEndpoint = mcpEndpoint
        figmaLog.info("FigmaBridge: configured with token (len=\(accessToken.count))")
    }

    func checkConnection() async -> Bool {
        figmaLog.warning("FigmaBridge: checkConnection — MCP not yet available")
        isConnected = false
        return false
    }

    func listFiles() async -> [String] {
        figmaLog.warning("FigmaBridge: listFiles — not yet implemented (blocked by MCP)")
        return []
    }

    func fetchDesign(fileKey: String) async -> FigmaDesignData? {
        figmaLog.warning("FigmaBridge: fetchDesign(\(fileKey)) — not yet implemented (blocked by MCP)")
        return nil
    }

    func fetchNodeImages(fileKey: String, nodeIds: [String]) async -> [String: NSImage] {
        figmaLog.warning("FigmaBridge: fetchNodeImages — not yet implemented (blocked by MCP)")
        return [:]
    }

    func convertToHTML(_ design: FigmaDesignData) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(design.fileName)</title>
            <script src="https://cdn.tailwindcss.com"></script>
        """

        if !design.colors.isEmpty {
            html += "\n    <style>\n    :root {\n"
            for (idx, color) in design.colors.enumerated() {
                html += "      --color-\(idx): \(color);\n"
            }
            html += "    }\n    </style>\n"
        }

        html += "</head>\n<body class=\"bg-gray-900 text-white\">\n"

        for node in design.nodes {
            html += renderNode(node, depth: 2)
        }

        html += "</body>\n</html>"
        figmaLog.info("FigmaBridge: converted Figma design to HTML (\(html.count) chars)")
        return html
    }

    private func renderNode(_ node: FigmaNode, depth: Int) -> String {
        let indent = String(repeating: " ", count: depth * 4)
        var result = ""

        switch node.type {
        case "FRAME", "GROUP":
            result += "\(indent)<div class=\"\(tailwindClasses(for: node))\">\n"
            if let children = node.children {
                for child in children {
                    result += renderNode(child, depth: depth + 1)
                }
            }
            result += "\(indent)</div>\n"
        case "TEXT":
            result += "\(indent)<span class=\"\(tailwindClasses(for: node))\">\(node.name)</span>\n"
        case "RECTANGLE":
            result += "\(indent)<div class=\"\(tailwindClasses(for: node))\"></div>\n"
        case "COMPONENT":
            result += "\(indent)<!-- Component: \(node.name) -->\n"
            result += "\(indent)<div class=\"\(tailwindClasses(for: node))\">\n"
            if let children = node.children {
                for child in children {
                    result += renderNode(child, depth: depth + 1)
                }
            }
            result += "\(indent)</div>\n"
        default:
            result += "\(indent)<!-- \(node.type): \(node.name) -->\n"
            if let children = node.children {
                for child in children {
                    result += renderNode(child, depth: depth + 1)
                }
            }
        }

        return result
    }

    private func tailwindClasses(for node: FigmaNode) -> String {
        var classes: [String] = []
        if let box = node.boundingBox {
            if let w = box["width"] { classes.append("w-\(Int(w))") }
            if let h = box["height"] { classes.append("h-\(Int(h))") }
        }
        if let styles = node.styles {
            if let bg = styles["background"] { classes.append("bg-\(bg)") }
            if let p = styles["padding"] { classes.append("p-\(p)") }
            if let r = styles["radius"] { classes.append("rounded-\(r)") }
        }
        return classes.joined(separator: " ")
    }

    func convertDesignToHTML(_ design: FigmaDesignData) -> String {
        return convertToHTML(design)
    }
}
