import DeviceActivity
import Foundation

@available(iOS 16.0, *)
final class ScreenTimeMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == "littlewins.playtime" else { return }
        // Always consult the current receipt: a late callback must not end a newer purchase.
        ProtectionState.enforce()
    }
}
