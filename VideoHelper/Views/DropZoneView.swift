import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import AppKit
@preconcurrency import AVFoundation

struct DropZoneView: View {
    let title: String
    let icon: String
    let acceptedTypes: [UTType]
    @Binding var selectedURL: URL?
    var accentColor: Color = .blue

    @State private var isTargeted = false
    @State private var videoThumbnail: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            if let url = selectedURL {
                // Show selected file
                VStack(spacing: 8) {
                    if acceptedTypes.contains(.image), let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 120, maxHeight: 80)
                            .cornerRadius(8)
                    } else if acceptedTypes.contains(.movie), let thumbnail = videoThumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 120, maxHeight: 80)
                            .cornerRadius(8)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    }

                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        selectedURL = nil
                        videoThumbnail = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 48))
                        .foregroundColor(isTargeted ? accentColor : accentColor.opacity(0.6))

                    Text(title)
                        .font(.headline)
                        .foregroundColor(isTargeted ? accentColor : .primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .accessibilityLabel(title)
        .accessibilityIdentifier("dropZone_\(title)")
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? accentColor.opacity(0.15) : accentColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? accentColor : accentColor.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else {
                print("❌ No provider")
                return false
            }

            print("✅ Drop received, loading file...")

            // Load file URL
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let error = error {
                    print("❌ Error loading URL: \(error)")
                    return
                }

                if let url = url {
                    print("✅ Got URL: \(url.path)")

                    // Generate video thumbnail if it's a video file
                    if self.acceptedTypes.contains(.movie) {
                        Task {
                            let thumbnail = await self.generateVideoThumbnail(from: url)
                            await MainActor.run {
                                self.selectedURL = url
                                self.videoThumbnail = thumbnail
                                print("✅ URL and thumbnail set in state")
                            }
                        }
                    } else {
                        Task { @MainActor in
                            self.selectedURL = url
                            print("✅ URL set in state")
                        }
                    }
                } else {
                    print("❌ URL is nil")
                }
            }

            return true
        }
    }

    // MARK: - Video Thumbnail Generation

    private nonisolated func generateVideoThumbnail(from url: URL) async -> NSImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 240, height: 180)

        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("❌ Failed to generate video thumbnail: \(error)")
            return nil
        }
    }
}
