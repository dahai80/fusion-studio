import Foundation

// M2: TeamWorkspace tab enum. M2-1 shell (kanban/members); M2-3..M2-6 add messages/review/approval/evidence/budget.
enum TeamWorkspaceTab: String, CaseIterable, Identifiable {
    case kanban
    case members
    case messages
    case review
    case evidence
    case budget

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kanban: return "Kanban"
        case .members: return "Members"
        case .messages: return "Messages"
        case .review: return "Review"
        case .evidence: return "Evidence"
        case .budget: return "Budget"
        }
    }

    var systemImage: String {
        switch self {
        case .kanban: return "square.grid.3x3"
        case .members: return "person.3"
        case .messages: return "bubble.left.and.bubble.right"
        case .review: return "checkmark.message"
        case .evidence: return "stethoscope"
        case .budget: return "creditcard"
        }
    }
}
