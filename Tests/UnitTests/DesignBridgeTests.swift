// Callers: Swift test runner (swift test).
// Reads: DesignMessage, ArtifactParseResult, DesignPage, DesignBridge published properties
// User instruction: "continue" — Phase 3 Task #34 multi-page tests

import XCTest
@testable import FusionStudio

final class DesignBridgeTests: XCTestCase {

    // MARK: - antArtifact XML Parsing

    func testExtractArtifactFromComplete() async {
        let content = """
        Here is your design:
        <antArtifact type="html" title="Login Page" identifier="login-001">
        <div class="flex items-center justify-center min-h-screen">
          <h1>Login</h1>
        </div>
        </antArtifact>
        Hope you like it!
        """
        let result = await DesignBridge().extractArtifactFromComplete(content)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, "html")
        XCTAssertEqual(result?.title, "Login Page")
        XCTAssertEqual(result?.identifier, "login-001")
        XCTAssertTrue(result?.code.contains("Login") == true)
    }

    func testExtractArtifactNoArtifact() async {
        let result = await DesignBridge().extractArtifactFromComplete("Just a plain text response without any artifact.")
        XCTAssertNil(result)
    }

    func testExtractArtifactWithReact() async {
        let content = """
        <antArtifact type="react" title="Dashboard" identifier="dash-002">
        export default function App() { return <div>Hi</div> }
        </antArtifact>
        """
        let result = await DesignBridge().extractArtifactFromComplete(content)
        XCTAssertEqual(result?.type, "react")
        XCTAssertEqual(result?.title, "Dashboard")
    }

    // MARK: - Code Block Extraction

    func testExtractCodeBlockHTML() async {
        let content = """
        Here is the code:
        ```html
        <div>Hello</div>
        ```
        End.
        """
        let code = await DesignBridge().extractCodeBlock(from: content)
        XCTAssertEqual(code, "<div>Hello</div>")
    }

    func testExtractCodeBlockNoFence() async {
        let code = await DesignBridge().extractCodeBlock(from: "No code fences here.")
        XCTAssertEqual(code, "")
    }

    // MARK: - DesignMessage

    func testDesignMessageIdentity() {
        let msg1 = DesignMessage(role: "user", content: "hi", timestamp: Date())
        let msg2 = DesignMessage(role: "user", content: "hi", timestamp: Date())
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    // MARK: - PreviewDeviceMode

    func testPreviewDeviceModeWidths() {
        XCTAssertEqual(PreviewDeviceMode.mobile.width, 375)
        XCTAssertEqual(PreviewDeviceMode.tablet.width, 768)
        XCTAssertNil(PreviewDeviceMode.desktop.width)
    }

    func testPreviewDeviceModeAllCases() {
        XCTAssertEqual(PreviewDeviceMode.allCases.count, 3)
    }

    // MARK: - DesignPrompts

    func testSystemPromptNotEmpty() {
        XCTAssertFalse(DesignPrompts.systemPrompt.isEmpty)
    }

    func testSystemPromptContainsAntArtifact() {
        XCTAssertTrue(DesignPrompts.systemPrompt.contains("antArtifact"))
    }

    func testQuickTemplatesCount() {
        XCTAssertTrue(DesignPrompts.quickTemplates.count >= 8)
    }

    func testQuickTemplatesHaveIcons() {
        for tmpl in DesignPrompts.quickTemplates {
            XCTAssertFalse(tmpl.icon.isEmpty, "Template '\(tmpl.name)' missing icon")
            XCTAssertFalse(tmpl.name.isEmpty, "Template missing name")
            XCTAssertFalse(tmpl.prompt.isEmpty, "Template '\(tmpl.name)' missing prompt")
        }
    }

    // MARK: - Clear Conversation

    func testClearConversation() async {
        let bridge = await DesignBridge()
        await bridge.clearConversation()
        let msgs = await bridge.messages
        let code = await bridge.currentArtifactCode
        let title = await bridge.currentArtifactTitle
        let saved = await bridge.artifactSaved
        XCTAssertTrue(msgs.isEmpty)
        XCTAssertTrue(code.isEmpty)
        XCTAssertTrue(title.isEmpty)
        XCTAssertFalse(saved)
    }

    // MARK: - kindForType

    func testKindForType() async {
        let bridge = await DesignBridge()
        let html = await bridge.kindForType("html")
        let react = await bridge.kindForType("react")
        let md = await bridge.kindForType("markdown")
        let py = await bridge.kindForType("python")
        XCTAssertEqual(html, "app")
        XCTAssertEqual(react, "app")
        XCTAssertEqual(md, "document")
        XCTAssertEqual(py, "code")
    }

    // MARK: - buildFullHTML

    func testBuildFullHTMLBareCode() {
        let html = DesignPreviewView(htmlContent: .constant(""), deviceMode: .desktop)
            .buildFullHTML("<h1>Hello</h1>")
        XCTAssertTrue(html.contains("<!DOCTYPE"))
        XCTAssertTrue(html.contains("--color-primary: #007AFF"))
        XCTAssertTrue(html.contains("<h1>Hello</h1>"))
    }

    func testBuildFullHTMLExistingDoc() {
        let existing = """
        <!DOCTYPE html>
        <html>
        <head><title>Test</title></head>
        <body><h1>Existing</h1></body>
        </html>
        """
        let html = DesignPreviewView(htmlContent: .constant(""), deviceMode: .desktop)
            .buildFullHTML(existing)
        XCTAssertTrue(html.contains("<h1>Existing</h1>"))
    }

    func testBuildFullHTMLAlreadyHasTailwind() {
        let existing = """
        <!DOCTYPE html>
        <html>
        <head><script src="https://cdn.tailwindcss.com"></script></head>
        <body><h1>Tailwind</h1></body>
        </html>
        """
        let html = DesignPreviewView(htmlContent: .constant(""), deviceMode: .desktop)
            .buildFullHTML(existing)
        let count = html.components(separatedBy: "tailwindcss").count - 1
        XCTAssertLessThanOrEqual(count, 1, "Tailwind should not be injected twice")
    }
}

