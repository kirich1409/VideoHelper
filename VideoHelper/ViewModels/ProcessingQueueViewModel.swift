import Foundation
import AppKit
import Combine

@MainActor
class ProcessingQueueViewModel: ObservableObject {
    @Published var tasks: [VideoTask] = []
    @Published var isProcessing: Bool = false

    private let videoProcessor = VideoProcessor()
    private let validator = ValidationService()
    private let notificationManager = NotificationManager.shared

    // MARK: - Public Methods

    func addTask(video: URL, thumbnail: URL, preset: ExportPreset) async {
        do {
            // Validate before adding
            try await validator.validate(videoURL: video, thumbnailURL: thumbnail, preset: preset)

            // Create and add task
            let task = VideoTask(videoURL: video, thumbnailURL: thumbnail, preset: preset)
            tasks.append(task)

            // Start processing if not already running
            if !isProcessing {
                await processQueue()
            }
        } catch {
            // Show error alert
            await showError(error.localizedDescription)
        }
    }

    func addBatchTasks(videos: [URL], thumbnail: URL, preset: ExportPreset) async {
        var validTasks: [VideoTask] = []
        var errors: [String] = []

        for video in videos {
            do {
                try await validator.validate(videoURL: video, thumbnailURL: thumbnail, preset: preset)
                let task = VideoTask(videoURL: video, thumbnailURL: thumbnail, preset: preset)
                validTasks.append(task)
            } catch {
                errors.append("\(video.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !errors.isEmpty {
            await showError("Некоторые файлы не прошли валидацию:\n" + errors.joined(separator: "\n"))
        }

        if !validTasks.isEmpty {
            tasks.append(contentsOf: validTasks)

            if !isProcessing {
                await processQueue()
            }
        }
    }

    func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id && $0.status == .pending }
    }

    func showInFinder(url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    // MARK: - Private Methods

    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        var successCount = 0
        let totalCount = tasks.filter { $0.status == .pending }.count

        while let index = tasks.firstIndex(where: { $0.status == .pending }) {
            var task = tasks[index]
            task.status = .processing
            tasks[index] = task

            do {
                let outputURL = try await videoProcessor.process(
                    videoURL: task.videoURL,
                    thumbnailURL: task.thumbnailURL,
                    preset: task.preset,
                    progressHandler: { [weak self] progress, timeRemaining in
                        Task { @MainActor in
                            guard let self = self else { return }
                            if let taskIndex = self.tasks.firstIndex(where: { $0.id == task.id }) {
                                var updatedTask = self.tasks[taskIndex]
                                updatedTask.progress = progress
                                updatedTask.estimatedTimeRemaining = timeRemaining
                                self.tasks[taskIndex] = updatedTask
                            }
                        }
                    }
                )

                // Success
                var completedTask = tasks[index]
                completedTask.status = .completed
                completedTask.outputURL = outputURL
                completedTask.progress = 1.0
                completedTask.estimatedTimeRemaining = nil
                tasks[index] = completedTask
                successCount += 1

            } catch {
                // Failure
                var failedTask = tasks[index]
                failedTask.status = .failed
                failedTask.error = error.localizedDescription
                tasks[index] = failedTask
            }
        }

        isProcessing = false

        // Send notification
        if totalCount > 0 {
            await notificationManager.notifyQueueCompleted(totalCount: totalCount, successCount: successCount)
        }
    }

    private func showError(_ message: String) async {
        let alert = NSAlert()
        alert.messageText = "Ошибка"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Computed Properties

    var hasActiveTasks: Bool {
        tasks.contains { $0.status == .processing || $0.status == .pending }
    }
}
