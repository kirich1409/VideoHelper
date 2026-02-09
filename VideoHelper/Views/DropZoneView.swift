import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    let title: String
    let icon: String
    let acceptedTypes: [UTType]
    @Binding var selectedURL: URL?

    @State private var isTargeted = false

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
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
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
                    DispatchQueue.main.async {
                        self.selectedURL = url
                        print("✅ URL set in state")
                    }
                } else {
                    print("❌ URL is nil")
                }
            }

            return true
        }
    }
}