// MARK: - DesignTokenPanel Tests

extension DesignBridgeTests {

    func testDesignTokenCategoryAllCases() {
        XCTAssertEqual(DesignTokenCategory.allCases.count, 6)
    }

    func testDesignTokenCategoryIcons() {
        for cat in DesignTokenCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat.rawValue) should have an icon")
        }
    }

    func testDesignTokenCategoryRawValues() {
        XCTAssertEqual(DesignTokenCategory.colors.rawValue, "颜色")
        XCTAssertEqual(DesignTokenCategory.spacing.rawValue, "间距")
        XCTAssertEqual(DesignTokenCategory.typography.rawValue, "排版")
        XCTAssertEqual(DesignTokenCategory.radius.rawValue, "圆角")
        XCTAssertEqual(DesignTokenCategory.shadows.rawValue, "阴影")
        XCTAssertEqual(DesignTokenCategory.animation.rawValue, "动画")
    }

    func testInfoPanelTabAllCases() {
        let tabs = InfoPanelTab.allCases
        XCTAssertEqual(tabs.count, 2)
        XCTAssertEqual(tabs[0].rawValue, "属性")
        XCTAssertEqual(tabs[1].rawValue, "Design System")
    }

    func testInfoPanelTabIcons() {
        let propTab = InfoPanelTab.properties
        let tokenTab = InfoPanelTab.tokens
        XCTAssertFalse(propTab.icon.isEmpty)
        XCTAssertFalse(tokenTab.icon.isEmpty)
    }
}

// MARK: - Multi-Page Tests

@MainActor
extension DesignBridgeTests {

    func testDesignPageInit() {
        let page = DesignPage(title: "Test Page", type: "html", code: "<h1>Hi</h1>")
        XCTAssertEqual(page.title, "Test Page")
        XCTAssertEqual(page.type, "html")
        XCTAssertTrue(page.artifactId.isEmpty)
    }

    func testAddPage() async {
        let bridge = DesignBridge()
        await bridge.addPage()
        let count = bridge.pages.count
        let idx = bridge.currentPageIndex
        XCTAssertEqual(count, 1)
        XCTAssertEqual(idx, 0)
    }

    func testSwitchPage() async {
        let bridge = DesignBridge()
        await bridge.addPage()
        bridge.currentArtifactCode = "<h1>P1</h1>"
        bridge.currentArtifactTitle = "P1"
        await bridge.addPage()
        bridge.currentArtifactCode = "<h1>P2</h1>"
        bridge.currentArtifactTitle = "P2"
        await bridge.switchToPage(at: 0)
        let title = bridge.currentArtifactTitle
        XCTAssertEqual(title, "P1")
    }

