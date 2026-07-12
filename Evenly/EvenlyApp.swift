//
//  EvenlyApp.swift
//  Evenly
//
//  App entry point
//

import SwiftUI

@main
struct EvenlyApp: App {
    @UIApplicationDelegateAdaptor(EvenlyAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Warm Taptic Engine generators so first press feels instant.
                    HapticManager.prepare()
                    DeepLinkInbox.shared.restorePersistedIfNeeded()
                }
                // Custom scheme (evenly://) and many Universal Link deliveries.
                .onOpenURL { url in
                    DeepLinkInbox.shared.handle(url: url)
                }
                // Universal Links often arrive as browsing user activities, not onOpenURL.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    DeepLinkInbox.shared.handle(userActivity: activity)
                }
        }
    }
}
