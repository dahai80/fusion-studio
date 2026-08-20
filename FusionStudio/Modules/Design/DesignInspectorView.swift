import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "DesignInspector")

enum InspectorSection: String, CaseIterable, Identifiable {
    case layout = "布局"
    case spacing = "间距"
    case typography = "排版"
    case colors = "颜色"
    case borders = "边框"
    case effects = "效果"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .layout: return "square.split.2x1"
        case .spacing: return "arrow.left.and.right"
        case .typography: return "textformat"
        case .colors: return "paintpalette"
        case .borders: return "square.dashed"
        case .effects: return "sparkles"
        }
    }

    var localLabel: String {
        switch self {
        case .layout: return I18nManager.shared.t(.design_ins_sec_layout)
        case .spacing: return I18nManager.shared.t(.design_ins_sec_spacing)
        case .typography: return I18nManager.shared.t(.design_ins_sec_typography)
        case .colors: return I18nManager.shared.t(.design_ins_sec_colors)
        case .borders: return I18nManager.shared.t(.design_ins_sec_borders)
        case .effects: return I18nManager.shared.t(.design_ins_sec_effects)
        }
    }
}

enum LayoutMode: String, CaseIterable, Identifiable {
    case flex = "Flex"
    case grid = "Grid"
    case block = "Block"
    case absolute = "Absolute"

    var id: String { rawValue }
}

enum FlexDirection: String, CaseIterable, Identifiable {
    case row = "row"
    case column = "column"
    case rowReverse = "row-reverse"
    case columnReverse = "column-reverse"

    var id: String { rawValue }
}

enum JustifyContent: String, CaseIterable, Identifiable {
    case start = "flex-start"
    case center = "center"
    case end = "flex-end"
    case between = "space-between"
    case around = "space-around"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .start: return I18nManager.shared.t(.design_ins_alignStart)
        case .center: return I18nManager.shared.t(.design_ins_alignCenter)
        case .end: return I18nManager.shared.t(.design_ins_alignEnd)
        case .between: return I18nManager.shared.t(.design_ins_justifyBetween)
        case .around: return I18nManager.shared.t(.design_ins_justifyAround)
        }
    }
}

enum AlignItems: String, CaseIterable, Identifiable {
    case start = "flex-start"
    case center = "center"
    case end = "flex-end"
    case stretch = "stretch"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .start: return I18nManager.shared.t(.design_ins_alignStart)
        case .center: return I18nManager.shared.t(.design_ins_alignCenter)
        case .end: return I18nManager.shared.t(.design_ins_alignEnd)
        case .stretch: return I18nManager.shared.t(.design_ins_alignStretch)
        }
    }
}

struct StyleProperties {
    var layoutMode: LayoutMode = .flex
    var flexDirection: FlexDirection = .row
    var justifyContent: JustifyContent = .start
    var alignItems: AlignItems = .stretch
    var width: String = "auto"
    var height: String = "auto"
    var padding: BoxValue = BoxValue()
    var margin: BoxValue = BoxValue()
    var gap: String = "0"
    var fontFamily: String = "system-ui"
    var fontSize: String = "14px"
    var fontWeight: String = "400"
    var lineHeight: String = "1.5"
    var textAlign: String = "left"
    var color: String = "#FFFFFF"
    var backgroundColor: String = "transparent"
    var borderColor: String = "transparent"
    var borderWidth: String = "0"
    var borderRadius: String = "8px"
    var opacity: String = "1"
    var boxShadow: String = "none"
    var overflow: String = "visible"

