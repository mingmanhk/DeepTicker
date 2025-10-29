import SwiftUI

struct MascotView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                // Mascot Character
                mascotCharacter
                    .scaleEffect(pulseScale)
                    .offset(x: shakeOffset)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        startAnimations()
                    }
                    .onChange(of: portfolioHealth.color) { _ in
                        updateAnimationsForHealth()
                    }
                
                Spacer()
                
                // Health Status Text
                VStack(spacing: 12) {
                    Text(healthStatusMessage)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(healthStatusTextColor)
                    
                    Text(detailedStatusMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                actionButtons
            }
            .navigationTitle("DeepTicker Mascot")
            .navigationBarTitleDisplayMode(.large)
            .background(
                RadialGradient(
                    colors: [mascotBackgroundColor.opacity(0.3), Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 300
                )
            )
        }
    }
    
    // MARK: - Computed Properties
    private var portfolioHealth: HealthStatus {
        return portfolioManager.getPortfolioStats().overallHealth
    }
    
    private var mascotBackgroundColor: Color {
        switch portfolioHealth {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
    
    private var healthStatusTextColor: Color {
        switch portfolioHealth {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
    
    private var healthStatusMessage: String {
        switch portfolioHealth {
        case .healthy:
            return "Portfolio Looking Great! 📈"
        case .warning:
            return "Portfolio Needs Attention ⚠️"
        case .danger:
            return "Portfolio in Danger Zone! 🚨"
        }
    }
    
    private var detailedStatusMessage: String {
        let stats = portfolioManager.getPortfolioStats()
        
        switch portfolioHealth {
        case .healthy:
            return "Your portfolio is performing well with \(stats.healthyCount) healthy stocks. Keep up the good work!"
        case .warning:
            return "You have \(stats.warningCount) stocks showing warning signs. Consider reviewing your positions."
        case .danger:
            return "You have \(stats.dangerCount) stocks in the danger zone. Immediate attention recommended!"
        }
    }
    
    // MARK: - Views
    private var mascotCharacter: some View {
        ZStack {
            // Main body (zigzag shape)
            ZigzagShape()
                .fill(
                    LinearGradient(
                        colors: [mascotBackgroundColor, mascotBackgroundColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 140)
                .shadow(color: mascotBackgroundColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Eye
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 15, height: 15)
                        .offset(x: eyeOffset.x, y: eyeOffset.y)
                )
                .offset(x: -10, y: -20)
            
            // Arrow tail (pointing up)
            ArrowTailShape()
                .fill(mascotBackgroundColor)
                .frame(width: 20, height: 40)
                .offset(x: 0, y: 90)
            
            // Motion lines (for urgency)
            if portfolioHealth == .danger {
                motionLines
            }
        }
        .frame(width: 160, height: 200)
    }
    
    private var eyeOffset: CGPoint {
        switch portfolioHealth {
        case .healthy:
            return CGPoint(x: 2, y: 0) // Looking slightly right (optimistic)
        case .warning:
            return CGPoint(x: 0, y: 0) // Looking straight (neutral)
        case .danger:
            return CGPoint(x: -2, y: 2) // Looking down-left (worried)
        }
    }
    
    private var motionLines: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                HStack {
                    ForEach(0..<3, id: \.self) { lineIndex in
                        Rectangle()
                            .fill(mascotBackgroundColor.opacity(0.6))
                            .frame(width: 15, height: 2)
                            .offset(x: CGFloat(lineIndex * 5))
                    }
                }
                .offset(x: CGFloat(index * 10 - 10))
            }
        }
        .offset(x: 80, y: 0)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                Task {
                    await portfolioManager.refreshAllStocks()
                }
            }) {
                VStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                    Text("Refresh")
                        .font(.caption)
                }
            }
            .disabled(portfolioManager.isLoading)
            
            Button(action: {
                Task {
                    await portfolioManager.generateAllPredictions()
                }
            }) {
                VStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                    Text("Predict")
                        .font(.caption)
                }
            }
            .disabled(portfolioManager.isLoading)
            
            Button(action: {
                // Trigger haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Animate mascot
                withAnimation(.easeInOut(duration: 0.5)) {
                    pulseScale = 1.2
                }
                withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                    pulseScale = 1.0
                }
            }) {
                VStack {
                    Image(systemName: "hand.wave.fill")
                        .font(.title2)
                    Text("Wave Hi")
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.bordered)
        .padding()
    }
    
    // MARK: - Private Methods
    private func startAnimations() {
        updateAnimationsForHealth()
        isAnimating = true
    }
    
    private func updateAnimationsForHealth() {
        switch portfolioHealth {
        case .healthy:
            // Gentle pulse animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
            shakeOffset = 0
            
        case .warning:
            // Moderate pulse
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
            shakeOffset = 0
            
        case .danger:
            // Shake animation
            pulseScale = 1.0
            withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                shakeOffset = 3
            }
        }
    }
}

// MARK: - Custom Shapes
struct ZigzagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let zigzagHeight: CGFloat = 20
        
        // Start at top-left with some rounding
        path.move(to: CGPoint(x: 10, y: 0))
        
        // Top edge with zigzag
        path.addLine(to: CGPoint(x: width * 0.3, y: 0))
        path.addLine(to: CGPoint(x: width * 0.4, y: zigzagHeight))
        path.addLine(to: CGPoint(x: width * 0.6, y: 0))
        path.addLine(to: CGPoint(x: width - 10, y: 0))
        
        // Right edge (rounded corner)
        path.addQuadCurve(to: CGPoint(x: width, y: 10), control: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height - 10))
        
        // Bottom-right (rounded corner)
        path.addQuadCurve(to: CGPoint(x: width - 10, y: height), control: CGPoint(x: width, y: height))
        
        // Bottom edge with inverse zigzag
        path.addLine(to: CGPoint(x: width * 0.7, y: height))
        path.addLine(to: CGPoint(x: width * 0.6, y: height - zigzagHeight))
        path.addLine(to: CGPoint(x: width * 0.4, y: height))
        path.addLine(to: CGPoint(x: 10, y: height))
        
        // Left edge (rounded corners)
        path.addQuadCurve(to: CGPoint(x: 0, y: height - 10), control: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 0, y: 0))
        
        return path
    }
}

struct ArrowTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Arrow pointing up
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.3))
        path.addLine(to: CGPoint(x: width * 0.65, y: height * 0.3))
        path.addLine(to: CGPoint(x: width * 0.65, y: height))
        path.addLine(to: CGPoint(x: width * 0.35, y: height))
        path.addLine(to: CGPoint(x: width * 0.35, y: height * 0.3))
        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.3))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    MascotView()
        .environmentObject(PortfolioManager())
}