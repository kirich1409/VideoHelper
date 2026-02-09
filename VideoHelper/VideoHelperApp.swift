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
        .defaultSize(width: 600, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var queueViewModel: ProcessingQueueViewModel?

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
