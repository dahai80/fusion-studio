import Foundation
import os.log

private let exporterLog = Logger(subsystem: "com.fusion.studio", category: "ReactVueExporter")

struct ReactExporter {

    static let conversionPrompt = """
    You are an expert React developer. Convert the following HTML/Tailwind CSS code into a React functional component.

    Rules:
    1. Use React functional components with hooks
    2. Use JSX syntax with className instead of class
    3. Apply Tailwind CSS utility classes directly in className
    4. Use proper React event handlers (onClick, onChange, etc.)
    5. Add PropTypes or TypeScript interface for props if component accepts them
    6. Export the component as default export
    7. Make the component responsive and accessible
    8. Output ONLY the React code, no explanations

    Common HTML → React mappings:
    - class → className
    - onclick → onClick
    - onchange → onChange
    - for → htmlFor
    - tabindex → tabIndex
    - readonly → readOnly
    - maxlength → maxLength

    HTML code to convert:

    """

    static func buildConversionRequest(htmlCode: String, title: String) -> (prompt: String, title: String) {
        let name = reactComponentName(from: title)
        let prompt = conversionPrompt + "```html\n\(htmlCode)\n```\n\nConvert to a React component named `\(name)`."
        return (prompt, title)
    }

    static func reactComponentName(from title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
        let name = cleaned.isEmpty ? "DesignComponent" : cleaned
        exporterLog.info("ReactExporter: generated component name '\(name)' from '\(title)'")
        return name
    }

    static func extractReactCode(from response: String) -> String {
        for tag in ["jsx", "tsx", "javascript", "typescript"] {
            if let startRange = response.range(of: "```\(tag)"),
               let codeStart = response.range(of: "\n", range: startRange.upperBound..<response.endIndex) {
                let afterOpen = codeStart.upperBound
                if let endRange = response.range(of: "```", range: afterOpen..<response.endIndex) {
                    return String(response[afterOpen..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        if response.contains("import React") || response.contains("export default") || response.contains("function ") {
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct VueExporter {

    static let conversionPrompt = """
    You are an expert Vue.js developer. Convert the following HTML/Tailwind CSS code into a Vue 3 Single File Component (SFC).

    Rules:
    1. Use Vue 3 Composition API with <script setup>
    2. Use <template> section with proper Vue directives (v-if, v-for, v-model, @click, etc.)
    3. Apply Tailwind CSS utility classes in class attributes
    4. Define props with defineProps(), emit with defineEmits()
    5. Use ref() and reactive() for reactivity
    6. Include <style scoped> if custom styles are needed
    7. Make the component responsive and accessible
    8. Output ONLY the Vue SFC code, no explanations

    Common HTML → Vue mappings:
    - onclick → @click
    - onchange → @change or v-model
    - oninput → @input or v-model
    - onsubmit → @submit.prevent
    - value → v-model or :value
    - disabled → :disabled

    HTML code to convert:

    """

    static func buildConversionRequest(htmlCode: String, title: String) -> (prompt: String, title: String) {
        let name = vueComponentName(from: title)
        let prompt = conversionPrompt + "```html\n\(htmlCode)\n```\n\nConvert to a Vue 3 SFC component named `\(name)`."
        return (prompt, title)
    }

    static func vueComponentName(from title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
        let name = cleaned.isEmpty ? "DesignComponent" : cleaned
        exporterLog.info("VueExporter: generated component name '\(name)' from '\(title)'")
        return name
    }

    static func extractVueCode(from response: String) -> String {
        if let startRange = response.range(of: "```vue"),
           let codeStart = response.range(of: "\n", range: startRange.upperBound..<response.endIndex) {
            let afterOpen = codeStart.upperBound
            if let endRange = response.range(of: "```", range: afterOpen..<response.endIndex) {
                return String(response[afterOpen..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if response.contains("<template>") && response.contains("<script") {
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
