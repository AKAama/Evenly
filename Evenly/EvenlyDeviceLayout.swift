//
//  EvenlyDeviceLayout.swift
//  Evenly
//
//  Device / size-class helpers. Phone layouts stay default;
//  iPad-only shells opt in via `isPadIdiom` so compact iPhone is untouched.
//

import SwiftUI
import UIKit

enum EvenlyDeviceLayout {
    /// True only on iPad (and iPad apps running as designed-for-iPad).
    /// Do **not** use regular width alone — iPhone Pro Max landscape is regular.
    static var isPadIdiom: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Prefer this for adaptive chrome that should also help large iPhones later.
    static func isRegularWidth(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular
    }

    /// Readable content width for forms / login on large canvases.
    static let formMaxWidth: CGFloat = 440

    /// Detail column comfort width before it stretches too thin/wide.
    static let detailComfortMaxWidth: CGFloat = 720

    /// Sidebar column ideal width for ledger list.
    static let sidebarIdealWidth: CGFloat = 300
}

/// Marks views that should only affect iPad presentation.
/// Phone continues to use the existing `TabView` shell.
struct EvenlyPadOnly<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if EvenlyDeviceLayout.isPadIdiom {
            content()
        }
    }
}
