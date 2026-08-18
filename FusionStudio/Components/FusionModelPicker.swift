// Importers/callers: CodeMainView (modelSelector), AgentStudioView (2 Pickers), SettingsView (slot config), WelcomeView (3-slot onboarding).
// Affected API: FusionModelPicker view - Menu-based unified model selector (3 slots + More Models submenu), scene-based default.
// Data schemas: reads MLXModelInfo[] (bridge.models), FusionConfig slot/scene @AppStorage (mlxModelSmall/Code/Heavy, defaultSlot*). User instruction: "在所有选额模型的地方都默认展示这三个模型+More Models（More Model子菜单里面展示其他模型），系统初始选择模型的时候默认是小模型，客户要有地方设置默认模型，设置后所有加载模型的地方都默认是客户设置的模型，所有对话框，code和agent，artifacts等等用到模型的地方默认的都是客户设置的模型"

import SwiftUI
import os.log

struct FusionModelPicker: View {
    let scene: ModelScene
    @Binding var selection: String
    let models: [MLXModelInfo]
    var defaultTag: String? = nil
    var onChange: ((String) -> Void)? = nil

    @ObservedObject private var config = FusionConfig.shared
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.studioTheme) var theme

    private let log = Logger(subsystem: "com.fusion.studio", category: "ModelPicker")

    private var assignedSlotModels: Set<String> {
        Set(ModelSlot.allCases.compactMap { config.slotModel($0) }.filter { !$0.isEmpty })
    }

    private var moreModels: [MLXModelInfo] {
        let assigned = assignedSlotModels
        let chat = models.filter { $0.isTextChatModel }
        let pool = chat.isEmpty ? models : chat
        return pool.filter { !assigned.contains($0.id) && !assigned.contains($0.name) }
    }

    private var displayLabel: String {
        if selection.isEmpty {
            if defaultTag != nil {
                return String(format: i18n.t(.defaultModelSlot), config.defaultSlot(for: scene).label)
            }
            let dm = config.defaultModel(for: scene)
            return dm.isEmpty ? i18n.t(.selectModel) : dm
        }
        return selection
    }

    private func isChosen(_ id: String) -> Bool {
        !selection.isEmpty && selection == id
    }

    var body: some View {
        Menu {
            ForEach(ModelSlot.allCases) { slot in
                let m = config.slotModel(slot)
                let chosen = !m.isEmpty && isChosen(m)
                Button {
                    if !m.isEmpty { pick(m) }
                } label: {
                    Label(m.isEmpty ? String(format: i18n.t(.slotNotSet), slot.label) : "\(slot.label) · \(m)",
                          systemImage: chosen ? "checkmark" : slot.icon)
                }
                .disabled(m.isEmpty)
            }
            if let defaultTag {
                Divider()
                Button {
                    pick(defaultTag)
                } label: {
                    if selection.isEmpty {
                        Label(String(format: i18n.t(.defaultModelSlot), config.defaultSlot(for: scene).label), systemImage: "checkmark")
                    } else {
                        Label(String(format: i18n.t(.defaultModelSlot), config.defaultSlot(for: scene).label), systemImage: "circle.dashed")
                    }
                }
            }
            Divider()
            if moreModels.isEmpty {
                Text(i18n.t(.moreModelsEmpty))
            } else {
                Menu(i18n.t(.moreModelsLabel)) {
                    ForEach(moreModels) { m in
                        Button {
                            pick(m.id)
                        } label: {
                            if isChosen(m.id) || isChosen(m.name) {
                                Label(m.name, systemImage: "checkmark")
                            } else {
                                Text(m.name)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayLabel)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.separator.opacity(0.5))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pick(_ id: String) {
        selection = id
        log.info("scene=\(self.scene.rawValue) model=\(id)")
        onChange?(id)
    }
}
