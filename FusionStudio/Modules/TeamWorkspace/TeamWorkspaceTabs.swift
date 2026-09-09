import Foundation

// M2: TeamWorkspace tab enum. M2-1 shell (kanban/members); M2-3..M2-6 add messages/review/approval/evidence/budget.
enum TeamWorkspaceTab: String, CaseIterable, Identifiable {
    case kanban
    case members
    // M2-3..M2-6 (deferred):
    // case messages, review, approval, evidence, budget

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kanban: return "Kanban"
        case .members: return "Members"
        }
    }

    var systemImage: String {
        switch self {
        case .kanban: return "square.grid.3x3"
        case .members: return "person.3"
        }
    }
}