    func testDeletePage() async {
        let bridge = DesignBridge()
        await bridge.addPage()
        await bridge.addPage()
        await bridge.deletePage(at: 0)
        let count = bridge.pages.count
        XCTAssertEqual(count, 1)
    }

    func testRenamePage() async {
        let bridge = DesignBridge()
        await bridge.addPage()
        await bridge.renamePage(at: 0, newTitle: "Renamed")
        let name = bridge.pages[0].title
        XCTAssertEqual(name, "Renamed")
    }

    func testClearConversationResetsPages() async {
        let bridge = DesignBridge()
        await bridge.addPage()
        bridge.clearConversation()
        XCTAssertTrue(bridge.pages.isEmpty)
        let idx = bridge.currentPageIndex
        XCTAssertEqual(idx, -1)
    }
}

// MARK: - RAG Tests

@MainActor
extension DesignBridgeTests {

    func testFetchRAGContextNoIPC() async {
        let bridge = DesignBridge()
        let result = await bridge.fetchRAGContext(for: "button styles")
        XCTAssertNil(result)
    }

    func testIngestDesignTokensNoIPC() async {
        let bridge = DesignBridge()
        await bridge.ingestDesignTokens()
    }
}

// MARK: - SwiftUIExporter Tests

extension DesignBridgeTests {

    func testSwiftUIViewNameFromTitle() {
        let name = SwiftUIExporter.swiftUIViewName(from: "Login Page")
        XCTAssertEqual(name, "LoginPageView")
    }

    func testSwiftUIViewNameEmpty() {
        let name = SwiftUIExporter.swiftUIViewName(from: "")
        XCTAssertEqual(name, "DesignView")
    }

    func testSwiftUIViewNameSpecialChars() {
        let name = SwiftUIExporter.swiftUIViewName(from: "Hello-World_123")
        XCTAssertEqual(name, "HelloWorld123View")
    }

    func testExtractSwiftUICodeFromFence() {
        let response = "Here is the code:\n```swift\nimport SwiftUI\nstruct TestView: View {\n    var body: some View { Text(\"Hi\") }\n}\n```\nDone."
        let code = SwiftUIExporter.extractSwiftUICode(from: response)
        XCTAssertTrue(code.contains("import SwiftUI"))
        XCTAssertTrue(code.contains("struct TestView"))
    }

    func testExtractSwiftUICodeNoFence() {
        let response = "import SwiftUI\nstruct TestView: View {\n    var body: some View { Text(\"Hi\") }\n}"
        let code = SwiftUIExporter.extractSwiftUICode(from: response)
        XCTAssertTrue(code.contains("import SwiftUI"))
    }

    func testBuildConversionRequest() {
        let req = SwiftUIExporter.buildConversionRequest(htmlCode: "<h1>Hi</h1>", title: "Login")
        XCTAssertTrue(req.prompt.contains("<h1>Hi</h1>"))
        XCTAssertTrue(req.prompt.contains("LoginView"))
    }
}

// MARK: - ScreenshotImporter Tests

extension DesignBridgeTests {

    func testScreenshotImportResultDefaults() {
        let result = ScreenshotImportResult(
            extractedHTML: "",
            designTokens: [:],
            detectedComponents: [],
            confidence: 0.0
        )
        XCTAssertTrue(result.extractedHTML.isEmpty)
        XCTAssertEqual(result.confidence, 0.0)
    }

    func testParseImportResultWithArtifact() {
        let output = """
        <antArtifact type="html" title="Imported Design">
        <div class="bg-blue-500">Hello</div>
        </antArtifact>
        ```json
        { "tokens": { "colors": { "primary": "#3B82F6" } }, "components": ["button"] }
        ```
        """
        let result = ScreenshotImporter.parseImportResult(output)
        XCTAssertTrue(result.extractedHTML.contains("bg-blue-500"))
        XCTAssertEqual(result.designTokens["colors.primary"], "#3B82F6")
        XCTAssertEqual(result.detectedComponents, ["button"])
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    func testParseImportResultFallbackCodeBlock() {
        let output = "```html\n<div>Hello</div>\n```"
        let result = ScreenshotImporter.parseImportResult(output)
        XCTAssertTrue(result.extractedHTML.contains("Hello"))
        XCTAssertGreaterThan(result.confidence, 0.0)
    }

    func testBuildImportRequestReturnsNilForEmptyImage() {
        let image = NSImage(size: NSSize(width: 0, height: 0))
        let result = ScreenshotImporter.buildImportRequest(image: image)
        XCTAssertNil(result)
    }
}

// MARK: - PenpotBridge Tests

@MainActor
extension DesignBridgeTests {

