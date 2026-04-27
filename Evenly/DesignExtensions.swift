//
//  DesignExtensions.swift
//  Evenly
//
//  Modern design extensions: animations, haptics, blur effects, accessibility
//

import SwiftUI

// MARK: - Haptic Feedback Manager
struct HapticManager {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let medium = UIImpactFeedbackGenerator(style: .medium)
    static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    static let soft = UIImpactFeedbackGenerator(style: .soft)
    static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    static let notification = UINotificationFeedbackGenerator()
    static let selection = UISelectionFeedbackGenerator()
    
    static func prepare() {
        [light, medium, heavy, soft, rigid, notification, selection].forEach { $0.prepare() }
    }
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
    }
}

// MARK: - Spring Animation Modifiers
struct SpringAnimationModifier: ViewModifier {
    let response: Double
    let dampingFraction: Double
    let blendDuration: Double
    
    init(response: Double = 0.5, dampingFraction: Double = 0.7, blendDuration: Double = 0) {
        self.response = response
        self.dampingFraction = dampingFraction
        self.blendDuration = blendDuration
    }
    
    func body(content: Content) -> some View {
        content
            .animation(.spring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration), value: UUID())
    }
}

extension View {
    func springAnimation(response: Double = 0.5, dampingFraction: Double = 0.7) -> some View {
        self.modifier(SpringAnimationModifier(response: response, dampingFraction: dampingFraction))
    }
}

// MARK: - Button Style with Haptics
struct SpringButtonStyle: ButtonStyle {
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    
    init(hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.impact(hapticStyle)
                }
            }
    }
}

extension ButtonStyle where Self == SpringButtonStyle {
    static var spring: SpringButtonStyle { SpringButtonStyle() }
    static func spring(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> SpringButtonStyle {
        SpringButtonStyle(hapticStyle: style)
    }
}

// MARK: - Scale on Press
struct ScaleOnPress: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.impact(.light)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func scaleOnPress() -> some View {
        modifier(ScaleOnPress())
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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
