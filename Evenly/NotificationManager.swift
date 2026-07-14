import Foundation
import Combine
import UIKit
import UserNotifications

enum NotificationDestination: Equatable, Sendable {
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
    /// Bumped whenever a remote notification is delivered (foreground banner or tap).
    /// Views observe this to refresh invites/ledgers without waiting for relaunch.
    @Published private(set) var remoteRefreshTick: UInt = 0
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
            do {
                _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                print("Notification authorization request failed: \(error.localizedDescription)")
            }
            authorizationStatus = (await center.notificationSettings()).authorizationStatus
        }
        guard authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral else {
            print("Notifications not authorized (status=\(authorizationStatus.rawValue)); skipping APNs register")
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            await register(token: token)
        }
    }

    func receivedDeviceToken(_ data: Data) {
        let token = Self.hexToken(data)
        UserDefaults.standard.set(token, forKey: tokenKey)
        print("APNs device token received (\(token.prefix(12))…)")
        Task { await register(token: token) }
    }

    func unregisterCurrentDevice() async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey), api.currentToken != nil else { return }
        do {
            try await api.delete(APIEndpoints.pushDevice(token: token))
        } catch {
            print("Failed to unregister push device: \(error.localizedDescription)")
        }
    }

    func consumeDestination() {
        pendingDestination = nil
    }

    /// Called for both foreground delivery and user taps so in-app state stays fresh.
    func handleRemoteNotification(userInfo: [AnyHashable: Any], openedByUser: Bool) {
        handleRemoteNotification(
            destination: NotificationDestination(userInfo: userInfo),
            openedByUser: openedByUser
        )
    }

    func handleRemoteNotification(destination: NotificationDestination?, openedByUser: Bool) {
        remoteRefreshTick &+= 1
        if openedByUser {
            pendingDestination = destination
        } else if destination == .invitations {
            // Foreground invite: still surface the in-app banner via data refresh;
            // pendingDestination is reserved for navigation on explicit taps.
        }
    }

    private func register(token: String) async {
        guard api.currentToken != nil else {
            print("Skipping push device register: not authenticated")
            return
        }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let request = PushDeviceRequest(
            environment: environment,
            bundleId: Bundle.main.bundleIdentifier ?? "com.yhma.Evenly"
        )
        do {
            let _: EmptyResponse = try await api.put(APIEndpoints.pushDevice(token: token), body: request)
            print("Push device registered environment=\(environment)")
        } catch {
            print("Failed to register push device: \(error.localizedDescription)")
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Parse on this nonisolated context; only hop a Sendable destination to MainActor.
        let destination = NotificationDestination(userInfo: notification.request.content.userInfo)
        await MainActor.run {
            self.handleRemoteNotification(destination: destination, openedByUser: false)
        }
        return [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let destination = NotificationDestination(userInfo: response.notification.request.content.userInfo)
        await MainActor.run {
            self.handleRemoteNotification(destination: destination, openedByUser: true)
        }
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

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            NotificationManager.shared.handleRemoteNotification(userInfo: userInfo, openedByUser: false)
            completionHandler(.newData)
        }
    }
}
