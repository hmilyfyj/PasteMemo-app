import SwiftUI

struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    @ObservedObject var preferences = AnimationPreferences.shared
    
    let scale: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    
    init(
        scale: CGFloat = 1.02,
        shadowRadius: CGFloat = 8,
        shadowOpacity: Double = 0.15
    ) {
        self.scale = scale
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? shadowOpacity : shadowOpacity / 3),
                radius: isHovered ? shadowRadius : shadowRadius / 2
            )
            .animation(preferences.enableMicroInteractions ? preferences.currentSpring : .none, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct PressEffect: ViewModifier {
    @State private var isPressed = false
    @ObservedObject var preferences = AnimationPreferences.shared
    
    let scale: CGFloat
    
    init(scale: CGFloat = 0.98) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(preferences.enableMicroInteractions ? .easeInOut(duration: 0.1) : .none, value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

struct InteractiveCard: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false
    @ObservedObject var preferences = AnimationPreferences.shared
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 8 : 4
            )
            .animation(preferences.enableMicroInteractions ? preferences.currentSpring : .none, value: isHovered)
            .animation(preferences.enableMicroInteractions ? .easeInOut(duration: 0.1) : .none, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

struct ScaleOnTap: ViewModifier {
    @State private var isPressed = false
    let scale: CGFloat
    
    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isPressed = true
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

struct BounceOnAppear: ViewModifier {
    @State private var hasAppeared = false
    @ObservedObject var preferences = AnimationPreferences.shared
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared ? 1.0 : 0.8)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .onAppear {
                if preferences.enableTransitions {
                    withAnimation(preferences.currentSpring) {
                        hasAppeared = true
                    }
                } else {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    func hoverEffect(
        scale: CGFloat = 1.02,
        shadowRadius: CGFloat = 8,
        shadowOpacity: Double = 0.15
    ) -> some View {
        self.modifier(HoverEffect(scale: scale, shadowRadius: shadowRadius, shadowOpacity: shadowOpacity))
    }
    
    func pressEffect(scale: CGFloat = 0.98) -> some View {
        self.modifier(PressEffect(scale: scale))
    }
    
    func interactiveCard() -> some View {
        self.modifier(InteractiveCard())
    }
    
    func scaleOnTap(scale: CGFloat = 0.95) -> some View {
        self.modifier(ScaleOnTap(scale: scale))
    }
    
    func bounceOnAppear() -> some View {
        self.modifier(BounceOnAppear())
    }
}
