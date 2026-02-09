import Foundation

enum TaskStatus: Equatable {
    case pending
    case processing
    case completed
    case failed

    var displayText: String {
        switch self {
        case .pending: return "Ожидает"
        case .processing: return "Обрабатывается"
        case .completed: return "Завершено"
        case .failed: return "Ошибка"
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
