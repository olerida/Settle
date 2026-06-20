import Foundation

struct LoginRestoreSignal {
    static let helperBundleIdentifier = "com.olerida.Settle.LoginHelper"
    static let notificationName = Notification.Name("com.olerida.Settle.loginRestoreRequested")

    private enum Keys {
        static let registrationDate = "loginHelper.registrationDate"
        static let pendingRestoreDate = "loginHelper.pendingRestoreDate"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "com.olerida.Settle.shared") ?? .standard) {
        self.defaults = defaults
    }

    func prepareForRegistration(at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: Keys.registrationDate)
        defaults.synchronize()
    }

    func cancelRegistrationPreparation() {
        defaults.removeObject(forKey: Keys.registrationDate)
        defaults.synchronize()
    }

    func consumeRegistrationSuppression(
        at date: Date = .now,
        maximumAge: TimeInterval = 60
    ) -> Bool {
        let registeredAt = defaults.double(forKey: Keys.registrationDate)
        defaults.removeObject(forKey: Keys.registrationDate)
        defaults.synchronize()

        guard registeredAt > 0 else { return false }
        let age = date.timeIntervalSince1970 - registeredAt
        return age >= 0 && age <= maximumAge
    }

    func requestLoginRestore(at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: Keys.pendingRestoreDate)
        defaults.synchronize()
    }

    func consumeLoginRestoreRequest(
        at date: Date = .now,
        maximumAge: TimeInterval = 300
    ) -> Bool {
        let requestedAt = defaults.double(forKey: Keys.pendingRestoreDate)
        defaults.removeObject(forKey: Keys.pendingRestoreDate)
        defaults.synchronize()

        guard requestedAt > 0 else { return false }
        let age = date.timeIntervalSince1970 - requestedAt
        return age >= 0 && age <= maximumAge
    }
}
