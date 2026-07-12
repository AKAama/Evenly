//
//  DeepLinkRouter.swift
//  Evenly
//
//  Universal Links + custom scheme routing for ledger QR invites.
//

import Foundation
import Combine

enum DeepLinkRoute: Equatable {
    case joinLedger(token: String)
}

/// Captures incoming URLs (scheme + Universal Links) so ContentView can process
/// them after auth session restore on cold start.
@MainActor
final class DeepLinkInbox: ObservableObject {
    static let shared = DeepLinkInbox()

    /// Latest unconsumed invite token from a deep link.
    @Published private(set) var pendingJoinToken: String?

    private init() {}

    func handle(url: URL) {
        print("[DeepLink] incoming \(url.absoluteString)")
        guard let route = DeepLinkRouter.parse(url) else {
            print("[DeepLink] unhandled url")
            return
        }
        switch route {
        case .joinLedger(let token):
            print("[DeepLink] join token=\(token.prefix(8))…")
            pendingJoinToken = token
            DeepLinkRouter.storePendingJoinToken(token)
        }
    }

    func handle(userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handle(url: url)
    }

    func clearPendingJoinToken() {
        pendingJoinToken = nil
        DeepLinkRouter.storePendingJoinToken(nil)
    }

    /// Restore any token persisted across process death / before ContentView mounted.
    func restorePersistedIfNeeded() {
        if pendingJoinToken == nil, let stored = DeepLinkRouter.loadPendingJoinToken() {
            pendingJoinToken = stored
        }
    }
}

enum DeepLinkRouter {
    /// Landing site host used for Universal Links (must match Associated Domains).
    static let inviteHost = "app.ismyh.cn"
    static let customScheme = "evenly"

    private static let pendingJoinTokenKey = "evenly.pendingJoinToken"

    static func parse(_ url: URL) -> DeepLinkRoute? {
        let pathParts = url.pathComponents.filter { $0 != "/" }

        // evenly://join/{token}  → host=join, path=/token
        // evenly:///join/{token} → host empty, path=/join/token
        if let scheme = url.scheme?.lowercased(), scheme == customScheme {
            if url.host?.lowercased() == "join" {
                if let token = pathParts.first, !token.isEmpty {
                    return .joinLedger(token: token)
                }
            }
            if pathParts.count >= 2, pathParts[0].lowercased() == "join", !pathParts[1].isEmpty {
                return .joinLedger(token: pathParts[1])
            }
            return nil
        }

        // https://app.ismyh.cn/join/{token}
        guard let host = url.host?.lowercased() else { return nil }
        let allowedHosts = [inviteHost, "www.\(inviteHost)"]
        guard allowedHosts.contains(host) else { return nil }

        if pathParts.count >= 2, pathParts[0] == "join", !pathParts[1].isEmpty {
            return .joinLedger(token: pathParts[1])
        }
        return nil
    }

    static func storePendingJoinToken(_ token: String?) {
        if let token, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: pendingJoinTokenKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pendingJoinTokenKey)
        }
    }

    static func loadPendingJoinToken() -> String? {
        UserDefaults.standard.string(forKey: pendingJoinTokenKey)
    }

    /// Compatibility accessors used by older call sites / tests.
    static var pendingJoinToken: String? {
        get { loadPendingJoinToken() }
        set { storePendingJoinToken(newValue) }
    }
}
