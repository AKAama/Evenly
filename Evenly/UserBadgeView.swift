//
//  UserBadgeView.swift
//  Evenly
//
//  Rectangular nameplate badges with metallic shine (like enamel pins).
//

import SwiftUI
import UIKit

struct UserBadgeChip: View {
    let key: String?
    var label: String? = nil
    var colorName: String? = nil
    /// Compact for list rows; slightly larger for profile.
    var size: BadgeSize = .compact

    enum BadgeSize {
        case compact
        case regular

        var font: Font {
            switch self {
            case .compact: return .system(size: 10, weight: .heavy, design: .rounded)
            case .regular: return .system(size: 11, weight: .heavy, design: .rounded)
            }
        }

        var hPad: CGFloat { self == .compact ? 7 : 9 }
        var vPad: CGFloat { self == .compact ? 3 : 4 }
        var corner: CGFloat { self == .compact ? 4 : 5 }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shinePhase: CGFloat = -0.35

    private var resolvedLabel: String? {
        if let label, !label.isEmpty { return label }
        switch key?.lowercased() {
        case "founder": return "创始人"
        case "crew": return "船员"
        case "mate": return "搭子"
        case "beta": return "内测官"
        case "vip": return "特邀"
        default: return key
        }
    }

    private var base: Color {
        Self.color(from: colorName) ?? Self.fallbackColor(for: key)
    }

    var body: some View {
        if let text = resolvedLabel, key != nil || label != nil {
            Text(text)
                .font(size.font)
                .foregroundStyle(textGradient)
                .padding(.horizontal, size.hPad)
                .padding(.vertical, size.vPad)
                .background { badgePlate }
                .clipShape(RoundedRectangle(cornerRadius: size.corner, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                        .strokeBorder(borderGradient, lineWidth: 1)
                }
                .shadow(color: base.opacity(0.35), radius: 2, y: 1)
                .accessibilityLabel("铭牌 \(text)")
                .onAppear { startShineIfNeeded() }
        }
    }

    // MARK: - Plate (metal body + optional texture + moving sheen)

    private var badgePlate: some View {
        ZStack {
            // Body — slightly metallic multi-stop gradient
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(metalBody)

            // Soft procedural “brushed metal” stripes
            GeometryReader { geo in
                let w = geo.size.width
                Path { path in
                    var x: CGFloat = 0
                    while x < w + 20 {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - 6, y: geo.size.height))
                        x += 3.5
                    }
                }
                .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
            }
            .allowsHitTesting(false)

            // Specular top edge
            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.softLight)

            // Moving diagonal shine
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.white.opacity(0.0), location: 0.35),
                        .init(color: Color.white.opacity(0.75), location: 0.5),
                        .init(color: Color.white.opacity(0.0), location: 0.65),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: w * 0.42)
                .rotationEffect(.degrees(18))
                .offset(x: shinePhase * w * 1.6)
                .blendMode(.screen)
                .opacity(reduceMotion ? 0.25 : 0.55)
            }
            .allowsHitTesting(false)
            .clipped()
        }
    }

    private var metalBody: LinearGradient {
        LinearGradient(
            colors: [
                base.mix(with: .white, amount: 0.35),
                base,
                base.mix(with: .black, amount: 0.28),
                base.mix(with: .white, amount: 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var textGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                Color.white.opacity(0.88),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.75),
                base.mix(with: .white, amount: 0.2).opacity(0.9),
                base.mix(with: .black, amount: 0.35).opacity(0.85),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func startShineIfNeeded() {
        guard !reduceMotion else {
            shinePhase = 0.15
            return
        }
        shinePhase = -0.4
        withAnimation(
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: false)
            .delay(Double.random(in: 0...0.8))
        ) {
            shinePhase = 1.15
        }
    }

    // MARK: - Color mapping

    static func color(from name: String?) -> Color? {
        guard var name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        // Accept #RGB / #RRGGBB / RRGGBB
        if name.hasPrefix("#") {
            if name.count == 4 { // #RGB → #RRGGBB
                let r = name[name.index(name.startIndex, offsetBy: 1)]
                let g = name[name.index(name.startIndex, offsetBy: 2)]
                let b = name[name.index(name.startIndex, offsetBy: 3)]
                name = "#\(r)\(r)\(g)\(g)\(b)\(b)"
            }
            if name.count == 7 { return Color(hex: name) }
        } else if name.count == 6, name.range(of: #"^[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil {
            return Color(hex: "#\(name)")
        }
        switch name.lowercased() {
        case "gold": return Color(red: 0.82, green: 0.62, blue: 0.18)
        case "blue", "geekblue": return EvenlyStyle.brandBlue
        case "orange", "volcano": return Color(red: 0.92, green: 0.48, blue: 0.12)
        case "purple": return Color(red: 0.55, green: 0.32, blue: 0.82)
        case "magenta", "pink": return Color(red: 0.78, green: 0.28, blue: 0.52)
        case "red": return Color(red: 0.85, green: 0.22, blue: 0.22)
        case "green", "lime": return Color(red: 0.22, green: 0.68, blue: 0.38)
        case "cyan": return Color(red: 0.12, green: 0.68, blue: 0.78)
        default: return nil
        }
    }

    static func fallbackColor(for key: String?) -> Color {
        switch key?.lowercased() {
        case "founder": return Color(red: 0.82, green: 0.62, blue: 0.18)
        case "crew": return EvenlyStyle.brandBlue
        case "mate": return Color(red: 0.92, green: 0.48, blue: 0.12)
        case "beta": return Color(red: 0.55, green: 0.32, blue: 0.82)
        case "vip": return Color(red: 0.78, green: 0.28, blue: 0.52)
        default: return EvenlyStyle.brandBlue
        }
    }
}

// MARK: - Helpers

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// Rough mix toward another color in sRGB (good enough for badge tints).
    func mix(with other: Color, amount: CGFloat) -> Color {
        let ui = UIColor(self)
        let ou = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ou.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = max(0, min(1, amount))
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t),
            opacity: Double(a1 + (a2 - a1) * t)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        UserBadgeChip(key: "founder", label: "创始人", colorName: "gold")
        UserBadgeChip(key: "crew", label: "船员", colorName: "blue")
        UserBadgeChip(key: "mate", label: "搭子", colorName: "orange", size: .regular)
        UserBadgeChip(key: "vip", label: "特邀", colorName: "magenta")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
