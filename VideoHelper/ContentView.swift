import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ProcessingQueueViewModel()

    @State private var selectedVideo: URL?
    @State private var selectedThumbnail: URL?
    @State private var selectedPreset: ExportPreset = .original

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
        .frame(minWidth: 480, minHeight: 600)
        .task {
            await NotificationManager.shared.requestAuthorization()
        }
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

                Spacer()
            }

            Button(action: addToQueue) {
                Text("Добавить в очередь")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddToQueue)
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

            if viewModel.tasks.isEmpty {
                VStack {
                    Spacer()
                    Text("Очередь пуста")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
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
}

#Preview {
    ContentView()
        .frame(width: 600, height: 700)
}
