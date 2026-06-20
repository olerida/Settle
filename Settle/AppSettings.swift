import Combine
import Foundation
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable
}

protocol LoginItemServicing {
    var state: LaunchAtLoginState { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemService: LoginItemServicing {
    var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var defaultLayoutID: UUID?

    private enum Keys {
        static let defaultLayoutID = "defaultLayoutID"
    }

    private let defaults: UserDefaults
    private let loginItemService: any LoginItemServicing

    init(
        defaults: UserDefaults = .standard,
        loginItemService: any LoginItemServicing = SystemLoginItemService()
    ) {
        self.defaults = defaults
        self.loginItemService = loginItemService
        self.launchAtLoginState = loginItemService.state
        self.defaultLayoutID = defaults
            .string(forKey: Keys.defaultLayoutID)
            .flatMap(UUID.init(uuidString:))
    }

    var isLaunchAtLoginRequested: Bool {
        launchAtLoginState == .enabled || launchAtLoginState == .requiresApproval
    }

    func setDefaultLayoutID(_ id: UUID?) {
        defaultLayoutID = id
        if let id {
            defaults.set(id.uuidString, forKey: Keys.defaultLayoutID)
        } else {
            defaults.removeObject(forKey: Keys.defaultLayoutID)
        }
    }

    func reconcileDefaultLayout(availableLayoutIDs: Set<UUID>) {
        guard let defaultLayoutID, !availableLayoutIDs.contains(defaultLayoutID) else { return }
        setDefaultLayoutID(nil)
    }

    func clearDefaultLayout(ifMatches layoutID: UUID) {
        guard defaultLayoutID == layoutID else { return }
        setDefaultLayoutID(nil)
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginState = loginItemService.state
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        guard enabled != isLaunchAtLoginRequested else {
            refreshLaunchAtLoginState()
            return
        }

        do {
            if enabled {
                try loginItemService.register()
            } else {
                try loginItemService.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }

        refreshLaunchAtLoginState()
    }
}
