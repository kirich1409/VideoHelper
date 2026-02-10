import Foundation

enum ExportPreset: String, CaseIterable, Identifiable {
    case fullHD = "Full HD (1080p)"
    case hd = "HD (720p)"
    case sd = "SD (540p)"

    var id: String { rawValue }

    var filenameSuffix: String {
        switch self {
        case .fullHD: return "_1080p"
        case .hd: return "_720p"
        case .sd: return "_540p"
        }
    }

    var targetBitrate: Int64 {
        switch self {
        case .fullHD: return 4_000_000 // 4 Mbps
        case .hd: return 2_000_000 // 2 Mbps
        case .sd: return 1_000_000 // 1 Mbps
        }
    }

    var maxResolution: CGSize? {
        switch self {
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .hd: return CGSize(width: 1280, height: 720)
        case .sd: return CGSize(width: 960, height: 540)
        }
    }
}
