import SwiftUI

struct SmoothTransitionModifier: ViewModifier {
    let id: AnyHashable
    @ObservedObject var preferences = AnimationPreferences.shared
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 1.1).combined(with: .opacity)
            ))
            .id(id)
    }
}

struct TypeSwitchTransition: ViewModifier {
    let contentType: ClipContentType
    @ObservedObject var preferences = AnimationPreferences.shared
    
    func body(content: Content) -> some View {
        if preferences.enableTransitions {
            content
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 1.05).combined(with: .opacity)
                ))
                .animation(preferences.currentSpring, value: contentType)
        } else {
            content
        }
    }
}

struct StaggeredListAnimation: ViewModifier {
    let index: Int
    @State private var isVisible = false
    @ObservedObject var preferences = AnimationPreferences.shared
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                if preferences.enableTransitions {
                    let delay = Double(index) * 0.05
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(preferences.currentSpring) {
                            isVisible = true
                        }
                    }
                } else {
                    isVisible = true
                }
            }
    }
}

struct FadeSlideTransition: ViewModifier {
    let direction: TransitionDirection
    @State private var isVisible = false
    @ObservedObject var preferences = AnimationPreferences.shared
    
    enum TransitionDirection {
        case left
        case right
        case up
        case down
        
        var offset: CGSize {
            switch self {
            case .left: return CGSize(width: -20, height: 0)
            case .right: return CGSize(width: 20, height: 0)
            case .up: return CGSize(width: 0, height: -20)
            case .down: return CGSize(width: 0, height: 20)
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(isVisible ? .zero : direction.offset)
            .onAppear {
                if preferences.enableTransitions {
                    withAnimation(preferences.currentSpring) {
                        isVisible = true
                    }
                } else {
                    isVisible = true
                }
            }
    }
}

struct PanelExpandAnimation: ViewModifier {
    let isExpanded: Bool
    @ObservedObject var preferences = AnimationPreferences.shared
    
    func body(content: Content) -> some View {
        content
            .frame(maxHeight: isExpanded ? .infinity : 0)
            .opacity(isExpanded ? 1.0 : 0.0)
            .clipped()
            .animation(preferences.enableTransitions ? preferences.currentSpring : .none, value: isExpanded)
    }
}

struct ScaleTransition: ViewModifier {
    let isActive: Bool
    let scale: CGFloat
    @ObservedObject var preferences = AnimationPreferences.shared
    
    init(isActive: Bool, scale: CGFloat = 0.95) {
        self.isActive = isActive
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? scale : 1.0)
            .animation(preferences.enableTransitions ? .easeInOut(duration: 0.2) : .none, value: isActive)
    }
}

extension View {
    func smoothTransition(id: AnyHashable) -> some View {
        self.modifier(SmoothTransitionModifier(id: id))
    }
    
    func typeSwitchTransition(contentType: ClipContentType) -> some View {
        self.modifier(TypeSwitchTransition(contentType: contentType))
    }
    
    func staggeredAnimation(index: Int) -> some View {
        self.modifier(StaggeredListAnimation(index: index))
    }
    
    func fadeSlideTransition(direction: FadeSlideTransition.TransitionDirection) -> some View {
        self.modifier(FadeSlideTransition(direction: direction))
    }
    
    func panelExpandAnimation(isExpanded: Bool) -> some View {
        self.modifier(PanelExpandAnimation(isExpanded: isExpanded))
    }
    
    func scaleTransition(isActive: Bool, scale: CGFloat = 0.95) -> some View {
        self.modifier(ScaleTransition(isActive: isActive, scale: scale))
    }
}

extension AnyTransition {
    static var smoothScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndOpacity: AnyTransition {
        .scale.combined(with: .opacity)
    }
}
