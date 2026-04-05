import AppKit
import QuartzCore

enum PanelAnimationTiming: Sendable {
    nonisolated(unsafe) static let smoothEaseOut = CAMediaTimingFunction(controlPoints: 0.0, 0.0, 0.2, 1.0)
    nonisolated(unsafe) static let smoothEaseInEaseOut = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
    nonisolated(unsafe) static let anticipateOvershoot = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.1)
    nonisolated(unsafe) static let gentleSpring = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
    nonisolated(unsafe) static let quickEaseOut = CAMediaTimingFunction(controlPoints: 0.0, 0.0, 0.15, 1.0)
    nonisolated(unsafe) static let systemEaseOut = CAMediaTimingFunction(name: .easeOut)
}

struct SpringAnimationConfig {
    var mass: CGFloat
    var stiffness: CGFloat
    var damping: CGFloat
    var initialVelocity: CGFloat

    static let gentleBounce = SpringAnimationConfig(
        mass: 1.0,
        stiffness: 180,
        damping: 18,
        initialVelocity: 0
    )

    static let snappy = SpringAnimationConfig(
        mass: 1.0,
        stiffness: 300,
        damping: 28,
        initialVelocity: 0
    )

    static let smooth = SpringAnimationConfig(
        mass: 1.0,
        stiffness: 200,
        damping: 22,
        initialVelocity: 0
    )

    static let panelOpen = SpringAnimationConfig(
        mass: 1.2,
        stiffness: 220,
        damping: 20,
        initialVelocity: 0
    )

    static let panelDismiss = SpringAnimationConfig(
        mass: 1.0,
        stiffness: 280,
        damping: 26,
        initialVelocity: 0
    )
}

extension CALayer {
    func animatePosition(
        from: CGPoint,
        to: CGPoint,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSValue(point: from)
        animation.toValue = NSValue(point: to)
        animation.duration = duration
        animation.timingFunction = timingFunction
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        if let completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            add(animation, forKey: "position")
            CATransaction.commit()
        } else {
            add(animation, forKey: "position")
        }
    }

    func animatePositionSpring(
        from: CGPoint,
        to: CGPoint,
        config: SpringAnimationConfig,
        completion: (() -> Void)? = nil
    ) {
        let animation = CASpringAnimation(keyPath: "position")
        animation.fromValue = NSValue(point: from)
        animation.toValue = NSValue(point: to)
        animation.mass = config.mass
        animation.stiffness = config.stiffness
        animation.damping = config.damping
        animation.initialVelocity = config.initialVelocity
        animation.duration = animation.settlingDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        if let completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            add(animation, forKey: "position")
            CATransaction.commit()
        } else {
            add(animation, forKey: "position")
        }
    }

    func animateBounds(
        from: CGRect,
        to: CGRect,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        let animation = CABasicAnimation(keyPath: "bounds")
        animation.fromValue = NSValue(rect: from)
        animation.toValue = NSValue(rect: to)
        animation.duration = duration
        animation.timingFunction = timingFunction
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        if let completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            add(animation, forKey: "bounds")
            CATransaction.commit()
        } else {
            add(animation, forKey: "bounds")
        }
    }

    func animateBoundsSpring(
        from: CGRect,
        to: CGRect,
        config: SpringAnimationConfig,
        completion: (() -> Void)? = nil
    ) {
        let animation = CASpringAnimation(keyPath: "bounds")
        animation.fromValue = NSValue(rect: from)
        animation.toValue = NSValue(rect: to)
        animation.mass = config.mass
        animation.stiffness = config.stiffness
        animation.damping = config.damping
        animation.initialVelocity = config.initialVelocity
        animation.duration = animation.settlingDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        if let completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            add(animation, forKey: "bounds")
            CATransaction.commit()
        } else {
            add(animation, forKey: "bounds")
        }
    }

    func animateOpacity(
        from: CGFloat,
        to: CGFloat,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = timingFunction
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        if let completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            add(animation, forKey: "opacity")
            CATransaction.commit()
        } else {
            add(animation, forKey: "opacity")
        }
    }
}

