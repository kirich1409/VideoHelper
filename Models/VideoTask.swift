import Foundation

struct VideoTask: Identifiable {
    let id: UUID
    let videoURL: URL
    let thumbnailURL: URL
    let preset: ExportPreset
    var status: TaskStatus
    var progress: Float
    var estimatedTimeRemaining: TimeInterval?
    var outputURL: URL?
    var error: String?

    init(
        id: UUID = UUID(),
        videoURL: URL,
        thumbnailURL: URL,
        preset: ExportPreset,
        status: TaskStatus = .pending,
        progress: Float = 0.0,
        estimatedTimeRemaining: TimeInterval? = nil,
        outputURL: URL? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.preset = preset
        self.status = status
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.outputURL = outputURL
        self.error = error
    }

    var displayName: String {
        "\(videoURL.deletingPathExtension().lastPathComponent) • \(preset.rawValue)"
    }

    var outputFileName: String {
        let basename = videoURL.deletingPathExtension().lastPathComponent
        return "\(basename)\(preset.filenameSuffix).mp4"
    }
}
