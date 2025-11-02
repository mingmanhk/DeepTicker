import SwiftUI

// MARK: - Liquid Glass Extensions

/// Glass effect modifiers for implementing Liquid Glass design
extension View {
    
    /// Applies a glass effect to the view
    /// - Parameters:
    ///   - glass: The glass configuration to apply
    ///   - shape: The shape to apply the glass effect to
    /// - Returns: A view with the glass effect applied
    func glassEffect(_ glass: Glass = .regular, in shape: some InsettableShape = .capsule) -> some View {
        self.background {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    if glass.isInteractive {
                        shape
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
                }
                .opacity(glass.opacity)
                .foregroundStyle(glass.tintColor ?? .primary)
        }
    }
    
    /// Associates a glass effect with an identifier for morphing animations
    /// - Parameters:
    ///   - id: The identifier for this glass effect
    ///   - namespace: The namespace for morphing animations
    /// - Returns: A view with the glass effect identifier
    func glassEffectID<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }
    
    /// Unites multiple glass effects into a single effect
    /// - Parameters:
    ///   - id: The union identifier
    ///   - namespace: The namespace for union effects
    /// - Returns: A view with the glass effect union
    func glassEffectUnion<ID: Hashable>(_ id: ID, namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }
}

// MARK: - Glass Configuration

/// Configuration for glass effects
struct Glass {
    let opacity: Double
    let tintColor: Color?
    let isInteractive: Bool
    
    private init(opacity: Double = 1.0, tintColor: Color? = nil, isInteractive: Bool = false) {
        self.opacity = opacity
        self.tintColor = tintColor
        self.isInteractive = isInteractive
    }
    
    /// Regular glass effect
    static let regular = Glass()
    
    /// Adds a tint color to the glass effect
    /// - Parameter color: The tint color to apply
    /// - Returns: A glass configuration with the tint applied
    func tint(_ color: Color) -> Glass {
        Glass(opacity: self.opacity, tintColor: color, isInteractive: self.isInteractive)
    }
    
    /// Makes the glass effect interactive
    /// - Parameter interactive: Whether the glass should be interactive
    /// - Returns: A glass configuration with interactivity
    func interactive(_ interactive: Bool = true) -> Glass {
        Glass(opacity: self.opacity, tintColor: self.tintColor, isInteractive: interactive)
    }
    
    /// Sets the opacity of the glass effect
    /// - Parameter opacity: The opacity value (0.0 to 1.0)
    /// - Returns: A glass configuration with the specified opacity
    func opacity(_ opacity: Double) -> Glass {
        Glass(opacity: opacity, tintColor: self.tintColor, isInteractive: self.isInteractive)
    }
}

// MARK: - Button Styles

extension ButtonStyle where Self == GlassButtonStyle {
    /// A button style that applies a glass effect
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    
    /// A prominent glass button style with accent color tint
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}

struct GlassButtonStyle: ButtonStyle {
    let isProminent: Bool
    
    init(isProminent: Bool = false) {
        self.isProminent = isProminent
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if isProminent {
                    Capsule()
                        .fill(.thinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                        }
                        .foregroundStyle(Color.accentColor)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Glass Effect Container

// Provide a factory helper instead of attempting to assign stored properties in an extension
extension GlassEffectContainer {
    /// Creates a glass effect container with custom styling (spacing + content)
    /// Use this when your `GlassEffectContainer` initializer does not take an alignment parameter.
    static func make(spacing: CGFloat = 16,
                     @ViewBuilder content: @escaping () -> Content) -> Self {
        // Calls through to `init(spacing:content:)` if available.
        Self.init(spacing: spacing, content: content)
    }

    /// Creates a glass effect container with custom styling (spacing + alignment + content)
    /// If your `GlassEffectContainer` doesn't support `alignment`, consider ignoring it or updating the initializer.
    static func make(spacing: CGFloat = 16,
                     alignment: HorizontalAlignment = .center,
                     @ViewBuilder content: @escaping () -> Content) -> Self {
        // Your GlassEffectContainer doesn't expose an initializer with alignment.
        // Fallback to the spacing-only initializer and ignore `alignment`.
        return Self.init(spacing: spacing, content: content)
    }
}

// MARK: - Shape Extensions for Glass Effects

extension InsettableShape where Self == Capsule {
    /// A capsule shape for glass effects
    static var capsule: Capsule { Capsule() }
}

extension InsettableShape where Self == Circle {
    /// A circle shape for glass effects
    static var circle: Circle { Circle() }
}

extension InsettableShape where Self == RoundedRectangle {
    /// A rounded rectangle shape for glass effects
    /// - Parameter cornerRadius: The corner radius of the rectangle
    /// - Returns: A rounded rectangle shape
    static func rect(cornerRadius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }
}
