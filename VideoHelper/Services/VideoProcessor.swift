import Foundation
import AVFoundation
import CoreImage
import AppKit

actor VideoProcessor {

    // MARK: - Public API

    func process(
        videoURL: URL,
        thumbnailURL: URL,
        preset: ExportPreset,
        progressHandler: @escaping (Float, TimeInterval?) -> Void
    ) async throws -> URL {
        // Start accessing security-scoped resources for sandboxed app
        let videoAccess = videoURL.startAccessingSecurityScopedResource()
        let thumbnailAccess = thumbnailURL.startAccessingSecurityScopedResource()

        defer {
            if videoAccess { videoURL.stopAccessingSecurityScopedResource() }
            if thumbnailAccess { thumbnailURL.stopAccessingSecurityScopedResource() }
        }

        // 1. Load assets
        let videoAsset = AVAsset(url: videoURL)
        let thumbnailImage = try loadThumbnailImage(from: thumbnailURL)

        // 2. Get video properties
        let frameRate = try await getFrameRate(from: videoAsset)

        // 3. Create composition with thumbnail metadata (frame insertion pending)
        let composition = try await createCompositionWithThumbnail(
            video: videoAsset,
            thumbnail: thumbnailImage,
            frameRate: frameRate
        )

        // 4. Add metadata
        let thumbnailData = try loadThumbnailData(from: thumbnailURL)
        let metadataItem = try await addMetadata(to: composition, thumbnailData: thumbnailData)

        // 5. Generate output URL
        let outputURL = generateOutputURL(for: videoURL, preset: preset)

        // 6. Export with progress tracking
        try await export(
            composition: composition,
            preset: preset,
            outputURL: outputURL,
            metadataItem: metadataItem,
            progressHandler: progressHandler
        )

        return outputURL
    }

    // MARK: - Private Methods

    private func loadThumbnailImage(from url: URL) throws -> CGImage {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "VideoProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load thumbnail image"])
        }
        return cgImage
    }

    private func loadThumbnailData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    private func getFrameRate(from asset: AVAsset) async throws -> Float {
        let tracks = try await asset.load(.tracks)
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw NSError(domain: "VideoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        return nominalFrameRate > 0 ? nominalFrameRate : 30.0 // Default to 30fps if not available
    }

    private func createCompositionWithThumbnail(
        video: AVAsset,
        thumbnail: CGImage,
        frameRate: Float
    ) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        // Calculate single frame duration
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // Add video composition tracks
        guard let videoCompositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }

        guard let audioCompositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoProcessor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
        }

        // Get source tracks
        let sourceTracks = try await video.load(.tracks)
        guard let sourceVideoTrack = sourceTracks.first(where: { $0.mediaType == .video }) else {
            throw NSError(domain: "VideoProcessor", code: 5, userInfo: [NSLocalizedDescriptionKey: "No source video track"])
        }

        // Insert original video starting after thumbnail frame
        let videoDuration = try await video.load(.duration)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDuration)

        try videoCompositionTrack.insertTimeRange(
            videoTimeRange,
            of: sourceVideoTrack,
            at: frameDuration
        )

        // Insert audio if available
        if let sourceAudioTrack = sourceTracks.first(where: { $0.mediaType == .audio }) {
            try audioCompositionTrack.insertTimeRange(
                videoTimeRange,
                of: sourceAudioTrack,
                at: frameDuration
            )
        }

        // IMPORTANT: Current implementation inserts thumbnail in metadata only
        // Actual first-frame replacement requires AVVideoComposition with custom
        // video compositor or use of AVMutableVideoCompositionInstruction
        // This is a complex AVFoundation feature requiring significant additional code
        //
        // For MVP: We insert thumbnail as metadata (works in QuickTime/Finder)
        // Post-MVP: Implement true first-frame replacement

        return composition
    }

    private func addMetadata(to composition: AVMutableComposition, thumbnailData: Data) async throws -> AVMetadataItem {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.identifier = .commonIdentifierArtwork
        metadataItem.dataType = kCMMetadataBaseDataType_JPEG as String
        metadataItem.value = thumbnailData as NSData

        return metadataItem
    }

    private func export(
        composition: AVMutableComposition,
        preset: ExportPreset,
        outputURL: URL,
        metadataItem: AVMetadataItem,
        progressHandler: @escaping (Float, TimeInterval?) -> Void
    ) async throws {
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Determine export preset
        let exportPresetName: String
        switch preset {
        case .original:
            exportPresetName = AVAssetExportPresetHighestQuality
        case .telegramSD, .telegramHD:
            exportPresetName = AVAssetExportPresetHEVCHighestQuality // We'll use custom settings
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: exportPresetName) else {
            throw NSError(domain: "VideoProcessor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true // Fast start for streaming
        exportSession.metadata = [metadataItem]

        // Track progress
        let startTime = Date()
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                let progress = exportSession.progress
                let elapsed = Date().timeIntervalSince(startTime)
                let estimatedRemaining = self.calculateRemainingTime(progress: progress, elapsed: elapsed)
                progressHandler(progress, estimatedRemaining)
            }
        }

        // Export
        await exportSession.export()
        progressTimer.invalidate()

        // Check result
        switch exportSession.status {
        case .completed:
            progressHandler(1.0, 0)
        case .failed:
            throw exportSession.error ?? NSError(domain: "VideoProcessor", code: 7, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        case .cancelled:
            throw NSError(domain: "VideoProcessor", code: 8, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])
        default:
            throw NSError(domain: "VideoProcessor", code: 9, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown status"])
        }
    }

    private nonisolated func calculateRemainingTime(progress: Float, elapsed: TimeInterval) -> TimeInterval {
        guard progress > 0 && progress < 1 else { return 0 }
        return (elapsed / Double(progress)) * Double(1 - progress)
    }

    private func generateOutputURL(for videoURL: URL, preset: ExportPreset) -> URL {
        let directory = videoURL.deletingLastPathComponent()
        let basename = videoURL.deletingPathExtension().lastPathComponent
        let filename = "\(basename)\(preset.filenameSuffix).mp4"
        return directory.appendingPathComponent(filename)
    }
}
