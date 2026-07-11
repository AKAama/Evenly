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
                }
        }
    }
}
