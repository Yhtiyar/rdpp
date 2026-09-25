import Flutter
import UIKit
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

@available(iOS 16.0, *)
@MainActor
final class ScreenTimeBridge {
    private let channel: FlutterMethodChannel
    private var expiryTimer: Timer?
    private var pickerController: UIViewController?
    private var pickerResult: FlutterResult?
    private let center = DeviceActivityCenter()
    private static let activity = DeviceActivityName("littlewins.playtime")

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "littlewins/screen_time", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            self.handle(call, result: result)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        resume()
    }

    @objc private func background() { finishPicker(selection: nil) }

    @objc private func resume() {
        ProtectionState.enforce()
        scheduleForegroundExpiry()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "status": result(ProtectionState.status())
        case "authorize":
            Task { @MainActor in
                do {
                    // Child authorization requires a child Apple ID in Family Sharing and parent approval.
                    try await AuthorizationCenter.shared.requestAuthorization(for: .child)
                    ProtectionState.defaults.set(true, forKey: "enabled")
                    ProtectionState.enforce()
                    result(ProtectionState.status())
                } catch { result(FlutterError(code: "authorization", message: error.localizedDescription, details: nil)) }
            }
        case "configureEssentials":
            guard ProtectionState.authorized else {
                result(FlutterError(code: "authorization", message: "Connect Screen Time first.", details: nil)); return
            }
            let arguments = call.arguments as? [String: Any]
            presentPicker(russian: arguments?["locale"] as? String == "ru", result: result)
        case "unlock":
            guard let args = call.arguments as? [String: Any], let minutes = args["minutes"] as? Int,
                  let id = args["transactionId"] as? String, [15, 30, 45].contains(minutes), ProtectionState.authorized else {
                result(FlutterError(code: "authorization", message: "Screen Time permission or duration is invalid.", details: nil)); return
            }
            if ProtectionState.transactionId == id {
                result(["endsAt": Int64(ProtectionState.expiry.timeIntervalSince1970 * 1000)]); return
            }
            guard ProtectionState.expiry <= Date() else {
                result(FlutterError(code: "active", message: "An access window is already active.", details: nil)); return
            }
            let now = Date()
            let end = Date(timeIntervalSince1970: ceil(now.timeIntervalSince1970 + Double(minutes * 60)))
            let calendar = Calendar.current
            // Begin one second earlier so the minimum 15-minute interval is never rounded short.
            let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now.addingTimeInterval(-1))
            let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end)
            do {
                center.stopMonitoring([Self.activity])
                try center.startMonitoring(Self.activity, during: DeviceActivitySchedule(intervalStart: startComponents, intervalEnd: endComponents, repeats: false))
                // Register the background deadline before lifting any restrictions.
                try ProtectionState.saveReceipt(transactionId: id, endsAt: end)
                ProtectionState.enforce()
                scheduleForegroundExpiry()
                result(["endsAt": Int64(end.timeIntervalSince1970 * 1000)])
            } catch { result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil)) }
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func scheduleForegroundExpiry() {
        expiryTimer?.invalidate()
        let remaining = ProtectionState.expiry.timeIntervalSinceNow
        guard remaining > 0 else { return }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { _ in ProtectionState.enforce() }
    }

    private func presentPicker(russian: Bool, result: @escaping FlutterResult) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            result(FlutterError(code: "presentation", message: "No active window.", details: nil)); return
        }
        while let next = presenter.presentedViewController { presenter = next }
        guard pickerResult == nil else {
            result(FlutterError(code: "busy", message: "An essentials picker is already open.", details: nil)); return
        }
        pickerResult = result
        let host = UIHostingController(rootView: EssentialsPicker(russian: russian, selection: ProtectionState.selection) { [weak self] selection in
            self?.finishPicker(selection: selection)
        })
        host.isModalInPresentation = true
        pickerController = host
        presenter.present(host, animated: true)
    }

    private func finishPicker(selection: FamilyActivitySelection?) {
        guard let result = pickerResult else { return }
        pickerResult = nil
        let active = UIApplication.shared.applicationState == .active
        if active, let selection {
            var essentials = FamilyActivitySelection()
            essentials.applicationTokens = selection.applicationTokens
            essentials.webDomainTokens = selection.webDomainTokens
            ProtectionState.selection = essentials
            ProtectionState.enforce()
        }
        pickerController?.dismiss(animated: active)
        pickerController = nil
        result(ProtectionState.status())
    }

}

@available(iOS 16.0, *)
private struct EssentialsPicker: View {
    let russian: Bool
    @State var selection: FamilyActivitySelection
    let done: (FamilyActivitySelection?) -> Void
    var body: some View {
        NavigationView {
            VStack {
                Text(russian ? "Выбирайте отдельные приложения и сайты. Системные исключения определяет iOS." : "Choose individual apps and websites. iOS controls system exemptions.")
                    .font(.footnote).padding()
                FamilyActivityPicker(selection: $selection)
            }
            .navigationTitle(russian ? "Доступны всегда" : "Always available")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(russian ? "Отмена" : "Cancel") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button(russian ? "Сохранить" : "Save") { done(selection) } }
            }
        }
    }
}
