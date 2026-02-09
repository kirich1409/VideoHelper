import Foundation

enum ExportPreset: String, CaseIterable, Identifiable {
    case original = "Оригинал"
    case telegramSD = "Telegram SD (720p)"
    case telegramHD = "Telegram HD (1080p)"

    var id: String { rawValue }

    var filenameSuffix: String {
        switch self {
        case .original: return "_original"
        case .telegramSD: return "_telegram_sd"
        case .telegramHD: return "_telegram_hd"
        }
    }

    var targetBitrate: Int64 {
        switch self {
        case .original: return 0 // Passthrough
        case .telegramSD: return 2_000_000 // 2 Mbps
        case .telegramHD: return 4_000_000 // 4 Mbps
        }
    }

    var maxResolution: CGSize? {
        switch self {
        case .original: return nil
        case .telegramSD: return CGSize(width: 1280, height: 720)
        case .telegramHD: return CGSize(width: 1920, height: 1080)
        }
    }
}
