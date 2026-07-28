// Callers: DesignChatPanel (import button), DesignBridge (importFromPenpot), DesignBridgeTests
// Affected API: PenpotBridge.fetchDesign(_:), Penpot RPC API (get-profile, get-file, get-recent-files, export-binfile)
// Data schemas: PenpotDesignData (nodes/colors/typography/spacing/components), PenpotNode (id/name/type/boundingBox)
// User instruction: "改为开源的，在figma上改" — replace Figma API with Penpot open-source integration

import AppKit
import Foundation
import os.log

private let penpotLog = Logger(subsystem: "com.fusion.studio", category: "PenpotBridge")

struct PenpotNode: Identifiable {
    let id: String
    var name: String
    var type: String
    var boundingBox: [String: Double]?
    var children: [PenpotNode]?
    var styles: [String: String]?
}

struct PenpotDesignData {
    var fileKey: String
    var fileName: String
    var nodes: [PenpotNode]
    var colors: [String]
    var typography: [String: String]
    var spacing: [String: Double]
    var components: [String]
    var rawJSON: [String: Any]?
}

@MainActor
class PenpotBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var availableFiles: [String] = []
    @Published var importError: String?
    @Published var isImporting: Bool = false

    private var accessToken: String = ""
    private var host: String = "http://localhost:9001"
    private var sessionId: String = ""

    func configure(accessToken: String, host: String = "http://localhost:9001") {
        self.accessToken = accessToken
        self.host = host.hasSuffix("/") ? String(host.dropLast()) : host
        penpotLog.info("PenpotBridge: configured host=\(self.host) token(len=\(accessToken.count))")
    }

    // MARK: - Penpot RPC API

    private func rpcURL(method: String) -> URL {
        URL(string: "\(host)/rpc/command/\(method)")!
    }

    private func makeRequest(url: URL, body: [String: Any]? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty {
            req.setValue("Token \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if !sessionId.isEmpty {
            req.setValue(sessionId, forHTTPHeaderField: "Cookie")
        }
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    private func executeRPC(method: String, params: [String: Any] = [:]) async -> [String: Any]? {
        let url = rpcURL(method: method)
        let req = makeRequest(url: url, body: params)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                penpotLog.error("PenpotBridge: RPC \(method) — non-HTTP response")
                return nil
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                penpotLog.error("PenpotBridge: RPC \(method) — auth failed (\(http.statusCode))")
                return nil
            }
            if http.statusCode != 200 {
                penpotLog.error("PenpotBridge: RPC \(method) — status \(http.statusCode)")
                return nil
            }
            // Extract session cookie if present
            if let cookies = http.allHeaderFields["Set-Cookie"] as? String {
                if let range = cookies.range(of: "sid=", options: []),
                   let end = cookies[range.upperBound...].firstIndex(where: { $0 == ";" || $0 == "," }) {
                    sessionId = String(cookies[range.upperBound..<end])
                }
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
            if let str = String(data: data, encoding: .utf8) {
                penpotLog.info("PenpotBridge: RPC \(method) — non-object response (\(str.count) chars)")
                return ["_raw": str]
            }
            return nil
        } catch {
            penpotLog.error("PenpotBridge: RPC \(method) — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Public API

    func checkConnection() async -> Bool {
        penpotLog.info("PenpotBridge: checkConnection — testing \(self.host)")
        let result = await executeRPC(method: "get-profile")
        let connected = result != nil
        isConnected = connected
        penpotLog.info("PenpotBridge: checkConnection — \(connected ? "OK" : "FAILED")")
        return connected
    }

    func listFiles() async -> [String] {
        penpotLog.info("PenpotBridge: listFiles — fetching recent files")
        let result = await executeRPC(method: "get-recent-files", params: ["max": 50])
        guard let data = result else {
            penpotLog.warning("PenpotBridge: listFiles — no response")
            return []
        }
        var files: [String] = []
        if let recentFiles = data["data"] as? [[String: Any]] {
            for file in recentFiles {
                if let name = file["name"] as? String, let id = file["id"] as? String {
                    files.append("\(name) (\(id))")
                }
            }
        } else if let items = data["files"] as? [[String: Any]] {
            for file in items {
                if let name = file["name"] as? String, let id = file["id"] as? String {
                    files.append("\(name) (\(id))")
                }
            }
        } else {
            penpotLog.warning("PenpotBridge: listFiles — unexpected response format: \(data.keys)")
        }
        availableFiles = files
        penpotLog.info("PenpotBridge: listFiles — found \(files.count) files")
        return files
    }

    func fetchDesign(fileKey: String) async -> PenpotDesignData? {
        penpotLog.info("PenpotBridge: fetchDesign(\(fileKey))")
        isImporting = true
        importError = nil

        let result = await executeRPC(method: "get-file", params: ["id": fileKey])
        guard let data = result else {
            importError = "Failed to fetch file from Penpot"
            isImporting = false
            return nil
        }

        var fileName = fileKey
        if let name = data["name"] as? String {
            fileName = name
        }

        var rootNodes: [PenpotNode] = []
        var colors: [String] = []
        var typography: [String: String] = [:]
        let spacing: [String: Double] = [:]
        var components: [String] = []

        if let pages = data["pages"] as? [[String: Any]] {
            for page in pages {
                rootNodes.append(parsePenpotPage(page))
            }
        } else if let children = data["children"] as? [[String: Any]] {
            for child in children {
                rootNodes.append(parsePenpotNode(child))
            }
        }

        if let palette = data["colors"] as? [String: Any] {
            for (_, value) in palette {
                if let hex = value as? String {
                    colors.append(hex)
                } else if let colorObj = value as? [String: Any], let color = colorObj["color"] as? String {
                    colors.append(color)
                }
            }
        }

        if let typographies = data["typographies"] as? [String: Any] {
            for (name, value) in typographies {
                if let fontStr = value as? String {
                    typography[name] = fontStr
                } else if let fontObj = value as? [String: Any] {
                    let family = fontObj["fontFamily"] as? String ?? ""
                    let size = fontObj["fontSize"] as? Double ?? 0
                    let weight = fontObj["fontWeight"] as? String ?? "normal"
                    typography[name] = "\(family) \(weight) \(Int(size))px"
                }
            }
        }

        if let comps = data["components"] as? [String: Any] {
            for (name, _) in comps {
                components.append(name)
            }
        } else if let compInstances = data["componentInstances"] as? [[String: Any]] {
            for comp in compInstances {
                if let name = comp["name"] as? String {
                    components.append(name)
                }
            }
        }

        isImporting = false
        let designData = PenpotDesignData(
            fileKey: fileKey,
            fileName: fileName,
            nodes: rootNodes,
            colors: colors,
            typography: typography,
            spacing: spacing,
            components: components,
            rawJSON: data
        )
        penpotLog.info("PenpotBridge: fetchDesign — parsed \(rootNodes.count) pages, \(colors.count) colors, \(components.count) components")
        return designData
    }

    func fetchNodeImages(fileKey: String, nodeIds: [String]) async -> [String: NSImage] {
        penpotLog.info("PenpotBridge: fetchNodeImages(file=\(fileKey), \(nodeIds.count) nodes)")
        var images: [String: NSImage] = [:]
        for nodeId in nodeIds {
            let result = await executeRPC(
                method: "get-file-object-thumbnails",
                params: ["file-id": fileKey, "object-ids": [nodeId]]
            )
            guard let data = result,
                  let thumbnails = data["thumbnails"] as? [String: String],
                  let base64 = thumbnails[nodeId] else {
                penpotLog.warning("PenpotBridge: no thumbnail for node \(nodeId)")
                continue
            }
            if let imageData = Data(base64Encoded: base64),
               let image = NSImage(data: imageData) {
                images[nodeId] = image
            }
        }
        penpotLog.info("PenpotBridge: fetchNodeImages — got \(images.count)/\(nodeIds.count) images")
        return images
    }

    func exportPage(fileKey: String, pageId: String, format: String = "png") async -> Data? {
        penpotLog.info("PenpotBridge: exportPage(file=\(fileKey), page=\(pageId), format=\(format))")
        let result = await executeRPC(
            method: "export-binfile",
            params: ["file-id": fileKey, "page-id": pageId, "type": format, "scale": 2]
        )
        guard let data = result, let raw = data["_raw"] as? String else {
            penpotLog.warning("PenpotBridge: exportPage — no data returned")
            return nil
        }
        return Data(base64Encoded: raw)
    }

    // MARK: - Penpot Node Parsing

    private func parsePenpotPage(_ page: [String: Any]) -> PenpotNode {
        let id = page["id"] as? String ?? UUID().uuidString
        let name = page["name"] as? String ?? "Untitled Page"
        var children: [PenpotNode] = []
        if let pageChildren = page["children"] as? [[String: Any]] {
            for child in pageChildren {
                children.append(parsePenpotNode(child))
            }
        }
        return PenpotNode(id: id, name: name, type: "PAGE", boundingBox: nil, children: children, styles: nil)
    }

    private func parsePenpotNode(_ obj: [String: Any]) -> PenpotNode {
        let id = obj["id"] as? String ?? UUID().uuidString
        let name = obj["name"] as? String ?? ""
        let type = obj["type"] as? String ?? "UNKNOWN"

        var boundingBox: [String: Double]? = nil
        if let x = obj["x"] as? Double, let y = obj["y"] as? Double,
           let w = obj["width"] as? Double, let h = obj["height"] as? Double {
            boundingBox = ["x": x, "y": y, "width": w, "height": h]
        }

        var styles: [String: String]? = nil
        if let fills = obj["fills"] as? [[String: Any]],
           let firstFill = fills.first,
           let fillColor = firstFill["color"] as? String {
            styles = ["background": fillColor.replacingOccurrences(of: "#", with: "")]
        }
        if let strokes = obj["strokes"] as? [[String: Any]],
           let firstStroke = strokes.first,
           let strokeColor = firstStroke["color"] as? String {
            if styles != nil {
                styles?["border"] = strokeColor
            } else {
                styles = ["border": strokeColor]
            }
        }
        if let r = obj["r"] as? Double, r > 0 {
            if styles != nil {
                styles?["radius"] = String(Int(r))
            } else {
                styles = ["radius": String(Int(r))]
            }
        }
        if let padding = obj["padding"] as? [String: Double],
           let p = padding["top"] ?? padding["p1"] {
            if styles != nil {
                styles?["padding"] = String(Int(p))
            } else {
                styles = ["padding": String(Int(p))]
            }
        }

        var children: [PenpotNode]? = nil
        if let childObjects = obj["children"] as? [[String: Any]] {
            children = childObjects.map { parsePenpotNode($0) }
        }

        return PenpotNode(id: id, name: name, type: mapPenpotType(type), boundingBox: boundingBox, children: children, styles: styles)
    }

    private func mapPenpotType(_ penpotType: String) -> String {
        switch penpotType {
        case "frame": return "FRAME"
        case "group": return "GROUP"
        case "rect": return "RECTANGLE"
        case "text": return "TEXT"
        case "component", "component-instance": return "COMPONENT"
        case "circle", "ellipse": return "ELLIPSE"
        case "path": return "PATH"
        case "image": return "IMAGE"
        case "svg-raw": return "SVG"
        default: return penpotType.uppercased()
        }
    }

    // MARK: - HTML Conversion (design-tool-agnostic)

    func convertToHTML(_ design: PenpotDesignData) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(design.fileName)</title>
            <script src="https://cdn.tailwindcss.com" integrity="sha384-0isd3pNtJi0sKmohLqyXZqWvJN9SgJkqLdJN5S0lOA0fFW7Ro5C7Yi6VBwS1PfQ" crossorigin="anonymous"></script>
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
        penpotLog.info("PenpotBridge: converted design to HTML (\(html.count) chars)")
        return html
    }

    private func renderNode(_ node: PenpotNode, depth: Int) -> String {
        let indent = String(repeating: " ", count: depth * 4)
        var result = ""

        switch node.type {
        case "FRAME", "GROUP", "PAGE":
            result += "\(indent)<div class=\"\(tailwindClasses(for: node))\">\n"
            if let children = node.children {
                for child in children {
                    result += renderNode(child, depth: depth + 1)
                }
            }
            result += "\(indent)</div>\n"
        case "TEXT":
            result += "\(indent)<span class=\"\(tailwindClasses(for: node))\">\(node.name)</span>\n"
        case "RECTANGLE", "ELLIPSE":
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
        case "IMAGE":
            result += "\(indent)<!-- Image: \(node.name) -->\n"
            result += "\(indent)<div class=\"\(tailwindClasses(for: node)) bg-gray-700\"></div>\n"
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

    private func tailwindClasses(for node: PenpotNode) -> String {
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

    func convertDesignToHTML(_ design: PenpotDesignData) -> String {
        return convertToHTML(design)
    }
}
