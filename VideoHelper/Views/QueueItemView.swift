import SwiftUI
import AVFoundation

struct QueueItemView: View {
    let task: VideoTask
    let onRemove: () -> Void
    let onShowInFinder: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "video.fill")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(task.status.emoji)
                    Text(task.status.displayText)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                }

                if task.status == .failed, let error = task.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(8)
        .task {
            await loadThumbnail()
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch task.status {
        case .pending, .failed:
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("remove_from_queue", comment: ""))

        case .completed:
            Button(action: onShowInFinder) {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("show_in_finder", comment: ""))

        case .processing:
            ProgressView()
                .controlSize(.small)
        }
    }

    private func loadThumbnail() async {
        let asset = AVAsset(url: task.videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try await generator.image(at: .zero).image
            await MainActor.run {
                thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        } catch {
            // Use default icon if thumbnail generation fails
        }
    }
}
