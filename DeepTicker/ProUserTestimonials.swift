import SwiftUI

/// Social proof component to increase trust and conversions
struct ProUserTestimonials: View {
    let testimonials: [Testimonial] = [
        Testimonial(
            name: "Sarah M.",
            role: "Long-term Investor",
            rating: 5,
            quote: "The multi-AI analysis in Pro is game-changing. I compare insights from different models before making decisions.",
            proFeature: "Advanced AI Providers"
        ),
        Testimonial(
            name: "James T.",
            role: "Day Trader",
            rating: 5,
            quote: "Custom prompts let me focus on what matters for my strategy. Worth every penny.",
            proFeature: "Custom Prompts"
        ),
        Testimonial(
            name: "Maria L.",
            role: "Portfolio Manager",
            rating: 5,
            quote: "Best investment app purchase I've made. The one-time payment model is refreshing.",
            proFeature: "One-time Purchase"
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                
                Text("What Pro Users Say")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(testimonials) { testimonial in
                        TestimonialCard(testimonial: testimonial)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct TestimonialCard: View {
    let testimonial: Testimonial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Rating
            HStack(spacing: 4) {
                ForEach(0..<testimonial.rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            
            // Quote
            Text(testimonial.quote)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Pro Feature Highlight
            HStack(spacing: 6) {
                Image(systemName: "star.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                
                Text(testimonial.proFeature)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.orange.opacity(0.1))
            .cornerRadius(8)
            
            // Author
            VStack(alignment: .leading, spacing: 2) {
                Text(testimonial.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(testimonial.role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280, height: 220)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

struct Testimonial: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let rating: Int
    let quote: String
    let proFeature: String
}

// Alternative: Stats-based social proof
struct ProUserStats: View {
    var body: some View {
        HStack(spacing: 0) {
            StatItem(
                value: "10K+",
                label: "Pro Users",
                icon: "person.3.fill"
            )
            
            Divider()
                .frame(height: 40)
            
            StatItem(
                value: "4.8★",
                label: "Rating",
                icon: "star.fill"
            )
            
            Divider()
                .frame(height: 40)
            
            StatItem(
                value: "95%",
                label: "Satisfaction",
                icon: "hand.thumbsup.fill"
            )
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Simple trust badge
struct TrustBadges: View {
    var body: some View {
        HStack(spacing: 20) {
            TrustBadge(
                icon: "lock.shield.fill",
                text: "Secure Payment",
                color: .green
            )
            
            TrustBadge(
                icon: "arrow.clockwise.circle.fill",
                text: "Money-Back Guarantee",
                color: .blue
            )
            
            TrustBadge(
                icon: "infinity.circle.fill",
                text: "Lifetime Access",
                color: .purple
            )
        }
        .padding()
    }
}

struct TrustBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Testimonials") {
    ScrollView {
        VStack(spacing: 32) {
            ProUserTestimonials()
            
            ProUserStats()
                .padding()
            
            TrustBadges()
        }
    }
}
