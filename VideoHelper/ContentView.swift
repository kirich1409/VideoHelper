import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = ProcessingQueueViewModel()

    @State private var selectedVideo: URL?
    @State private var selectedThumbnail: URL?
    @State private var selectedPreset: ExportPreset = .fullHD
    @State private var hasUserResized = false

    var body: some View {
        VStack(spacing: 20) {
            // Drag & Drop Section
            dropZoneSection

            // Settings Section
            settingsSection

            // Queue Section - only show when not empty
            if !viewModel.tasks.isEmpty {
                queueSection
            }
        }
        .padding()
        .frame(minWidth: 600)
        .task {
            await NotificationManager.shared.requestAuthorization()
        }
        .onChange(of: viewModel.tasks.isEmpty) { oldValue, newValue in
            // When queue becomes non-empty, expand window
            if oldValue == true && newValue == false && !hasUserResized {
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
                title: "Перетащите видео",
                icon: "video.fill",
                acceptedTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                selectedURL: $selectedVideo
            )

            DropZoneView(
                title: "Перетащите картинку",
                icon: "photo.fill",
                acceptedTypes: [.image],
                selectedURL: $selectedThumbnail
            )
        }
        .frame(height: 160)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Качество:")
                    .font(.headline)

                Picker("", selection: $selectedPreset) {
                    ForEach(ExportPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 250)
                .accessibilityIdentifier("qualityPicker")

                Spacer()
            }

            Button(action: addToQueue) {
                Text("Добавить в очередь")
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
                Text("Очередь обработки")
                    .font(.headline)

                Spacer()

                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Обработка...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
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
