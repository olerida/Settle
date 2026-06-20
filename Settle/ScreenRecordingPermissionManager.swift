import Combine
import CoreGraphics

@MainActor
final class ScreenRecordingPermissionManager: ObservableObject {
    @Published private(set) var isGranted = false

    init() {
        refresh()
    }

    func refresh() {
        isGranted = CGPreflightScreenCaptureAccess()
    }

    func requestIfNeeded() {
        guard !isGranted else { return }
        isGranted = CGRequestScreenCaptureAccess()
    }
}
