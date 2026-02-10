import Foundation

enum TaskStatus: Equatable {
    case pending
    case processing
    case completed
    case failed

    var displayText: String {
        switch self {
        case .pending: return NSLocalizedString("status.pending", comment: "")
        case .processing: return NSLocalizedString("status.processing", comment: "")
        case .completed: return NSLocalizedString("status.completed", comment: "")
        case .failed: return NSLocalizedString("status.failed", comment: "")
        }
    }

    var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .processing: return "⚙️"
        case .completed: return "✅"
        case .failed: return "⚠️"
        }
    }
}
