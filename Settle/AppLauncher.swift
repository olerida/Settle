import AppKit
import Foundation

enum AppLauncherError: LocalizedError {
    case appNotInstalled(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotInstalled(let bundleIdentifier):
            L10n.format("The app %@ is not installed.", bundleIdentifier)
        case .launchFailed(let bundleIdentifier):
            L10n.format("This app could not be opened: %@.", bundleIdentifier)
        }
    }
}

struct AppLauncher {
    func ensureRunning(bundleIdentifier: String) async throws -> (NSRunningApplication, Bool) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            return (running, false)
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppLauncherError.appNotInstalled(bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
                if app != nil {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? AppLauncherError.launchFailed(bundleIdentifier))
                }
            }
        }

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                return (running, true)
            }
            try await Task.sleep(for: .milliseconds(250))
        }

        throw AppLauncherError.launchFailed(bundleIdentifier)
    }

    func reopen(bundleIdentifier: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppLauncherError.appNotInstalled(bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
