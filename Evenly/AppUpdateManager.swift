import Foundation
import Combine

struct IOSUpdateRelease: Decodable, Equatable {
    let latestVersion: String
    let message: String
    let appStoreURL: String
    let remindAfterDays: Int

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case message
        case appStoreURL = "app_store_url"
        case remindAfterDays = "remind_after_days"
    }

    // Accept only the configured Evenly destination, never an arbitrary server URL.
    static let storeURL = URL(string: "https://apps.apple.com/cn/app/evenly/id6784235151")!
}

@MainActor
final class AppUpdateManager: ObservableObject {
    @Published private(set) var pendingRelease: IOSUpdateRelease?
    private let defaults: UserDefaults
    private let currentVersion: String
    private let fetchRelease: () async throws -> IOSUpdateRelease
    private let now: () -> Date
    private var lastAttempt: Date?
    private var retryInterval: TimeInterval = 0
    private var isChecking = false
    private var cachedRelease: IOSUpdateRelease?

    init(
        defaults: UserDefaults = .standard,
        currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        now: @escaping () -> Date = Date.init,
        fetchRelease: @escaping () async throws -> IOSUpdateRelease = {
            try await APIClient.shared.get(APIEndpoints.iosUpdate, requiresAuth: false)
        }
    ) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.now = now
        self.fetchRelease = fetchRelease
    }

    static func isNewer(_ candidate: String, than installed: String) -> Bool {
        func components(_ version: String) -> [Int]? {
            let parts = version.split(separator: ".", omittingEmptySubsequences: false)
            guard (1...3).contains(parts.count) else { return nil }
            var values: [Int] = []
            for part in parts {
                guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                      let value = Int(part) else { return nil }
                values.append(value)
            }
            return values + Array(repeating: 0, count: 3 - values.count)
        }
        guard let next = components(candidate), let current = components(installed) else { return false }
        return current.lexicographicallyPrecedes(next)
    }

    func checkIfNeeded() async {
        guard !isChecking else { return }
        if let lastAttempt, now().timeIntervalSince(lastAttempt) < retryInterval {
            offer(cachedRelease)
            return
        }
        isChecking = true
        lastAttempt = now()
        defer { isChecking = false }
        do {
            let release = try await fetchRelease()
            cachedRelease = release
            retryInterval = 6 * 60 * 60
            offer(release)
        } catch {
            // Offline or an older backend must never interrupt normal app usage.
            retryInterval = 15 * 60
        }
    }

    func snooze() {
        guard let release = pendingRelease else { return }
        let days = min(max(release.remindAfterDays, 1), 30)
        defaults.set(now().addingTimeInterval(TimeInterval(days) * 24 * 60 * 60),
                     forKey: snoozeKey(release.latestVersion))
        pendingRelease = nil
    }

    private func offer(_ release: IOSUpdateRelease?) {
        guard let release,
              release.appStoreURL == IOSUpdateRelease.storeURL.absoluteString,
              Self.isNewer(release.latestVersion, than: currentVersion) else {
            pendingRelease = nil
            return
        }
        if let until = defaults.object(forKey: snoozeKey(release.latestVersion)) as? Date, now() < until {
            pendingRelease = nil
            return
        }
        pendingRelease = release
    }

    private func snoozeKey(_ version: String) -> String {
        "evenly.update.snoozedUntil.\(version)"
    }
}
