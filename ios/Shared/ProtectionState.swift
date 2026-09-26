#if !WITHOUT_SCREEN_TIME
import Foundation
import FamilyControls
import ManagedSettings

/// Shared by Runner and the DeviceActivityMonitor extension.
@available(iOS 16.0, *)
enum ProtectionState {
    static let group = Bundle.main.object(forInfoDictionaryKey: "LittlewinsAppGroup") as? String ?? "group.com.example.readapp"
    static var defaults: UserDefaults { UserDefaults(suiteName: group)! }
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("littlewins"))
    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: "essentials"),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                return FamilyActivitySelection()
            }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "essentials") }
    }
    private struct AccessReceipt: Codable {
        let transactionId: String
        let endsAt: Date
    }
    private static var receiptURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("access-receipt.json")
    }
    private static var receipt: AccessReceipt? {
        guard let url = receiptURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AccessReceipt.self, from: data)
    }
    static var expiry: Date { receipt?.endsAt ?? Date(timeIntervalSince1970: 0) }
    static var transactionId: String? { receipt?.transactionId }
    static func saveReceipt(transactionId: String, endsAt: Date) throws {
        guard let url = receiptURL else {
            throw NSError(domain: "Littlewins", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group access is unavailable."])
        }
        let data = try JSONEncoder().encode(AccessReceipt(transactionId: transactionId, endsAt: endsAt))
        // Receipt and deadline become visible together, including across process crashes.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    static var authorized: Bool { AuthorizationCenter.shared.authorizationStatus == .approved && defaults.bool(forKey: "enabled") }

    static func enforce() {
        guard authorized, defaults.bool(forKey: "enabled") else { return }
        store.dateAndTime.requireAutomaticDateAndTime = true
        if expiry > Date() {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .all(except: selection.applicationTokens)
            store.shield.webDomainCategories = .all(except: selection.webDomainTokens)
        }
    }

    static func status() -> [String: Any] {
        enforce()
        var result: [String: Any] = ["supported": true, "authorized": authorized,
            "essentialsCount": selection.applicationTokens.count + selection.webDomainTokens.count,
            "endsAt": Int64(expiry.timeIntervalSince1970 * 1000)]
        if let transactionId { result["transactionId"] = transactionId }
        return result
    }
}
#endif
