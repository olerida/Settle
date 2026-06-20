import AppKit

@main
enum SettleLoginHelperApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = LoginHelperDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.prohibited)
        application.run()
    }
}

private final class LoginHelperDelegate: NSObject, NSApplicationDelegate {
    private let signal = LoginRestoreSignal()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !signal.consumeRegistrationSuppression() else {
            NSApp.terminate(nil)
            return
        }

        signal.requestLoginRestore()
        DistributedNotificationCenter.default().postNotificationName(
            LoginRestoreSignal.notificationName,
            object: nil
        )

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(
            at: mainApplicationURL,
            configuration: configuration
        ) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private var mainApplicationURL: URL {
        Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
