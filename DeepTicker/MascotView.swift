import SwiftUI

struct ZigzagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let segments = 4
        let segmentWidth = width / CGFloat(segments)
        path.move(to: CGPoint(x: 0, y: height / 2))
        for i in 0..<segments {
            let x = CGFloat(i + 1) * segmentWidth
            let y = i % 2 == 0 ? height * 0.2 : height * 0.8
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

struct MascotView: View {
    let overallHealth: StockHealthStatus
    @State private var isAnimating = false
    @State private var eyeScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Main body (zigzag shape)
            mascotBody
            
            // Eye
            mascotEye
            
            // Arrow tail
            mascotArrowTail
            
            // Motion lines for urgency
            if overallHealth == .danger {
                motionLines
            }
        }
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .offset(y: bounceOffset)
        .onAppear {
            startAnimations()
        }
        .onChange(of: overallHealth) { _, _ in
            triggerHealthChangeAnimation()
        }
    }
    
    private var mascotBody: some View {
        // Zigzag-shaped body resembling a stock chart
        ZStack {
            // Base body shape
            RoundedRectangle(cornerRadius: 20)
                .fill(healthGradient)
                .frame(width: 80, height: 60)
            
            // Zigzag pattern overlay
            ZigzagShape()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 60, height: 40)
        }
    }
    
    private var mascotEye: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .fill(eyeColor)
                    .frame(width: 12, height: 12)
                    .scaleEffect(eyeScale)
            )
            .offset(x: 10, y: -10)
    }
    
    private var mascotArrowTail: some View {
        // Arrow pointing upward for growth
        Image(systemName: "arrow.up.right")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Color.white.opacity(0.8))
            .offset(x: -25, y: 15)
            .rotationEffect(.degrees(isAnimating ? 10 : -10))
    }
    
    private var motionLines: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: isAnimating ? 15 : 8, height: 2)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.1), value: isAnimating)
            }
        }
        .offset(x: 50, y: 0)
    }
    
    private var healthGradient: LinearGradient {
        switch overallHealth {
        case .stable:
            return LinearGradient(colors: [Color.green.opacity(0.8), Color.green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warning:
            return LinearGradient(colors: [Color.orange.opacity(0.8), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .danger:
            return LinearGradient(colors: [Color.red.opacity(0.8), Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var eyeColor: Color {
        switch overallHealth {
        case .stable:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
    
    private func startAnimations() {
        // Gentle breathing animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
        
        // Eye blinking
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            eyeScale = 0.8
        }
        
        // Bounce animation for danger state
        if overallHealth == .danger {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                bounceOffset = -5
            }
        }
    }
    
    private func triggerHealthChangeAnimation() {
        // Reset animations
        withAnimation(.easeInOut(duration: 0.3)) {
            bounceOffset = 0
            eyeScale = 1.2
        }
        
        // Restart appropriate animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startAnimations()
        }
    }
}

struct MascotView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            MascotView(overallHealth: .stable)
            MascotView(overallHealth: .warning)
            MascotView(overallHealth: .danger)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
