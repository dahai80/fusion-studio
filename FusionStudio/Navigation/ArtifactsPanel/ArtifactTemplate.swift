import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct ArtifactTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let type: String
    let kind: ArtifactKind
    let defaultContent: String
}

let artifactTemplates: [ArtifactTemplate] = [
    ArtifactTemplate(
        id: "apps-and-websites",
        name: "Apps and websites",
        icon: "globe",
        description: "A new interactive artifact for a website, app surface, or product workflow.",
        type: "html",
        kind: .app,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>My App</title>\n  <style>\n    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; }\n  </style>\n</head>\n<body>\n  <h1>Hello World</h1>\n  <p>Start building your app here.</p>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "documents-and-templates",
        name: "Documents and templates",
        icon: "doc.text",
        description: "A structured artifact for a document, repeatable template, or formatted brief.",
        type: "markdown",
        kind: .document,
        defaultContent: "# Document Title\n\n## Overview\n\nStart writing your document here.\n\n## Details\n\n- Point 1\n- Point 2\n- Point 3\n\n## Summary\n\nTBD"
    ),
    ArtifactTemplate(
        id: "games",
        name: "Games",
        icon: "gamecontroller",
        description: "A playable artifact for a game, simulation, or interactive challenge.",
        type: "html",
        kind: .game,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>My Game</title>\n  <style>\n    canvas { border: 1px solid #333; display: block; margin: 20px auto; }\n  </style>\n</head>\n<body>\n  <h1 style=\"text-align:center\">Game</h1>\n  <canvas id=\"canvas\" width=\"480\" height=\"320\"></canvas>\n  <script>\n    const canvas = document.getElementById('canvas');\n    const ctx = canvas.getContext('2d');\n    ctx.fillStyle = '#007AFF';\n    ctx.fillRect(10, 10, 50, 50);\n  </script>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "productivity-tools",
        name: "Productivity tools",
        icon: "chart.bar",
        description: "A utility artifact for planning, tracking, calculating, or repeatable work.",
        type: "html",
        kind: .tool,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>Productivity Tool</title>\n  <style>\n    body { font-family: -apple-system, sans-serif; padding: 20px; }\n    input, button { padding: 8px 12px; margin: 4px; }\n  </style>\n</head>\n<body>\n  <h1>Tool</h1>\n  <input type=\"text\" placeholder=\"Enter value...\">\n  <button onclick=\"alert('Done')\">Process</button>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "creative-projects",
        name: "Creative projects",
        icon: "paintbrush",
        description: "A visual or expressive artifact for creative exploration and presentation.",
        type: "html",
        kind: .template,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>Creative Project</title>\n  <style>\n    body { margin: 0; overflow: hidden; background: #1a1a2e; }\n    canvas { display: block; }\n  </style>\n</head>\n<body>\n  <canvas id=\"canvas\"></canvas>\n  <script>\n    const c = document.getElementById('canvas');\n    const ctx = c.getContext('2d');\n    c.width = window.innerWidth;\n    c.height = window.innerHeight;\n    ctx.fillStyle = '#e94560';\n    ctx.beginPath();\n    ctx.arc(c.width/2, c.height/2, 80, 0, Math.PI*2);\n    ctx.fill();\n  </script>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "quiz-or-survey",
        name: "Quiz or survey",
        icon: "questionmark.circle",
        description: "A question-led artifact for collecting answers, testing knowledge, or guiding choices.",
        type: "html",
        kind: .template,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>Quiz</title>\n  <style>\n    body { font-family: -apple-system, sans-serif; padding: 20px; max-width: 600px; margin: auto; }\n    .question { margin: 16px 0; padding: 12px; border: 1px solid #ddd; border-radius: 8px; }\n    label { display: block; padding: 4px 0; }\n  </style>\n</head>\n<body>\n  <h1>Quiz</h1>\n  <div class=\"question\">\n    <p>Question 1?</p>\n    <label><input type=\"radio\" name=\"q1\"> Option A</label>\n    <label><input type=\"radio\" name=\"q1\"> Option B</label>\n    <label><input type=\"radio\" name=\"q1\"> Option C</label>\n  </div>\n  <button onclick=\"alert('Submitted!')\">Submit</button>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "start-from-scratch",
        name: "Start from scratch",
        icon: "pencil.and.outline",
        description: "A blank artifact canvas ready for a custom idea.",
        type: "code",
        kind: .app,
        defaultContent: ""
    )
]

// MARK: - TemplatePickerSheet

