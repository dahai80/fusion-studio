// F-I11: en-US locale prompt set — translated. Natural language translated,
// technical directives verbatim (antArtifact tag, CSS :root block, hex, JSON format, Tailwind/CDN/dark/HTML/React).

import Foundation

extension DesignPrompts {

    static let enUS = DesignPromptSet(
        systemPrompt: """
        You are Fusion Studio's professional UI designer and front-end engineer. Generate high-quality HTML component code based on user requirements.

        ## Output Specification

        1. Use Tailwind CSS (CDN) for styling, no inline styles
        2. Components must be self-contained complete HTML documents, runnable directly in the browser
        3. Support dark theme (default dark background #1a1a2e, text #e0e0e0)
        4. Responsive layout, using Tailwind's responsive prefixes
        5. Interactive logic implemented with inline <script>
        6. No frameworks (React/Vue/Angular), pure HTML + Tailwind + vanilla JS
        7. Define design tokens with CSS variables:

        :root {
          --color-primary: #007AFF;
          --color-secondary: #5856D6;
          --color-success: #34C759;
          --color-warning: #FF9500;
          --color-error: #FF3B30;
          --color-bg: #1a1a2e;
          --color-surface: #16213e;
          --color-text: #e0e0e0;
          --color-text-secondary: #a0a0a0;
          --radius-sm: 6px;
          --radius-md: 10px;
          --radius-lg: 16px;
          --spacing-xs: 4px;
          --spacing-sm: 8px;
          --spacing-md: 16px;
          --spacing-lg: 24px;
        }

        ## Output Format

        Wrap generated code with the antArtifact tag:

        <antArtifact type="html" title="Component Name">
        Complete HTML code...
        </antArtifact>

        If the user requests modification of an existing design, output only the complete modified code (still wrapped in antArtifact), do not output a diff.
        Do not add extra explanation beyond the code; the code is the final product.
        """,
        templatePrompts: [
            "login": "Design a modern login page, dark theme, supporting email and password login, with a \"Remember me\" option and a \"Forgot password\" link, social login buttons at the bottom",
            "dashboard": "Design a data dashboard page, dark theme, top navigation bar, left sidebar menu, main area with 4 data cards + a line chart area + a data table",
            "landing": "Design a product landing page, dark theme, including: navigation bar, Hero area (large title + subtitle + CTA button), feature introduction area (3 columns), pricing area (3 pricing cards), footer",
            "settings": "Design a settings page, dark theme, left tab navigation (General/Security/Notifications/Appearance), right corresponding settings content, using form controls (switches/selectors/inputs)",
            "chat": "Design a chat interface, dark theme, left conversation list, right chat area (message bubbles + input box), supporting send button and attachment button",
            "profile": "Design a personal profile page, dark theme, top avatar + name + bio, below tab switching (Activity/Favorites/About), displaying a card list",
            "card": "Design a set of card components: standard card, featured card (with image), outline card, 3 sizes each, using Fusion Design tokens",
            "form": "Design a registration form, dark theme, including: username, email, password (with strength indicator), confirm password, agree-to-terms checkbox, submit button, with form validation logic",
            "table": "Design an interactive data table page, dark theme, supporting sorting, search filtering, pagination, action buttons per row (edit/delete), sortable clickable headers",
            "nav": "Design a set of navigation components: top navigation bar (with search + user avatar), sidebar navigation (collapsible + icons + labels), breadcrumb navigation, dark theme",
            "modal": "Design a set of modal components: confirmation dialog, form modal, full-screen modal, bottom drawer, with overlay and animation, dark theme",
            "buttons": "Design a set of button components: primary/secondary/outline/text/danger buttons, each with default/hover/active/disabled states, dark theme",
        ],
        pageFlowDefaultNames: ["Home", "List", "Detail"],
        multiVariantsDefaultStyles: ["Minimal", "Modern", "Clean"],
        fallbackTextToUI: "Design a modern dark-theme page",
        fallbackImageToUIHint: "Generate UI layout referencing the image",
        fallbackMultiVariants: "Design a data card component",
        fallbackLocalEditInstruction: "Modify the selected element",
        fallbackPartialEditInstruction: "Optimize the visual style of the selected nodes",
        fallbackSimPanel: "Generate style variants",
        fallbackSpecDoc: "Output the complete design specification",
        fallbackPageFlow: "Home → List → Detail navigation flow",
        applyLocalEditContext: { nodesJSON, instruction in
            "Current state of selected nodes:\n\(nodesJSON)\n\nPlease modify the above nodes to satisfy: \(instruction)\n\nOutput only the JSON array of modified nodes, no other content. Format: [{\"id\":\"...\", ...modified properties}]"
        },
        skillImageToUIPrompt: { imagePath, hint, pageName in
            "Reference image path: \(imagePath)\nAdditional note: \(hint)\nGenerate the UI layout for the page \"\(pageName)\""
        },
        skillPartialEditPrompt: { nodesJSON, instruction in
            "Make a partial modification to the following nodes:\n\(nodesJSON)\n\nModification requirement: \(instruction)\n\nOutput only the complete JSON of the modified nodes, keeping the id unchanged. Format: [{\"id\":\"...\", ...all properties}]"
        },
        skillSimPanelPrompt: { prompt in
            "Generate panel variants similar to the current design but with a different style. Requirement: \(prompt)\n\nKeep the functionality the same, but adjust visual properties such as color, spacing, and corner radius, producing 3 variant proposals."
        },
        skillSpecDocPrompt: { prompt in
            "Based on the current design, generate a design specification document, including:\n1. Design tokens (color, font, spacing, corner radius)\n2. Component specifications (buttons, cards, inputs, etc.)\n3. Layout rules\n4. Interaction state specifications\n\nAdditional requirement: \(prompt)"
        },
        pageFlowPerPage: { idx, name, prompt in
            "Page \(idx+1) \"\(name)\": \(prompt)"
        },
        pageFlowFlowPrompt: { flowDesc in
            "Design a multi-page flow, including the navigation relationships between the following pages:\n\(flowDesc)\n\nEach page must include navigation elements (buttons/links) pointing to the next page."
        },
        pageFlowPagePrompt: { flowPrompt, idx, pageName in
            "\(flowPrompt)\n\nCurrently generating: Page \(idx+1) \"\(pageName)\""
        },
        multiVariantsStyledPrompt: { prompt, style in
            "\(prompt) (Style: \(style))"
        },
        sendDesignChatArtifactAppend: { currentArtifactCode in
            "\n\nCurrent design code:\n```html\n\(currentArtifactCode)\n```\nPlease iterate on this code."
        },
        sendDesignChatRagAppend: { rag in
            "\n\nProject design specification:\n\(rag)"
        }
    )
}
