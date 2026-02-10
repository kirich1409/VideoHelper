import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = ProcessingQueueViewModel()

    @State private var selectedVideo: URL?
    @State private var selectedThumbnail: URL?
    @State private var selectedPreset: ExportPreset = .fullHD
    @State private var hasUserResized = false
    @State private var estimatedSize: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Drag & Drop Section
            dropZoneSection

            // Settings Section
            settingsSection

            // Queue Section
            queueSection
        }
        .padding()
        .frame(minWidth: 600, minHeight: 600)
        .task {
            await NotificationManager.shared.requestAuthorization()
        }
        .onChange(of: viewModel.tasks.count) { oldValue, newValue in
            // When first task is added, expand window
            if oldValue == 0 && newValue == 1 && !hasUserResized {
                expandWindowForQueue()
            }
        }
        .background(WindowAccessor(onWindowResize: {
            hasUserResized = true
        }))
    }

    // MARK: - Drop Zone Section

    private var dropZoneSection: some View {
        HStack(spacing: 16) {
            DropZoneView(
                title: NSLocalizedString("drop_video", comment: ""),
                icon: "video.fill",
                acceptedTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                selectedURL: $selectedVideo,
                accentColor: .blue
            )
            .onChange(of: selectedVideo) { _, _ in
                updateEstimatedSize()
            }

            DropZoneView(
                title: NSLocalizedString("drop_thumbnail", comment: ""),
                icon: "photo.fill",
                acceptedTypes: [.image],
                selectedURL: $selectedThumbnail,
                accentColor: .purple
            )
        }
        .frame(height: 160)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(NSLocalizedString("quality", comment: ""))
                    .font(.headline)

                Picker("", selection: $selectedPreset) {
                    ForEach(ExportPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 250)
                .accessibilityIdentifier("qualityPicker")
                .onChange(of: selectedPreset) { _, _ in
                    updateEstimatedSize()
                }

                Spacer()
            }

            if !estimatedSize.isEmpty {
                HStack {
                    Image(systemName: "doc.badge.gearshape")
                        .foregroundColor(.secondary)
                    Text(String(format: NSLocalizedString("estimated_size", comment: ""), estimatedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            Button(action: addToQueue) {
                Text(NSLocalizedString("add_to_queue", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddToQueue)
            .accessibilityIdentifier("addToQueueButton")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }

    // MARK: - Queue Section

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("queue_title", comment: ""))
                    .font(.headline)

                Spacer()

                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text(NSLocalizedString("processing", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.tasks.isEmpty {
                        Text(NSLocalizedString("queue_empty", comment: ""))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(viewModel.tasks) { task in
                            QueueItemView(
                                task: task,
                                onRemove: {
                                    viewModel.removeTask(id: task.id)
                                },
                                onShowInFinder: {
                                    if let url = task.outputURL {
                                        viewModel.showInFinder(url: url)
                                    }
                                }
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.05))
                            )
                        }
                    }
                }
            }
            .frame(minHeight: 100)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Actions

    private var canAddToQueue: Bool {
        selectedVideo != nil && selectedThumbnail != nil
    }

    private func addToQueue() {
        guard let video = selectedVideo, let thumbnail = selectedThumbnail else { return }

        Task {
            await viewModel.addTask(video: video, thumbnail: thumbnail, preset: selectedPreset)

            // Clear selection after adding
            selectedVideo = nil
            selectedThumbnail = nil
        }
    }

    private func expandWindowForQueue() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.keyWindow {
                var frame = window.frame
                let targetHeight: CGFloat = 500

                // Only expand if current height is less than target
                if frame.size.height < targetHeight {
                    let heightDiff = targetHeight - frame.size.height
                    frame.origin.y -= heightDiff // Move window up to keep top position
                    frame.size.height = targetHeight

                    // Smooth animation with NSAnimationContext
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.3
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        window.animator().setFrame(frame, display: true)
                    })
                }
            }
        }
    }

    private func updateEstimatedSize() {
        guard let videoURL = selectedVideo else {
            estimatedSize = ""
            return
        }

        Task {
            do {
                let asset = AVAsset(url: videoURL)
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)

                let bitrate = selectedPreset.targetBitrate
                let audioBitrate: Int64 = 192_000 // Average audio bitrate

                let estimatedBytes = Int64(durationInSeconds * Double(bitrate + audioBitrate) / 8.0)
                let formattedSize = ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)

                await MainActor.run {
                    estimatedSize = formattedSize
                }
            } catch {
                await MainActor.run {
                    estimatedSize = ""
                }
            }
        }
    }
}

// MARK: - Window Accessor Helper

struct WindowAccessor: NSViewRepresentable {
    let onWindowResize: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    onWindowResize()
                }
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    ContentView()
        .frame(width: 600, height: 700)
}