    func testPenpotBridgeNotConnected() async {
        let penpot = PenpotBridge()
        let connected = await penpot.checkConnection()
        XCTAssertFalse(connected)
    }

    func testPenpotBridgeListFilesEmpty() async {
        let penpot = PenpotBridge()
        let files = await penpot.listFiles()
        XCTAssertTrue(files.isEmpty)
    }

    func testPenpotConvertToHTML() {
        let penpot = PenpotBridge()
        let design = PenpotDesignData(
            fileKey: "test123",
            fileName: "Test File",
            nodes: [
                PenpotNode(id: "1", name: "Frame1", type: "FRAME", boundingBox: ["width": 400, "height": 300], children: nil, styles: nil)
            ],
            colors: ["#3B82F6", "#EF4444"],
            typography: [:],
            spacing: [:],
            components: []
        )
        let html = penpot.convertDesignToHTML(design)
        XCTAssertTrue(html.contains("Test File"))
        XCTAssertTrue(html.contains("bg-gray-900"))
        XCTAssertTrue(html.contains("--color-0: #3B82F6"))
    }
}

// MARK: - Artifact File Sync Tests

@MainActor
extension DesignBridgeTests {

    func testEnableFileSync() {
        let bridge = DesignBridge()
        bridge.enableFileSync(to: "/tmp/design-sync")
        XCTAssertTrue(bridge.isFileSyncEnabled)
        XCTAssertEqual(bridge.syncFolderPath, "/tmp/design-sync")
    }

    func testDisableFileSync() {
        let bridge = DesignBridge()
        bridge.enableFileSync(to: "/tmp/design-sync")
        bridge.disableFileSync()
        XCTAssertFalse(bridge.isFileSyncEnabled)
        XCTAssertTrue(bridge.syncFolderPath.isEmpty)
    }

    func testSanitizeFileName() {
        let bridge = DesignBridge()
        let result = bridge.sanitizeFileName("my/design:file*test")
        XCTAssertEqual(result, "my_design_file_test")
    }

    // MARK: - Design Metadata

    func testDesignMetadataKeys() {
        let bridge = DesignBridge()
        bridge.currentArtifactTitle = "TestCard"
        bridge.currentArtifactType = "html"
        let meta: [String: Any] = [
            "component_name": bridge.currentArtifactTitle,
            "framework": bridge.currentArtifactType,
            "layout_type": "responsive",
            "source": "fusion-design"
        ]
        XCTAssertEqual(meta["component_name"] as? String, "TestCard")
        XCTAssertEqual(meta["framework"] as? String, "html")
        XCTAssertEqual(meta["layout_type"] as? String, "responsive")
        XCTAssertEqual(meta["source"] as? String, "fusion-design")
    }

    func testDesignMetadataWithEmptyTitle() {
        let bridge = DesignBridge()
        bridge.currentArtifactTitle = ""
        bridge.currentArtifactType = "react"
        let meta: [String: Any] = [
            "component_name": bridge.currentArtifactTitle,
            "framework": bridge.currentArtifactType,
            "layout_type": "responsive",
            "source": "fusion-design"
        ]
        XCTAssertEqual(meta["component_name"] as? String, "")
        XCTAssertEqual(meta["framework"] as? String, "react")
    }
}

// MARK: - Phase 4: DesignCodeLink Tests

@MainActor
extension DesignBridgeTests {

    func testDesignCodeLinkSingleton() {
        let link1 = DesignCodeLink.shared
        let link2 = DesignCodeLink.shared
        XCTAssertFalse(link1.isActive)
        XCTAssertTrue(link1 === link2)
    }

    func testDesignCodeLinkMarkDesignWrite() {
        let link = DesignCodeLink.shared
        link.markDesignWrite(artifactName: "TestArtifact")
    }

    func testDesignCodeLinkDeactivateWhenNotActive() {
        let link = DesignCodeLink.shared
        link.deactivate()
        XCTAssertFalse(link.isActive)
    }

