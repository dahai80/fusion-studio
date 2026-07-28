// Callers: DesignChatPanel (export button), DesignBridge.exportAsSwiftUI
// Affected API: SwiftUIExporter struct (buildConversionRequest, swiftUIViewName, extractSwiftUICode)
// Data schemas: HTML input string, SwiftUI code output string, conversion prompt template
// User instruction: "continue" — Phase 3 Task #36 SwiftUI code export

import Foundation
import os.log

private let exporterLog = Logger(subsystem: "com.fusion.studio", category: "SwiftUIExporter")

struct SwiftUIExporter {

    static let conversionPrompt = """
    You are an expert iOS/macOS developer. Convert the following HTML/Tailwind CSS code into a native SwiftUI View.

    Rules:
    1. Use SwiftUI native components (VStack, HStack, Text, Image, Button, etc.)
    2. Apply SwiftUI modifiers for styling (font, foregroundColor, padding, background, etc.)
    3. Match the visual layout as closely as possible
    4. Use Apple HIG design principles
    5. Make the view previewable with #Preview
    6. Use descriptive variable names
    7. If the HTML uses Tailwind utility classes, map them to equivalent SwiftUI modifiers
    8. Output ONLY the SwiftUI code, no explanations

    Common Tailwind → SwiftUI mappings:
    - flex → HStack/VStack
    - items-center → alignment or frame
    - justify-center → Spacer + alignment
    - p-4/m-4 → padding()
    - bg-blue-500 → .background(Color.blue)
    - text-white → .foregroundStyle(.white)
    - rounded-lg → .clipShape(RoundedRectangle())
    - shadow-lg → .shadow()
    - w-full → .frame(maxWidth: .infinity)
    - h-screen → .frame(maxHeight: .infinity)

    HTML code to convert:

    """

    static func buildConversionRequest(htmlCode: String, title: String) -> (prompt: String, title: String) {
        let prompt = conversionPrompt + "```html\n\(htmlCode)\n```\n\nConvert to a SwiftUI View named `\(swiftUIViewName(from: title))`."
        return (prompt, title)
    }

    static func swiftUIViewName(from title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
        let name = cleaned.isEmpty ? "DesignView" : cleaned + "View"
        exporterLog.info("SwiftUIExporter: generated view name '\(name)' from '\(title)'")
        return name
    }

    static func extractSwiftUICode(from response: String) -> String {
        if let startRange = response.range(of: "```swift"),
           let codeStart = response.range(of: "\n", range: startRange.upperBound..<response.endIndex) {
            let afterOpen = codeStart.upperBound
            if let endRange = response.range(of: "```", range: afterOpen..<response.endIndex) {
                return String(response[afterOpen..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if response.contains("import SwiftUI") || response.contains("struct ") {
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
