import Foundation

enum ExportPreset: String, CaseIterable, Identifiable {
    case uhd4K = "4K (2160p)"
    case fullHD = "Full HD (1080p)"
    case hd = "HD (720p)"

    var id: String { rawValue }

    var filenameSuffix: String {
        switch self {
        case .uhd4K: return "_4K"
        case .fullHD: return "_1080p"
        case .hd: return "_720p"
        }
    }

    var targetBitrate: Int64 {
        switch self {
        case .uhd4K: return 20_000_000 // 20 Mbps
        case .fullHD: return 8_000_000 // 8 Mbps
        case .hd: return 4_000_000 // 4 Mbps
        }
    }

    var maxResolution: CGSize? {
        switch self {
        case .uhd4K: return CGSize(width: 3840, height: 2160)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .hd: return CGSize(width: 1280, height: 720)
        }
    }
}