    func toCSS() -> String {
        var lines: [String] = []
        lines.append("display: \(layoutMode == .flex ? "flex" : layoutMode == .grid ? "grid" : layoutMode == .absolute ? "block" : "block")")
        if layoutMode == .flex {
            lines.append("flex-direction: \(flexDirection.rawValue)")
            lines.append("justify-content: \(justifyContent.rawValue)")
            lines.append("align-items: \(alignItems.rawValue)")
        }
        if width != "auto" { lines.append("width: \(width)") }
        if height != "auto" { lines.append("height: \(height)") }
        if padding.top != "0" || padding.right != "0" || padding.bottom != "0" || padding.left != "0" {
            lines.append("padding: \(padding.top) \(padding.right) \(padding.bottom) \(padding.left)")
        }
        if margin.top != "0" || margin.right != "0" || margin.bottom != "0" || margin.left != "0" {
            lines.append("margin: \(margin.top) \(margin.right) \(margin.bottom) \(margin.left)")
        }
        if gap != "0" { lines.append("gap: \(gap)") }
        lines.append("font-family: \(fontFamily)")
        lines.append("font-size: \(fontSize)")
        lines.append("font-weight: \(fontWeight)")
        lines.append("line-height: \(lineHeight)")
        lines.append("text-align: \(textAlign)")
        if color != "#FFFFFF" { lines.append("color: \(color)") }
        if backgroundColor != "transparent" { lines.append("background-color: \(backgroundColor)") }
        if borderColor != "transparent" { lines.append("border: \(borderWidth) solid \(borderColor)") }
        if borderRadius != "0" { lines.append("border-radius: \(borderRadius)") }
        if opacity != "1" { lines.append("opacity: \(opacity)") }
        if boxShadow != "none" { lines.append("box-shadow: \(boxShadow)") }
        if overflow != "visible" { lines.append("overflow: \(overflow)") }
        return lines.joined(separator: ";\n  ") + ";"
    }
}

struct BoxValue {
    var top: String = "0"
    var right: String = "0"
    var bottom: String = "0"
    var left: String = "0"

    var isUniform: Bool { top == right && right == bottom && bottom == left }
}

// Callers: DesignCanvasView.Coordinator (node.select/drag/resize events), DesignInspectorView (UI binding).
// Affected API: DesignInspectorState.shared, Notification.Name.designInspectorMutateNode.
// Data schemas: BridgeEvent payload (node_id, dx, dy, w, h), MutateNode command JSON.
// User instruction: "现在开始实施" — Task #11 P2-2

class DesignInspectorState: ObservableObject {
    static let shared = DesignInspectorState()

    @Published var properties: StyleProperties = StyleProperties()
    @Published var selectedElement: String? = nil
    @Published var expandedSections: Set<InspectorSection> = Set(InspectorSection.allCases)
    var _lastDragDX: Float = 0
    var _lastDragDY: Float = 0

    init() {
        logger.info("DesignInspectorState initialized")
    }

    func reset() {
        properties = StyleProperties()
        selectedElement = nil
    }

    func toggleSection(_ section: InspectorSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    func applyPreset(_ preset: StylePreset) {
        properties = preset.properties
        logger.info("Applied style preset: \(preset.rawValue)")
    }

    func pushSizeToCanvas() {
        guard let nodeID = selectedElement else { return }
        let w = parsePxValue(properties.width)
        let h = parsePxValue(properties.height)
        guard w != nil || h != nil else { return }
        NotificationCenter.default.post(
            name: .designInspectorMutateNode,
            object: nil,
            userInfo: [
                "node_id": nodeID,
                "w": w ?? NSNull(),
                "h": h ?? NSNull(),
            ]
        )
        logger.info("DesignInspectorState: pushSizeToCanvas nodeID=\(nodeID) w=\(w?.description ?? "nil") h=\(h?.description ?? "nil")")
    }

    func pushStyleToCanvas() {
        guard let nodeID = selectedElement else { return }
        var userInfo: [String: Any] = ["node_id": nodeID]

        let w = parsePxValue(properties.width)
        let h = parsePxValue(properties.height)
        if let w = w { userInfo["w"] = w }
        if let h = h { userInfo["h"] = h }

        if properties.backgroundColor != "transparent" {
            userInfo["fill"] = properties.backgroundColor
        }
        if properties.borderColor != "transparent" {
            userInfo["stroke"] = properties.borderColor
            if let sw = parsePxValue(properties.borderWidth) {
                userInfo["stroke_width"] = sw
            }
        }
        if let r = parsePxValue(properties.borderRadius) {
            userInfo["radius"] = r
        }
        if let fs = parsePxValue(properties.fontSize) {
            userInfo["font_size"] = fs
        }
        if properties.fontFamily != "system-ui" {
            userInfo["font_family"] = properties.fontFamily
        }
        if let o = Float(properties.opacity), o != 1.0 {
            userInfo["opacity"] = o
        }

        NotificationCenter.default.post(
            name: .designInspectorMutateNode,
            object: nil,
            userInfo: userInfo
        )
        logger.info("DesignInspectorState: pushStyleToCanvas nodeID=\(nodeID) fields=\(userInfo.keys.filter { $0 != "node_id" }.joined(separator: ","))")
    }

    private func parsePxValue(_ s: String) -> Float? {
        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: "px "))
        return Float(trimmed)
    }
}

