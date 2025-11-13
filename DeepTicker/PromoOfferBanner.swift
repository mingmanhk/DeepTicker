import SwiftUI

/// Shows a promotional banner for limited-time offers
struct PromoOfferBanner: View {
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    let offerEndDate: Date
    let discount: String
    
    init(offerEndDate: Date, discount: String = "50% OFF") {
        self.offerEndDate = offerEndDate
        self.discount = discount
    }
    
    var body: some View {
        if Date() < offerEndDate {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch Special: \(discount)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text("Ends in \(timeRemainingString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.yellow.opacity(0.2), .orange.opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.yellow.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(12)
            .onAppear {
                updateTimeRemaining()
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    updateTimeRemaining()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    private func updateTimeRemaining() {
        timeRemaining = max(0, offerEndDate.timeIntervalSince(Date()))
    }
    
    private var timeRemainingString: String {
        let days = Int(timeRemaining) / 86400
        let hours = (Int(timeRemaining) % 86400) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    VStack {
        PromoOfferBanner(
            offerEndDate: Date().addingTimeInterval(172800), // 2 days from now
            discount: "50% OFF"
        )
        .padding()
    }
}
