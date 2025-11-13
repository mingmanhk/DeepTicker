import SwiftUI

/// A celebratory view shown after successful Pro purchase
struct PurchaseSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var confettiCounter = 0
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = -180
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 32) {
                // Success icon with animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .yellow.opacity(0.5), radius: 20)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(rotation))
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                VStack(spacing: 12) {
                    Text("Welcome to Pro! 🎉")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .opacity(opacity)
                    
                    Text("You now have access to all premium features")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(opacity)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    SuccessFeatureRow(icon: "brain.head.profile", text: "Advanced AI Providers")
                    SuccessFeatureRow(icon: "doc.text.fill", text: "Custom Prompts")
                    SuccessFeatureRow(icon: "sparkles", text: "All Future Features")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .opacity(opacity)
                
                Button {
                    dismiss()
                } label: {
                    Text("Start Using Pro")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .opacity(opacity)
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(24)
            .padding(32)
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                rotation = 0
            }
            
            // Trigger confetti animation
            confettiCounter += 1
        }
    }
}

struct SuccessFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    PurchaseSuccessView()
}
