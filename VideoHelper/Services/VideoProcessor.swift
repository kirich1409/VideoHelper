import Foundation
import AVFoundation
import CoreImage
import AppKit

actor VideoProcessor {

    // MARK: - Public API

    nonisolated func process(
        videoURL: URL,
        thumbnailURL: URL,
        outputURL: URL,
        preset: ExportPreset
    ) async throws -> URL {
        print("🎬 VideoProcessor.process started")
        print("   Video: \(videoURL.path)")
        print("   Output: \(outputURL.path)")

        // Start accessing security-scoped resources for sandboxed app
        let videoAccess = videoURL.startAccessingSecurityScopedResource()
        let thumbnailAccess = thumbnailURL.startAccessingSecurityScopedResource()
        print("🔐 Security-scoped access: video=\(videoAccess), thumbnail=\(thumbnailAccess)")

        defer {
            if videoAccess { videoURL.stopAccessingSecurityScopedResource() }
            if thumbnailAccess { thumbnailURL.stopAccessingSecurityScopedResource() }
        }

        // 1. Load assets
        print("📹 Loading video asset...")
        let videoAsset = AVAsset(url: videoURL)
        print("🖼️ Loading thumbnail...")
        let thumbnailImage = try loadThumbnailImage(from: thumbnailURL)
        print("✅ Assets loaded")

        // 2. Get video properties
        print("📊 Getting frame rate...")
        let frameRate = try await getFrameRate(from: videoAsset)
        print("✅ Frame rate: \(frameRate)")

        // 3. Create composition with thumbnail metadata (frame insertion pending)
        print("🎞️ Creating composition...")
        let composition = try await createCompositionWithThumbnail(
            video: videoAsset,
            thumbnail: thumbnailImage,
            frameRate: frameRate
        )
        print("✅ Composition created")

        // 4. Add metadata
        print("📝 Adding metadata...")
        let thumbnailData = try loadThumbnailData(from: thumbnailURL)
        let metadataItem = try await addMetadata(to: composition, thumbnailData: thumbnailData, thumbnailURL: thumbnailURL)
        print("✅ Metadata added")

        // 5. Create video composition with thumbnail
        print("🎨 Creating video composition with thumbnail...")
        let videoComposition = try await createVideoComposition(
            for: composition,
            thumbnail: thumbnailImage,
            frameRate: frameRate
        )
        print("✅ Video composition created")

        // 6. Export
        print("💾 Starting export to: \(outputURL.path)")
        try await export(
            composition: composition,
            videoComposition: videoComposition,
            preset: preset,
            outputURL: outputURL,
            metadataItem: metadataItem
        )
        print("✅ Export completed!")

        return outputURL
    }

    // MARK: - Private Methods

    nonisolated private func loadThumbnailImage(from url: URL) throws -> CGImage {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "VideoProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load thumbnail image"])
        }
        return cgImage
    }

    nonisolated private func loadThumbnailData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    nonisolated private func getFrameRate(from asset: AVAsset) async throws -> Float {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "VideoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        return nominalFrameRate > 0 ? nominalFrameRate : 30.0 // Default to 30fps if not available
    }

    nonisolated private func createCompositionWithThumbnail(
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
        let sourceVideoTracks = try await video.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = sourceVideoTracks.first else {
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
        let sourceAudioTracks = try await video.loadTracks(withMediaType: .audio)
        if let sourceAudioTrack = sourceAudioTracks.first {
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

    nonisolated private func addMetadata(to composition: AVMutableComposition, thumbnailData: Data, thumbnailURL: URL) async throws -> AVMetadataItem {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.identifier = .commonIdentifierArtwork

        // Determine data type from actual image data using CGImageSource
        let dataType: String
        if let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil),
           let imageType = CGImageSourceGetType(imageSource) {
            // Map UTType to metadata data type
            if UTType(imageType as String) == .png {
                dataType = kCMMetadataBaseDataType_PNG as String
            } else if UTType(imageType as String) == .heic || UTType(imageType as String) == .heif {
                dataType = "com.apple.quicktime.artwork"
            } else {
                dataType = kCMMetadataBaseDataType_JPEG as String
            }
        } else {
            // Fallback to file extension if image source fails
            let pathExtension = thumbnailURL.pathExtension.lowercased()
            dataType = switch pathExtension {
            case "png":
                kCMMetadataBaseDataType_PNG as String
            case "heic", "heif":
                "com.apple.quicktime.artwork"
            default:
                kCMMetadataBaseDataType_JPEG as String
            }
        }

        metadataItem.dataType = dataType
        metadataItem.value = thumbnailData as NSData

        return metadataItem
    }

    nonisolated private func createVideoComposition(
        for composition: AVMutableComposition,
        thumbnail: CGImage,
        frameRate: Float
    ) async throws -> AVMutableVideoComposition {
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // Get video track
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoProcessor", code: 10, userInfo: [NSLocalizedDescriptionKey: "No video track in composition"])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)

        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = frameDuration
        videoComposition.renderSize = naturalSize

        // Create layer for thumbnail (first frame)
        let thumbnailLayer = CALayer()
        thumbnailLayer.contents = thumbnail
        thumbnailLayer.frame = CGRect(origin: .zero, size: naturalSize)
        thumbnailLayer.contentsGravity = .resizeAspect

        // Create parent layer
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: naturalSize)

        // Create video layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: naturalSize)

        // Add layers: thumbnail first (at t=0), then video
        parentLayer.addSublayer(videoLayer)

        // Animation to show thumbnail only for first frame
        let thumbnailAnimation = CABasicAnimation(keyPath: "opacity")
        thumbnailAnimation.fromValue = 1.0
        thumbnailAnimation.toValue = 0.0
        thumbnailAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
        thumbnailAnimation.duration = CMTimeGetSeconds(frameDuration)
        thumbnailAnimation.fillMode = .forwards
        thumbnailAnimation.isRemovedOnCompletion = false
        thumbnailLayer.add(thumbnailAnimation, forKey: "opacity")

        parentLayer.insertSublayer(thumbnailLayer, above: videoLayer)

        // Set up animation tool
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // Create instruction for entire duration
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]

        return videoComposition
    }

    nonisolated private func export(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition,
        preset: ExportPreset,
        outputURL: URL,
        metadataItem: AVMetadataItem
    ) async throws {
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Determine export preset
        let exportPresetName: String
        switch preset {
        case .uhd4K:
            exportPresetName = AVAssetExportPreset3840x2160 // 4K
        case .fullHD, .telegramHD:
            exportPresetName = AVAssetExportPreset1920x1080 // 1080p
        case .hd, .telegramSD:
            exportPresetName = AVAssetExportPreset1280x720 // 720p
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: exportPresetName) else {
            throw NSError(domain: "VideoProcessor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true // Fast start for streaming
        exportSession.metadata = [metadataItem]
        exportSession.videoComposition = videoComposition

        // Simple export without progress tracking
        await exportSession.export()

        // Check result
        switch exportSession.status {
        case .completed:
            break
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

    nonisolated private func generateOutputURL(for videoURL: URL, preset: ExportPreset) -> URL {
        let directory = videoURL.deletingLastPathComponent()
        let basename = videoURL.deletingPathExtension().lastPathComponent
        let filename = "\(basename)\(preset.filenameSuffix).mp4"
        return directory.appendingPathComponent(filename)
    }
}