extension Notification.Name {
    static let designInspectorMutateNode = Notification.Name("designInspectorMutateNode")
    static let designInspectorShowNode = Notification.Name("designInspectorShowNode")
    static let designInspectorHide = Notification.Name("designInspectorHide")
}

enum StylePreset: String, CaseIterable, Identifiable {
    case card = "卡片"
    case button = "按钮"
    case inputField = "输入框"
    case navBar = "导航栏"
    case heroSection = "Hero 区域"

    var id: String { rawValue }

    var localLabel: String {
        switch self {
        case .card: return I18nManager.shared.t(.design_ins_preset_card)
        case .button: return I18nManager.shared.t(.design_ins_preset_button)
        case .inputField: return I18nManager.shared.t(.design_ins_preset_inputField)
        case .navBar: return I18nManager.shared.t(.design_ins_preset_navBar)
        case .heroSection: return I18nManager.shared.t(.design_ins_preset_heroSection)
        }
    }

    var properties: StyleProperties {
        switch self {
        case .card:
            return StyleProperties(
                layoutMode: .flex, flexDirection: .column,
                padding: BoxValue(top: "16px", right: "16px", bottom: "16px", left: "16px"),
                backgroundColor: "#1C1C1E", borderRadius: "12px",
                boxShadow: "0 2px 8px rgba(0,0,0,0.3)"
            )
        case .button:
            return StyleProperties(
                layoutMode: .flex, flexDirection: .row,
                justifyContent: .center, alignItems: .center,
                padding: BoxValue(top: "8px", right: "16px", bottom: "8px", left: "16px"),
                fontSize: "14px", fontWeight: "600",
                color: "#FFFFFF", backgroundColor: "#007AFF",
                borderRadius: "8px"
            )
        case .inputField:
            return StyleProperties(
                layoutMode: .flex, flexDirection: .column,
                padding: BoxValue(top: "10px", right: "12px", bottom: "10px", left: "12px"),
                fontSize: "14px",
                color: "#FFFFFF", backgroundColor: "#2C2C2E",
                borderColor: "#3A3A3C", borderWidth: "1px", borderRadius: "8px"
            )
        case .navBar:
            return StyleProperties(
                layoutMode: .flex, flexDirection: .row,
                justifyContent: .between, alignItems: .center,
                padding: BoxValue(top: "12px", right: "20px", bottom: "12px", left: "20px"),
                gap: "16px",
                backgroundColor: "#1C1C1E"
            )
        case .heroSection:
            return StyleProperties(
                layoutMode: .flex, flexDirection: .column,
                justifyContent: .center, alignItems: .center,
                padding: BoxValue(top: "60px", right: "40px", bottom: "60px", left: "40px"),
                gap: "16px",
                fontSize: "32px", fontWeight: "700",
                textAlign: "center", color: "#FFFFFF"
            )
        }
    }
}

