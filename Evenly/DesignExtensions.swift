//
//  DesignExtensions.swift
//  Evenly
//
//  Modern design extensions: animations, haptics, blur effects, accessibility
//

import SwiftUI

// MARK: - Evenly Visual Language
enum EvenlyStyle {
    static let brandBlue = Color(red: 0.12, green: 0.48, blue: 0.96)
    static let brandBlueHero = Color(red: 0.10, green: 0.38, blue: 0.78)
    static let brandBlueAccent = Color(red: 0.35, green: 0.57, blue: 0.93)
    static let brandBlueSoft = Color(red: 0.83, green: 0.89, blue: 0.98)
    static let brandBlueDeep = Color(red: 0.11, green: 0.22, blue: 0.38)
    static let blue = brandBlue
    static let indigo = Color(red: 0.31, green: 0.25, blue: 0.88)
    static let cyan = Color(red: 0.10, green: 0.72, blue: 0.82)

    static let brandGradient = LinearGradient(
        colors: [brandBlue, indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softBackground = LinearGradient(
        colors: [brandBlue.opacity(0.12), indigo.opacity(0.06), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func brandBlueSoft(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? brandBlueDeep : brandBlueSoft
    }

    static func brandBlueGlow(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.8)
            : brandBlueSoft.opacity(0.48)
    }

    static func selectedBlueFill(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.25, blue: 0.42)
            : brandBlueSoft.opacity(0.62)
    }

    static func avatarBlueFill(_ colorScheme: ColorScheme, selected: Bool) -> Color {
        if colorScheme == .dark {
            return selected ? Color(red: 0.18, green: 0.34, blue: 0.55) : Color(red: 0.16, green: 0.28, blue: 0.45)
        }
        return brandBlueSoft.opacity(selected ? 0.95 : 0.55)
    }
}

struct ElevatedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.65), lineWidth: 0.75)
            }
            .shadow(color: EvenlyStyle.indigo.opacity(0.09), radius: 18, y: 8)
    }
}

extension View {
    func evenlyCard() -> some View {
        modifier(ElevatedCardModifier())
    }
}

// MARK: - Apple-style Motion Tokens
/// Springs aligned with Apple's fluid-interface guidance (WWDC Designing Fluid Interfaces).
/// Prefer critically damped motion for routine UI; reserve bounce for momentum gestures.
enum EvenlyMotion {
    /// Default UI motion — no overshoot (damping ≈ 1.0).
    static var ui: Animation { .spring(response: 0.35, dampingFraction: 1.0) }
    /// Snappy press feedback (~100–160ms feel).
    static var press: Animation { .spring(response: 0.18, dampingFraction: 0.92) }
    /// Sheet / drawer settle with a hint of physicality.
    static var sheet: Animation { .spring(response: 0.32, dampingFraction: 0.86) }
    /// Momentum / flick release (slight bounce only when gesture carried velocity).
    static var momentum: Animation { .spring(response: 0.30, dampingFraction: 0.82) }
    /// List / layout appearance.
    static var appear: Animation { .spring(response: 0.40, dampingFraction: 0.92) }

    static func preferReducedMotion(_ reduce: Bool) -> Animation {
        reduce ? .easeOut(duration: 0.15) : ui
    }
}

// MARK: - Haptic Feedback Manager (UIKit Core Haptics path)
/// Reuses prepared generators so feedback fires on touch-down with minimal latency.
/// Respects system Reduce Motion: keeps short utility haptics, skips decorative ones.
@MainActor
enum HapticManager {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let medium = UIImpactFeedbackGenerator(style: .medium)
    static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    static let soft = UIImpactFeedbackGenerator(style: .soft)
    static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    static let notification = UINotificationFeedbackGenerator()
    static let selection = UISelectionFeedbackGenerator()

    /// True when the device can play haptics (iPhone with Taptic Engine).
    static var isSupported: Bool {
        // All modern iPhones support UIKit haptics; simulators silently no-op.
        true
    }

