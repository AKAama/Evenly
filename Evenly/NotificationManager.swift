import Foundation
import Combine
import UIKit
import UserNotifications

enum NotificationDestination: Equatable {
    case ledger(UUID)
    case invitations

    nonisolated init?(userInfo: [AnyHashable: Any]) {
        guard let event = userInfo["event"] as? String else { return nil }
        if event == "ledger.invited" {
            self = .invitations
            return
        }
        guard event.hasPrefix("expense."),
              let ledgerID = userInfo["ledger_id"] as? String,
              let uuid = UUID(uuidString: ledgerID) else { return nil }
        self = .ledger(uuid)
    }
}

private struct PushDeviceRequest: Encodable {
    let environment: String
    let bundleId: String

    enum CodingKeys: String, CodingKey {
        case environment
        case bundleId = "bundle_id"
    }
}

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var pendingDestination: NotificationDestination?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let api = APIClient.shared
    private let tokenKey = "APNs_Device_Token"

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated static func hexToken(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = (await center.notificationSettings()).authorizationStatus
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            await register(token: token)
        }
    }

    func receivedDeviceToken(_ data: Data) {
        let token = Self.hexToken(data)
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await register(token: token) }
    }

    func unregisterCurrentDevice() async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey), api.currentToken != nil else { return }
        try? await api.delete(APIEndpoints.pushDevice(token: token))
    }

    func consumeDestination() {
        pendingDestination = nil
    }

    private func register(token: String) async {
        guard api.currentToken != nil else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let request = PushDeviceRequest(
            environment: environment,
            bundleId: Bundle.main.bundleIdentifier ?? "com.yhma.Evenly"
        )
        let _: EmptyResponse? = try? await api.put(APIEndpoints.pushDevice(token: token), body: request)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let destination = NotificationDestination(userInfo: response.notification.request.content.userInfo)
        await MainActor.run { self.pendingDestination = destination }
    }
}

final class EvenlyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in NotificationManager.shared.receivedDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }
}
