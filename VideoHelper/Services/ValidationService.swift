import Foundation
import AVFoundation
import UniformTypeIdentifiers

actor ValidationService {

    func validate(
        videoURL: URL,
        thumbnailURL: URL,
        preset: ExportPreset
    ) async throws {
        try checkFileExists(videoURL)
        try checkFileExists(thumbnailURL)

        try checkFileReadable(videoURL)
        try checkFileReadable(thumbnailURL)

        try await checkVideoFormat(videoURL)
        try checkImageFormat(thumbnailURL)

        let outputURL = generateOutputURL(for: videoURL, preset: preset)
        try checkOutputFileNotExists(outputURL)

        let outputDir = outputURL.deletingLastPathComponent()
        // Skip write permission check for sandboxed apps - will be checked during export
        // try checkWritePermissions(outputDir)

        let estimatedSize = try await estimateOutputSize(videoURL: videoURL, preset: preset)
        try checkDiskSpace(in: outputDir, required: estimatedSize)
    }

    // MARK: - Private Methods

    private func checkFileExists(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.fileNotFound(url.path)
        }
    }

    private func checkFileReadable(_ url: URL) throws {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ValidationError.fileNotReadable(url.path)
        }
    }

    private func checkVideoFormat(_ url: URL) async throws {
        let asset = AVAsset(url: url)

        // Check if asset can be loaded
        do {
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else {
                throw ValidationError.unsupportedVideoFormat(url.lastPathComponent)
            }
        } catch {
            throw ValidationError.corruptedFile(url.lastPathComponent)
        }

        // Check for video tracks
        do {
            let tracks = try await asset.load(.tracks)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            guard !videoTracks.isEmpty else {
                throw ValidationError.unsupportedVideoFormat(url.lastPathComponent)
            }
        } catch {
            throw ValidationError.corruptedFile(url.lastPathComponent)
        }
    }

    private func checkImageFormat(_ url: URL) throws {
        guard let contentType = UTType(filenameExtension: url.pathExtension) else {
            throw ValidationError.unsupportedImageFormat(url.lastPathComponent)
        }

        let supportedTypes: [UTType] = [.jpeg, .png, .heic]
        guard supportedTypes.contains(where: { $0.conforms(to: contentType) || contentType.conforms(to: $0) }) else {
            throw ValidationError.unsupportedImageFormat(url.lastPathComponent)
        }
    }

    private func estimateOutputSize(videoURL: URL, preset: ExportPreset) async throws -> Int64 {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)

        switch preset {
        case .original:
            // Original: input size + 10% buffer
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return Int64(Double(fileSize) * 1.1)

        case .telegramSD:
            // SD: 2 Mbps video + 128 kbps audio
            let videoBitrate: Int64 = 2_000_000
            let audioBitrate: Int64 = 128_000
            return Int64(durationInSeconds * Double(videoBitrate + audioBitrate) / 8.0)

        case .telegramHD:
            // HD: 4 Mbps video + 128 kbps audio
            let videoBitrate: Int64 = 4_000_000
            let audioBitrate: Int64 = 128_000
            return Int64(durationInSeconds * Double(videoBitrate + audioBitrate) / 8.0)
        }
    }

    private func checkDiskSpace(in directory: URL, required: Int64) throws {
        let requiredWithBuffer = Int64(Double(required) * 1.2) // 20% buffer

        do {
            let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = values.volumeAvailableCapacityForImportantUsage {
                guard available >= requiredWithBuffer else {
                    throw ValidationError.insufficientDiskSpace(required: requiredWithBuffer, available: available)
                }
            }
        } catch let error as ValidationError {
            throw error
        } catch {
            // If we can't determine disk space, proceed anyway
        }
    }

    private func checkWritePermissions(_ url: URL) throws {
        // For sandboxed apps, when user drops a file, we automatically
        // get write access to the parent directory. Try creating a temp file.
        let testURL = url.appendingPathComponent(".videohelper_test_\(UUID().uuidString)")

        do {
            try Data().write(to: testURL)
            try? FileManager.default.removeItem(at: testURL)
        } catch {
            throw ValidationError.noWritePermission(url)
        }
    }

    private func checkOutputFileNotExists(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            throw ValidationError.outputFileExists(url)
        }
    }

    private func generateOutputURL(for videoURL: URL, preset: ExportPreset) -> URL {
        let directory = videoURL.deletingLastPathComponent()
        let basename = videoURL.deletingPathExtension().lastPathComponent
        let filename = "\(basename)\(preset.filenameSuffix).mp4"
        return directory.appendingPathComponent(filename)
    }
}
