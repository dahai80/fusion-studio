import SwiftUI
import Combine
import os.log

// MARK: - SkillsTabView

struct SkillsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var mode = "skill"
    @State private var selectedAgentId = ""
    @State private var skillName = ""
    @State private var input = ""
    @State private var question = ""
    @State private var maxSteps: Double = 10
    @State private var webSearch = true
    @State private var result = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Skills & Research")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(theme.spacingM)

            Picker("Mode", selection: $mode) {
                Text("Skill Execute").tag("skill")
                Text("Adaptive Research").tag("research")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if mode == "skill" {
                skillForm
            } else {
                researchForm
            }

            if isLoading {
                ProgressView().padding(theme.spacingM)
            }
            if !result.isEmpty {
                StudioSectionHeader(title: "Result")
                ScrollView {
                    Text(result)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingL)
                }
            }
            Spacer()
        }
    }

    private var skillForm: some View {
        VStack(spacing: theme.spacingS) {
            Picker("Agent", selection: $selectedAgentId) {
                Text("Select agent...").tag("")
                ForEach(bridge.agentState.agents) { agent in
                    Text(agent.name).tag(agent.id)
                }
            }
            .textFieldStyle(.roundedBorder)
            TextField("Skill name", text: $skillName)
                .textFieldStyle(.roundedBorder)
            TextField("Input", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            FusionButton("Execute Skill", icon: "wand.and.stars", isDisabled: selectedAgentId.isEmpty || skillName.isEmpty || isLoading) {
                Task { await runSkill() }
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    private var researchForm: some View {
        VStack(spacing: theme.spacingS) {
            TextField("Research question", text: $question, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Text("Max steps: \(Int(maxSteps))")
                    .font(.system(size: theme.captionSize))
                Slider(value: $maxSteps, in: 1...30, step: 1)
            }
            Toggle("Web search", isOn: $webSearch)
                .font(.system(size: theme.captionSize))
            FusionButton("Run Research", icon: "magnifyingglass.circle", isDisabled: question.isEmpty || isLoading) {
                Task { await runResearch() }
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func runSkill() async {
        guard !selectedAgentId.isEmpty, !skillName.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let output = try await bridge.skillExecute(agentId: selectedAgentId, skillName: skillName, input: input)
            result = output.isEmpty ? "(no output)" : output
            toastManager.show(style: .success, title: "Skill Done", message: skillName)
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func runResearch() async {
        guard !question.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let summary = try await bridge.researchAdaptive(question: question, maxSteps: Int(maxSteps), webSearch: webSearch)
            result = summary.isEmpty ? "(no summary)" : summary
            toastManager.show(style: .success, title: "Research Done", message: "Adaptive research completed")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}
