import SwiftUI
import Foundation

enum AnimationStyle: String, CaseIterable, Codable {
    case smooth = "smooth"
    case snappy = "snappy"
    case gentle = "gentle"
    case minimal = "minimal"
    
    var displayName: String {
        switch self {
        case .smooth: return "平滑"
        case .snappy: return "快速"
        case .gentle: return "柔和"
        case .minimal: return "极简"
        }
    }
    
    var springConfig: SpringAnimationConfig {
        switch self {
        case .smooth:
            return SpringAnimationConfig(
                mass: 1.0,
                stiffness: 200,
                damping: 22,
                initialVelocity: 0
            )
        case .snappy:
            return SpringAnimationConfig(
                mass: 1.0,
                stiffness: 300,
                damping: 28,
                initialVelocity: 0
            )
        case .gentle:
            return SpringAnimationConfig(
                mass: 1.0,
                stiffness: 180,
                damping: 18,
                initialVelocity: 0
            )
        case .minimal:
            return SpringAnimationConfig(
                mass: 1.0,
                stiffness: 400,
                damping: 30,
                initialVelocity: 0
            )
        }
    }
    
    var swiftUISpring: Animation {
        let config = springConfig
        return .spring(
            response: 0.5,
            dampingFraction: Double(config.damping) / Double(config.stiffness) * 2,
            blendDuration: 0
        )
    }
}

@MainActor
class AnimationPreferences: ObservableObject {
    static let shared = AnimationPreferences()
    
    private let styleKey = "animationStyle"
    private let enableMicroInteractionsKey = "enableMicroInteractions"
    private let enableTransitionsKey = "enableTransitions"
    private let animationSpeedKey = "animationSpeed"
    
    @Published var style: AnimationStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: styleKey)
        }
    }
    
    @Published var enableMicroInteractions: Bool {
        didSet {
            UserDefaults.standard.set(enableMicroInteractions, forKey: enableMicroInteractionsKey)
        }
    }
    
    @Published var enableTransitions: Bool {
        didSet {
            UserDefaults.standard.set(enableTransitions, forKey: enableTransitionsKey)
        }
    }
    
    @Published var animationSpeed: Double {
        didSet {
            UserDefaults.standard.set(animationSpeed, forKey: animationSpeedKey)
        }
    }
    
    private init() {
        self.style = AnimationStyle(rawValue: UserDefaults.standard.string(forKey: styleKey) ?? "") ?? .smooth
        self.enableMicroInteractions = UserDefaults.standard.object(forKey: enableMicroInteractionsKey) as? Bool ?? true
        self.enableTransitions = UserDefaults.standard.object(forKey: enableTransitionsKey) as? Bool ?? true
        self.animationSpeed = UserDefaults.standard.double(forKey: animationSpeedKey)
        
        if self.animationSpeed == 0 {
            self.animationSpeed = 1.0
        }
    }
    
    var currentSpring: Animation {
        style.swiftUISpring
    }
    
    func adjustedDuration(_ duration: TimeInterval) -> TimeInterval {
        duration / animationSpeed
    }
}
