import SwiftUI

@main
struct VideoHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var queueViewModel = ProcessingQueueViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queueViewModel)
                .onAppear {
                    appDelegate.queueViewModel = queueViewModel
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 400)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var queueViewModel: ProcessingQueueViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        let runningApps = NSWorkspace.shared.runningApplications
        let videoHelperApps = runningApps.filter { app in
            app.bundleIdentifier == Bundle.main.bundleIdentifier && app != NSRunningApplication.current
        }

        if !videoHelperApps.isEmpty {
            // Another instance is running - activate it and quit this one
            videoHelperApps.first?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let viewModel = queueViewModel else { return .terminateNow }

        if viewModel.hasActiveTasks {
            let alert = NSAlert()
            alert.messageText = "Обработка видео в процессе"
            alert.informativeText = "Вы уверены что хотите выйти? Незавершенные задачи будут отменены."
            alert.addButton(withTitle: "Отмена")
            alert.addButton(withTitle: "Выйти")
            alert.alertStyle = .warning

            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }

        return .terminateNow
    }
}
