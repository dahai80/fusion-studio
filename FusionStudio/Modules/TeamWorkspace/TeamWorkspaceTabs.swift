import Foundation

// M2: TeamWorkspace tab enum. M2-1 shell (kanban/members); M2-3..M2-6 add messages/review/approval/evidence/budget.
enum TeamWorkspaceTab: String, CaseIterable, Identifiable {
    case kanban
    case members
    case messages
    // M2-3..M2-6 (deferred):
    // case review, approval, evidence, budget

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kanban: return "Kanban"
        case .members: return "Members"
        case .messages: return "Messages"
        }
    }

    var systemImage: String {
        switch self {
        case .kanban: return "square.grid.3x3"
        case .members: return "person.3"
        case .messages: return "bubble.left.and.bubble.right"
        }
    }
}