    func testSyncDirectionRawValues() {
        XCTAssertEqual(DesignCodeLink.SyncDirection.designToFile.rawValue, "design→file")
        XCTAssertEqual(DesignCodeLink.SyncDirection.fileToDesign.rawValue, "file→design")
    }
}

// MARK: - Phase 4: DesignArtifactExporter Tests

extension DesignBridgeTests {

    func testExporterTypeFromExtension() {
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("html"), "html")
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("jsx"), "react")
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("tsx"), "react")
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("swift"), "swiftui")
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("svg"), "svg")
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("md"), "markdown")
        XCTAssertEqual(DesignArtifactExporter.shared.typeFromExtension("css"), "html")
    }

    func testExporterExportResultInit() {
        let success = ExportResult(success: true, path: "/tmp/test.html", error: nil)
        XCTAssertTrue(success.success)
        XCTAssertEqual(success.path, "/tmp/test.html")
        XCTAssertNil(success.error)

        let failure = ExportResult(success: false, path: "", error: "no project")
        XCTAssertFalse(failure.success)
        XCTAssertEqual(failure.error, "no project")
    }
}

// MARK: - Phase 4: ArtifactVersionDiff Tests

extension DesignBridgeTests {

    func testDiffLineTypeEquality() {
        XCTAssertEqual(DiffLineType.unchanged, DiffLineType.unchanged)
        XCTAssertNotEqual(DiffLineType.added, DiffLineType.deleted)
    }

    func testDiffLineInit() {
        let line = DiffLine(type: .added, oldLineNum: nil, newLineNum: 5, content: "hello")
        XCTAssertEqual(line.type, .added)
        XCTAssertNil(line.oldLineNum)
        XCTAssertEqual(line.newLineNum, 5)
        XCTAssertEqual(line.content, "hello")
    }

    func testDiffResultInit() {
        let result = DiffResult(additions: 3, deletions: 1, lines: [])
        XCTAssertEqual(result.additions, 3)
        XCTAssertEqual(result.deletions, 1)
        XCTAssertTrue(result.lines.isEmpty)
    }
}

// MARK: - Phase 4: DesignWorkflowOrchestrator Tests

@MainActor
extension DesignBridgeTests {

    func testWorkflowRecipeSteps() {
        let d2c = WorkflowRecipe.designToCode
        XCTAssertEqual(d2c.steps.count, 4)
        XCTAssertEqual(d2c.steps[0], .createDesign)
        XCTAssertEqual(d2c.steps[3], .openInEditor)

        let c2d = WorkflowRecipe.codeToDesign
        XCTAssertEqual(c2d.steps.count, 4)

        let s2d2c = WorkflowRecipe.screenshotToDesignToCode
        XCTAssertEqual(s2d2c.steps.count, 5)
    }

    func testWorkflowStepIcons() {
        for step in [WorkflowStep.createDesign, .exportToCode, .captureScreenshot, .generateDesign] {
            XCTAssertFalse(step.icon.isEmpty)
        }
    }

    func testOrchestratorInitial() {
        let orch = DesignWorkflowOrchestrator.shared
        XCTAssertNil(orch.activeRecipe)
        XCTAssertFalse(orch.isRunning)
        XCTAssertEqual(orch.progress, 0)
        XCTAssertNil(orch.currentStep)
    }

    func testOrchestratorCancel() {
        let orch = DesignWorkflowOrchestrator.shared
        orch.cancel()
        XCTAssertNil(orch.activeRecipe)
        XCTAssertFalse(orch.isRunning)
    }
}

// MARK: - Phase 4: CodeDesignPreviewPanel Notification Tests

extension DesignBridgeTests {

    func testSwitchToDesignModuleNotification() {
        let name = Notification.Name.switchToDesignModule
        XCTAssertEqual(name.rawValue, "switchToDesignModule")
    }

    func testSwitchToCodeModuleNotification() {
        let name = Notification.Name.switchToCodeModule
        XCTAssertEqual(name.rawValue, "switchToCodeModule")
    }

    // MARK: - FusionDesignSystem (P2 #8)

    func testDesignSystemPresetComponents() {
        let ds = FusionDesignSystem.shared
        XCTAssertGreaterThanOrEqual(ds.components.count, 9)
    }

    func testDesignSystemComponentByCategory() {
        let ds = FusionDesignSystem.shared
        let buttons = ds.components(in: .button)
        XCTAssertGreaterThanOrEqual(buttons.count, 1)
        XCTAssertEqual(buttons.first?.name, "Button")
    }