    private static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        soft.prepare()
        rigid.prepare()
        notification.prepare()
        selection.prepare()
    }

    private static func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light: return light
        case .medium: return medium
        case .heavy: return heavy
        case .soft: return soft
        case .rigid: return rigid
        @unknown default: return medium
        }
    }

    /// Touch-down impact. Intensity 0…1 maps to Apple's impact intensity API.
    static func impact(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        intensity: CGFloat = 1.0
    ) {
        let gen = generator(for: style)
        gen.prepare()
        let clamped = min(max(intensity, 0), 1)
        if clamped >= 0.999 {
            gen.impactOccurred()
        } else {
            gen.impactOccurred(intensity: clamped)
        }
    }

    /// Subtle press used by buttons (light + soft intensity).
    static func press() {
        impact(.soft, intensity: 0.7)
    }

    /// Selection scrub / chip change.
    static func selectionChanged() {
        selection.prepare()
        selection.selectionChanged()
    }

    /// Success / error / warning for completed actions.
    static func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        // Keep outcome haptics even with Reduce Motion — they signal utility, not decoration.
        notification.prepare()
        notification.notificationOccurred(type)
    }

    /// Decorative motion haptic — skipped when Reduce Motion is on.
    static func decorativeImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard !prefersReducedMotion else { return }
        impact(style, intensity: 0.55)
    }
}

// MARK: - Spring Animation Modifiers
struct SpringAnimationModifier: ViewModifier {
    let response: Double
    let dampingFraction: Double
    let blendDuration: Double

    init(response: Double = 0.35, dampingFraction: Double = 1.0, blendDuration: Double = 0) {
        self.response = response
        self.dampingFraction = dampingFraction
        self.blendDuration = blendDuration
    }

    func body(content: Content) -> some View {
        content
            .animation(
                .spring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration),
                value: UUID()
            )
    }
}

extension View {
    func springAnimation(response: Double = 0.35, dampingFraction: Double = 1.0) -> some View {
        self.modifier(SpringAnimationModifier(response: response, dampingFraction: dampingFraction))
    }
}

// MARK: - Button Style with Haptics (press-down, Apple-scale ~0.97)
struct SpringButtonStyle: ButtonStyle {
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    var scale: CGFloat = 0.97
    var intensity: CGFloat = 0.75

    init(
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .soft,
        scale: CGFloat = 0.97,
        intensity: CGFloat = 0.75
    ) {
        self.hapticStyle = hapticStyle
        self.scale = scale
        self.intensity = intensity
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(EvenlyMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                // Fire on touch-down (not release) so feedback feels direct.
                if isPressed {
                    HapticManager.impact(hapticStyle, intensity: intensity)
                }
            }
    }
}

extension ButtonStyle where Self == SpringButtonStyle {
    static var spring: SpringButtonStyle { SpringButtonStyle() }
    static func spring(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> SpringButtonStyle {
        SpringButtonStyle(hapticStyle: style)
    }
    /// Primary CTAs (保存 / 确认) — slightly firmer.
    static var springPrimary: SpringButtonStyle {
        SpringButtonStyle(hapticStyle: .medium, scale: 0.97, intensity: 0.85)
    }
    /// Destructive / 拒绝.
    static var springRigid: SpringButtonStyle {
        SpringButtonStyle(hapticStyle: .rigid, scale: 0.97, intensity: 0.8)
    }
}

// MARK: - Scale on Press (for non-Button labels / rows)
struct ScaleOnPress: ViewModifier {
    var haptic: Bool = true
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(EvenlyMotion.press, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        if haptic {
                            HapticManager.press()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func scaleOnPress(haptic: Bool = true) -> some View {
        modifier(ScaleOnPress(haptic: haptic))
    }

    /// iOS 17+ sensory feedback layered on top of UIKit haptics for system-native feel.
    @ViewBuilder
    func evenlyPressFeedback(trigger: some Equatable) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: trigger)
        } else {
            self
        }
    }
}

// MARK: - Blur and Material Effects
struct GlassBackground: ViewModifier {
    let material: Material
    let cornerRadius: CGFloat
    
    init(material: Material = .ultraThinMaterial, cornerRadius: CGFloat = 16) {
        self.material = material
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
    
    func materialBackground(_ material: Material) -> some View {
        self.background(material)
    }
}

// MARK: - Gradient Backgrounds
struct GradientBackground: ViewModifier {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    init(colors: [Color] = [.blue.opacity(0.1), .purple.opacity(0.1)], 
         startPoint: UnitPoint = .topLeading,
         endPoint: UnitPoint = .bottomTrailing) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
    }
}

