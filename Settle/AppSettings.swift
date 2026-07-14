import Combine
import Foundation
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable
}

enum AutomaticExtraWindowsBehavior: String, CaseIterable {
    case leaveUntouched
    case minimize
    case close
}

protocol LoginItemServicing {
    var state: LaunchAtLoginState { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemService: LoginItemServicing {
    private let service: SMAppService
    private let signal: LoginRestoreSignal

    init(signal: LoginRestoreSignal = LoginRestoreSignal()) {
        self.service = SMAppService.loginItem(identifier: LoginRestoreSignal.helperBundleIdentifier)
        self.signal = signal
        migrateLegacyMainAppRegistrationIfNeeded()
    }

    var state: LaunchAtLoginState {
        switch service.status {
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
        signal.prepareForRegistration()
        do {
            try service.register()
        } catch {
            signal.cancelRegistrationPreparation()
            throw error
        }
    }

    func unregister() throws {
        try service.unregister()
        signal.cancelRegistrationPreparation()
    }

    private func migrateLegacyMainAppRegistrationIfNeeded() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let legacyStatus = SMAppService.mainApp.status
        guard legacyStatus == .enabled || legacyStatus == .requiresApproval else { return }

        do {
            try SMAppService.mainApp.unregister()
            guard service.status == .notRegistered else { return }
            signal.prepareForRegistration()
            try service.register()
        } catch {
            signal.cancelRegistrationPreparation()
            try? SMAppService.mainApp.register()
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var defaultLayoutID: UUID?
    @Published private(set) var layoutSwitcherShortcut: LayoutSwitcherShortcut?
    @Published private(set) var automaticExtraWindowsBehavior: AutomaticExtraWindowsBehavior

    private enum Keys {
        static let defaultLayoutID = "defaultLayoutID"
        static let layoutSwitcherShortcut = "layoutSwitcherShortcut"
        static let layoutSwitcherDisabled = "layoutSwitcherDisabled"
        static let automaticExtraWindowsBehavior = "automaticExtraWindowsBehavior"
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
        self.automaticExtraWindowsBehavior = AutomaticExtraWindowsBehavior(
            rawValue: defaults.string(forKey: Keys.automaticExtraWindowsBehavior) ?? ""
        ) ?? .leaveUntouched
        self.defaultLayoutID = defaults
            .string(forKey: Keys.defaultLayoutID)
            .flatMap(UUID.init(uuidString:))
        if defaults.bool(forKey: Keys.layoutSwitcherDisabled) {
            self.layoutSwitcherShortcut = nil
        } else if
            let data = defaults.data(forKey: Keys.layoutSwitcherShortcut),
            let shortcut = try? JSONDecoder().decode(LayoutSwitcherShortcut.self, from: data)
        {
            self.layoutSwitcherShortcut = shortcut
        } else {
            self.layoutSwitcherShortcut = .defaultShortcut
        }
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

    func setLayoutSwitcherShortcut(_ shortcut: LayoutSwitcherShortcut?) {
        layoutSwitcherShortcut = shortcut
        guard let shortcut else {
            defaults.removeObject(forKey: Keys.layoutSwitcherShortcut)
            defaults.set(true, forKey: Keys.layoutSwitcherDisabled)
            return
        }
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: Keys.layoutSwitcherShortcut)
        }
        defaults.set(false, forKey: Keys.layoutSwitcherDisabled)
    }

    func resetLayoutSwitcherShortcut() {
        setLayoutSwitcherShortcut(.defaultShortcut)
    }

    func setAutomaticExtraWindowsBehavior(_ behavior: AutomaticExtraWindowsBehavior) {
        automaticExtraWindowsBehavior = behavior
        defaults.set(behavior.rawValue, forKey: Keys.automaticExtraWindowsBehavior)
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