    func testDesignSystemComponentByName() {
        let ds = FusionDesignSystem.shared
        XCTAssertNotNil(ds.component(by: "Button"))
        XCTAssertNotNil(ds.component(by: "Card"))
        XCTAssertNil(ds.component(by: "NonExistent"))
    }

    func testDesignSystemRenderComponent() {
        let ds = FusionDesignSystem.shared
        guard let btn = ds.component(by: "Button") else { XCTFail(); return }
        let html = ds.renderComponent(btn, variant: .secondary, size: .large)
        XCTAssertTrue(html.contains("fusion-btn-secondary"))
        XCTAssertTrue(html.contains("component-lg"))
    }

    func testDesignSystemInjectIntoPrompt() {
        let ds = FusionDesignSystem.shared
        guard let btn = ds.component(by: "Button") else { XCTFail(); return }
        let ctx = ds.injectIntoPrompt(btn)
        XCTAssertTrue(ctx.contains("Button"))
        XCTAssertTrue(ctx.contains("primary"))
    }

    func testComponentVariantAllCases() {
        XCTAssertEqual(ComponentVariant.allCases.count, 6)
    }

    func testComponentSizeAllCases() {
        XCTAssertEqual(ComponentSize.allCases.count, 3)
        XCTAssertEqual(ComponentSize.small.displayName, "小")
    }

    func testComponentCategoryAllCases() {
        XCTAssertEqual(ComponentCategory.allCases.count, 9)
    }

    func testDesignTemplateAllCases() {
        XCTAssertEqual(DesignTemplate.allCases.count, 5)
        XCTAssertFalse(DesignTemplate.dashboard.description.isEmpty)
    }

    func testDesignSystemTemplates() {
        let ds = FusionDesignSystem.shared
        XCTAssertGreaterThanOrEqual(ds.templates.count, 5)
        XCTAssertNotNil(ds.templates[.dashboard])
    }

    func testDesignSystemFilteredComponents() {
        let ds = FusionDesignSystem.shared
        ds.selectedCategory = .button
        ds.searchQuery = ""
        let filtered = ds.filteredComponents
        XCTAssertTrue(filtered.allSatisfy { $0.category == .button })
        ds.selectedCategory = nil
    }

    // MARK: - DesignInspectorView (P2 #9)

    func testInspectorSectionAllCases() {
        XCTAssertEqual(InspectorSection.allCases.count, 6)
    }

    func testLayoutModeAllCases() {
        XCTAssertEqual(LayoutMode.allCases.count, 4)
    }

    func testFlexDirectionAllCases() {
        XCTAssertEqual(FlexDirection.allCases.count, 4)
    }

    func testJustifyContentDisplayNames() {
        XCTAssertEqual(JustifyContent.center.displayName, "居中")
        XCTAssertEqual(JustifyContent.between.displayName, "两端对齐")
    }

    func testAlignItemsDisplayNames() {
        XCTAssertEqual(AlignItems.stretch.displayName, "拉伸")
    }

    func testStylePropertiesDefaultCSS() {
        let props = StyleProperties()
        let css = props.toCSS()
        XCTAssertTrue(css.contains("display: flex"))
        XCTAssertTrue(css.contains("font-size: 14px"))
    }

    func testStylePropertiesCardPresetCSS() {
        let props = StylePreset.card.properties
        let css = props.toCSS()
        XCTAssertTrue(css.contains("background-color: #1C1C1E"))
        XCTAssertTrue(css.contains("border-radius: 12px"))
    }

    func testStylePresetAllCases() {
        XCTAssertEqual(StylePreset.allCases.count, 5)
    }

    func testBoxValueUniform() {
        let uniform = BoxValue(top: "8px", right: "8px", bottom: "8px", left: "8px")
        XCTAssertTrue(uniform.isUniform)
        let nonUniform = BoxValue(top: "8px", right: "0", bottom: "8px", left: "0")
        XCTAssertFalse(nonUniform.isUniform)
    }

    func testDesignInspectorStateReset() {
        let state = DesignInspectorState.shared
        state.properties.fontSize = "99px"
        state.reset()
        XCTAssertEqual(state.properties.fontSize, "14px")
        XCTAssertNil(state.selectedElement)
    }
}