extension View {
    func gradientBackground(_ colors: [Color] = [.blue.opacity(0.1), .purple.opacity(0.1)]) -> some View {
        modifier(GradientBackground(colors: colors))
    }
}

// MARK: - Shadow Styles
struct CardShadow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    init(color: Color = .black.opacity(0.1), radius: CGFloat = 8, x: CGFloat = 0, y: CGFloat = 4) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadow())
    }
    
    func elevatedShadow() -> some View {
        modifier(CardShadow(radius: 16, y: 8))
    }
}

// MARK: - Context Menu
extension View {
    func contextMenu<T: Identifiable>(_ items: [T], @ViewBuilder content: @escaping (T) -> some View) -> some View {
        self.contextMenu {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

// MARK: - Pull to Refresh (using native SwiftUI)

// MARK: - Reduced Motion Support
struct ReducedMotionModifier: ViewModifier {
    let animation: Animation
    let value: Bool
    
    func body(content: Content) -> some View {
        content
            .animation(value ? animation : .default, value: value)
    }
}

extension View {
    func respectReducedMotion(_ respect: Bool = true) -> some View {
        self.animation(respect ? .easeInOut(duration: 0.3) : .spring(), value: respect)
    }
}

// MARK: - Dynamic Type Support
struct AccessibleFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    
    init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        self.size = size
        self.weight = weight
        self.design = design
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: design))
            .dynamicTypeSize(.accessibility2)
    }
}

extension View {
    func accessibleFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(AccessibleFont(size: size, weight: weight))
    }
}

// MARK: - List Row Animation
struct ListRowAnimation: ViewModifier {
    @State private var appears = false
    
    func body(content: Content) -> some View {
        content
            .opacity(appears ? 1 : 0)
            .offset(y: appears ? 0 : 10)
            .onAppear {
                withAnimation(EvenlyMotion.appear) {
                    appears = true
                }
            }
    }
}

extension View {
    func listRowAnimation() -> some View {
        modifier(ListRowAnimation())
    }
}

// MARK: - Transition Extensions
extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .slide.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        )
    }
    
    static var moveAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Swipe Action with Haptic
struct SwipeActionHaptic: ViewModifier {
    let role: ButtonRole?
    let icon: String
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: role == .destructive) {
                Button(role: role) {
                    HapticManager.notificationOccurred(.warning)
                    action()
                } label: {
                    Label("删除", systemImage: icon)
                }
            }
    }
}

extension View {
    func swipeActionWithHaptic(role: ButtonRole? = nil, icon: String = "trash", action: @escaping () -> Void) -> some View {
        modifier(SwipeActionHaptic(role: role, icon: icon, action: action))
    }
}

// MARK: - Confirmation Dialog
struct ConfirmationDialogModifier<T: StringProtocol>: ViewModifier {
    @Binding var isPresented: Bool
    let title: T
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let destructive: Bool
    let onConfirm: () -> Void
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(confirmTitle, role: destructive ? .destructive : nil) {
                    HapticManager.notificationOccurred(.warning)
                    onConfirm()
                }
                Button(cancelTitle, role: .cancel) {}
            } message: {
                if let message = message {
                    Text(message)
                }
            }
    }
}

extension View {
    func confirmationDialog<T: StringProtocol>(
        _ title: T,
        isPresented: Binding<Bool>,
        message: String? = nil,
        confirmTitle: String = "确认",
        cancelTitle: String = "取消",
        destructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmationDialogModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            destructive: destructive,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Searchable Modifier
extension View {
    @ViewBuilder
    func searchableWithAnimation(
        _ text: Binding<String>,
        placement: SearchFieldPlacement = .toolbar,
        prompt: String
    ) -> some View {
        self.searchable(text: text, placement: placement, prompt: prompt)
    }
}

// MARK: - Task Modifier for Async
struct TaskModifier: ViewModifier {
    let action: @Sendable () async -> Void
    
    @State private var task: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                task = Task {
                    await action()
                }
            }
            .onDisappear {
                task?.cancel()
            }
    }
}

extension View {
    func taskWithPriority(action: @escaping @Sendable () async -> Void) -> some View {
        modifier(TaskModifier(action: action))
    }
}

// MARK: - Animated List
struct AnimatedList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
            content(item)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
        }
    }
}