struct DesignInspectorView: View {
    @StateObject private var state = DesignInspectorState.shared
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    presetPicker
                    Rectangle().fill(theme.separator).frame(height: 1)
                    ForEach(InspectorSection.allCases) { section in
                        sectionContent(section)
                    }
                }
            }
            Rectangle().fill(theme.separator).frame(height: 1)
            cssOutputBar
        }
        .onAppear {
            observeNotifications()
        }
    }

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            forName: .designInspectorShowNode,
            object: nil,
            queue: .main
        ) { notification in
            if let nodeID = notification.userInfo?["node_id"] as? String {
                appState.inspectorContext = .node(id: nodeID)
                appState.isInspectorVisible = true
                state.selectedElement = nodeID
                logger.info("DesignInspectorView: show node=\(nodeID), selectedElement set")
            }
        }
        NotificationCenter.default.addObserver(
            forName: .designInspectorHide,
            object: nil,
            queue: .main
        ) { _ in
            appState.inspectorContext = .none
            appState.isInspectorVisible = false
            state.selectedElement = nil
            logger.info("DesignInspectorView: hide, selectedElement cleared")
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(theme.accent)
            Text(i18n.t(.design_ins_title))
                .font(.system(size: theme.bodySize, weight: .semibold))
                .foregroundColor(theme.text)
            Spacer()
            if let el = state.selectedElement {
                Text(el)
                    .font(.system(size: theme.captionSize))
                    .foregroundColor(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.groupBg)
                    .cornerRadius(4)
            }
            Button(action: { state.reset() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.design_ins_presetLabel))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, theme.spacingM)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingXS) {
                    ForEach(StylePreset.allCases) { preset in
                        Button(action: { state.applyPreset(preset) }) {
                            Text(preset.localLabel)
                                .font(.system(size: theme.captionSize))
                                .foregroundColor(theme.accentText)
                                .padding(.horizontal, theme.spacingS)
                                .padding(.vertical, theme.spacingXS)
                                .background(theme.accentSoft)
                                .cornerRadius(theme.cornerRadiusSmall)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacingM)
            }
        }
        .padding(.vertical, theme.spacingS)
    }

    @ViewBuilder
    private func sectionContent(_ section: InspectorSection) -> some View {
        VStack(spacing: 0) {
            Button(action: { state.toggleSection(section) }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: state.expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                    Image(systemName: section.icon)
                        .font(.system(size: 10))
                        .foregroundColor(theme.accent)
                    Text(section.localLabel)
                        .font(.system(size: theme.captionSize, weight: .semibold))
                        .foregroundColor(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
            }
            .buttonStyle(.plain)

            if state.expandedSections.contains(section) {
                switch section {
                case .layout: layoutSection
                case .spacing: spacingSection
                case .typography: typographySection
                case .colors: colorsSection
                case .borders: bordersSection
                case .effects: effectsSection
                }
            }
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            propertyRow(i18n.t(.design_ins_layoutMode)) {
                Picker("", selection: $state.properties.layoutMode) {
                    ForEach(LayoutMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            if state.properties.layoutMode == .flex {
                propertyRow(i18n.t(.design_ins_direction)) {
                    Picker("", selection: $state.properties.flexDirection) {
                        ForEach(FlexDirection.allCases) { d in Text(d.rawValue).tag(d) }
                    }
                    .pickerStyle(.segmented)
                }
                propertyRow(i18n.t(.design_ins_mainAxis)) {
                    Picker("", selection: $state.properties.justifyContent) {
                        ForEach(JustifyContent.allCases) { j in Text(j.displayName).tag(j) }
                    }
                    .pickerStyle(.segmented)
                }
                propertyRow(i18n.t(.design_ins_crossAxis)) {
                    Picker("", selection: $state.properties.alignItems) {
                        ForEach(AlignItems.allCases) { a in Text(a.displayName).tag(a) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            propertyRow(i18n.t(.design_ins_width)) {
                textField("auto", text: $state.properties.width) {
                    state.pushSizeToCanvas()
                }
            }
            propertyRow(i18n.t(.design_ins_height)) {
                textField("auto", text: $state.properties.height) {
                    state.pushSizeToCanvas()
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
    }

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.design_ins_padding))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textTertiary)
            boxValueEditor($state.properties.padding)
            Text(i18n.t(.design_ins_margin))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textTertiary)
            boxValueEditor($state.properties.margin)
            propertyRow(i18n.t(.design_ins_gap)) { textField("0", text: $state.properties.gap) }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            propertyRow(i18n.t(.design_ins_fontFamily)) { textField("system-ui", text: $state.properties.fontFamily) }
            propertyRow(i18n.t(.design_ins_fontSize)) { textField("14px", text: $state.properties.fontSize) }
            propertyRow(i18n.t(.design_ins_fontWeight)) {
                Picker("", selection: $state.properties.fontWeight) {
                    ForEach(["100","200","300","400","500","600","700","800","900"], id: \.self) { w in
                        Text(w).tag(w)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }
            propertyRow(i18n.t(.design_ins_lineHeight)) { textField("1.5", text: $state.properties.lineHeight) }
            propertyRow(i18n.t(.design_ins_textAlign)) {
                Picker("", selection: $state.properties.textAlign) {
                    ForEach(["left","center","right","justify"], id: \.self) { a in Text(a).tag(a) }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            colorRow(i18n.t(.design_ins_textColor), text: $state.properties.color)
            colorRow(i18n.t(.design_ins_bgColor), text: $state.properties.backgroundColor)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
    }

    private var bordersSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            colorRow(i18n.t(.design_ins_borderColor), text: $state.properties.borderColor)
            propertyRow(i18n.t(.design_ins_borderWidth)) { textField("0", text: $state.properties.borderWidth) }
            propertyRow(i18n.t(.design_ins_borderRadius)) { textField("8px", text: $state.properties.borderRadius) }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
    }

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            propertyRow(i18n.t(.design_ins_opacity)) { textField("1", text: $state.properties.opacity) }
            propertyRow(i18n.t(.design_ins_shadow)) { textField("none", text: $state.properties.boxShadow) }
            propertyRow(i18n.t(.design_ins_overflow)) {
                Picker("", selection: $state.properties.overflow) {
                    ForEach(["visible","hidden","scroll","auto"], id: \.self) { o in Text(o).tag(o) }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
    }

    private var cssOutputBar: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(i18n.t(.design_ins_cssOutput))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.properties.toCSS(), forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Text(state.properties.toCSS())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .lineLimit(4)
        }
        .padding(theme.spacingS)
    }

    private func propertyRow(_ label: String, content: () -> some View) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(label)
                .font(.system(size: theme.captionSize))
                .foregroundColor(theme.textSecondary)
                .frame(width: 80, alignment: .leading)
            content()
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void = {}) -> some View {
        TextField(placeholder, text: text, onCommit: onCommit)
            .textFieldStyle(.plain)
            .font(.system(size: theme.captionSize, design: .monospaced))
            .foregroundColor(theme.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(theme.inputBg)
            .cornerRadius(theme.cornerRadiusSmall)
    }

    private func colorRow(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(label)
                .font(.system(size: theme.captionSize))
                .foregroundColor(theme.textSecondary)
                .frame(width: 80, alignment: .leading)
            TextField("#FFFFFF", text: text, onCommit: { state.pushStyleToCanvas() })
                .textFieldStyle(.plain)
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundColor(theme.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.inputBg)
                .cornerRadius(theme.cornerRadiusSmall)
        }
    }

    private func boxValueEditor(_ value: Binding<BoxValue>) -> some View {
        VStack(spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Spacer()
                textField("0", text: value.top)
                    .frame(width: 50)
                Spacer()
            }
            HStack(spacing: theme.spacingXS) {
                textField("0", text: value.left)
                    .frame(width: 50)
                Text("□")
                    .foregroundColor(theme.textTertiary)
                    .font(.system(size: 12))
                textField("0", text: value.right)
                    .frame(width: 50)
            }
            HStack(spacing: theme.spacingXS) {
                Spacer()
                textField("0", text: value.bottom)
                    .frame(width: 50)
                Spacer()
            }
        }
    }
}