extension NSView {
    func animateFrame(
        to frame: NSRect,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        guard let layer else {
            self.frame = frame
            completion?()
            return
        }

        let fromBounds = bounds
        let toBounds = NSRect(origin: .zero, size: frame.size)
        let fromPosition = CGPoint(x: frame.midX, y: frame.midY)
        let toPosition = CGPoint(x: frame.midX, y: frame.midY)

        layer.position = toPosition
        layer.bounds = toBounds

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let boundsAnimation = CABasicAnimation(keyPath: "bounds")
        boundsAnimation.fromValue = NSValue(rect: fromBounds)
        boundsAnimation.toValue = NSValue(rect: toBounds)
        boundsAnimation.duration = duration
        boundsAnimation.timingFunction = timingFunction

        if let completion {
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        layer.add(boundsAnimation, forKey: "bounds")
        CATransaction.commit()
    }

    func animateFrameSpring(
        to frame: NSRect,
        config: SpringAnimationConfig,
        completion: (() -> Void)? = nil
    ) {
        guard let layer else {
            self.frame = frame
            completion?()
            return
        }

        let fromBounds = bounds
        let toBounds = NSRect(origin: .zero, size: frame.size)
        let fromPosition = layer.position
        let toPosition = CGPoint(x: frame.midX, y: frame.midY)

        layer.position = toPosition
        layer.bounds = toBounds

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let boundsAnimation = CASpringAnimation(keyPath: "bounds")
        boundsAnimation.fromValue = NSValue(rect: fromBounds)
        boundsAnimation.toValue = NSValue(rect: toBounds)
        boundsAnimation.mass = config.mass
        boundsAnimation.stiffness = config.stiffness
        boundsAnimation.damping = config.damping
        boundsAnimation.initialVelocity = config.initialVelocity
        boundsAnimation.duration = boundsAnimation.settlingDuration

        if let completion {
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        layer.add(boundsAnimation, forKey: "bounds")
        CATransaction.commit()
    }

    func animateOrigin(
        to origin: NSPoint,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        guard let layer else {
            setFrameOrigin(origin)
            completion?()
            return
        }

        let fromPosition = layer.position
        let toPosition = CGPoint(x: origin.x + bounds.width / 2, y: origin.y + bounds.height / 2)

        layer.position = toPosition

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let positionAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(point: fromPosition)
        positionAnimation.toValue = NSValue(point: toPosition)
        positionAnimation.duration = duration
        positionAnimation.timingFunction = timingFunction

        if let completion {
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        layer.add(positionAnimation, forKey: "position")
        CATransaction.commit()
    }

    func animateOriginSpring(
        to origin: NSPoint,
        config: SpringAnimationConfig,
        completion: (() -> Void)? = nil
    ) {
        guard let layer else {
            setFrameOrigin(origin)
            completion?()
            return
        }

        let fromPosition = layer.position
        let toPosition = CGPoint(x: origin.x + bounds.width / 2, y: origin.y + bounds.height / 2)

        layer.position = toPosition

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let positionAnimation = CASpringAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(point: fromPosition)
        positionAnimation.toValue = NSValue(point: toPosition)
        positionAnimation.mass = config.mass
        positionAnimation.stiffness = config.stiffness
        positionAnimation.damping = config.damping
        positionAnimation.initialVelocity = config.initialVelocity
        positionAnimation.duration = positionAnimation.settlingDuration

        if let completion {
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        layer.add(positionAnimation, forKey: "position")
        CATransaction.commit()
    }
}

extension NSWindow {
    func animateFrame(
        to frame: NSRect,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        display: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let fromFrame = self.frame

        setFrame(frame, display: display)

        guard let contentView = contentView, let layer = contentView.layer else {
            completion?()
            return
        }

        let fromLayerPosition = CGPoint(
            x: fromFrame.origin.x + fromFrame.width / 2,
            y: fromFrame.origin.y + fromFrame.height / 2
        )
        let toLayerPosition = CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2
        )

        let fromLayerBounds = CGRect(origin: .zero, size: fromFrame.size)
        let toLayerBounds = CGRect(origin: .zero, size: frame.size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let positionAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(point: fromLayerPosition)
        positionAnimation.toValue = NSValue(point: toLayerPosition)
        positionAnimation.duration = duration
        positionAnimation.timingFunction = timingFunction

        let boundsAnimation = CABasicAnimation(keyPath: "bounds")
        boundsAnimation.fromValue = NSValue(rect: fromLayerBounds)
        boundsAnimation.toValue = NSValue(rect: toLayerBounds)
        boundsAnimation.duration = duration
        boundsAnimation.timingFunction = timingFunction

        if let completion {
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        layer.add(positionAnimation, forKey: "windowPosition")
        layer.add(boundsAnimation, forKey: "windowBounds")
        CATransaction.commit()
    }

    func animateFrameSpring(
        to frame: NSRect,
        config: SpringAnimationConfig,
        display: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let fromFrame = self.frame

        setFrame(frame, display: display)

        guard let contentView = contentView, let layer = contentView.layer else {
            completion?()
            return
        }

        let fromLayerPosition = CGPoint(
            x: fromFrame.origin.x + fromFrame.width / 2,
            y: fromFrame.origin.y + fromFrame.height / 2
        )
        let toLayerPosition = CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2
        )

        let fromLayerBounds = CGRect(origin: .zero, size: fromFrame.size)
        let toLayerBounds = CGRect(origin: .zero, size: frame.size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let positionAnimation = CASpringAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(point: fromLayerPosition)
        positionAnimation.toValue = NSValue(point: toLayerPosition)
        positionAnimation.mass = config.mass
        positionAnimation.stiffness = config.stiffness
        positionAnimation.damping = config.damping
        positionAnimation.initialVelocity = config.initialVelocity
        positionAnimation.duration = positionAnimation.settlingDuration

        let boundsAnimation = CASpringAnimation(keyPath: "bounds")
        boundsAnimation.fromValue = NSValue(rect: fromLayerBounds)
        boundsAnimation.toValue = NSValue(rect: toLayerBounds)
        boundsAnimation.mass = config.mass
        boundsAnimation.stiffness = config.stiffness
        boundsAnimation.damping = config.damping
        boundsAnimation.initialVelocity = config.initialVelocity
        boundsAnimation.duration = boundsAnimation.settlingDuration

        if let completion {
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        layer.add(positionAnimation, forKey: "windowPositionSpring")
        layer.add(boundsAnimation, forKey: "windowBoundsSpring")
        CATransaction.commit()
    }
}
