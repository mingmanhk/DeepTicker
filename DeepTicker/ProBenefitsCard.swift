import SwiftUI

/// Simple visual card showing what users get with Pro
/// Can be used in multiple contexts
struct ProBenefitsCard: View {
    let style: CardStyle
    
    enum CardStyle {
        case compact    // For inline display
        case expanded   // For dedicated screens
        case minimal    // For tooltips/popovers
    }
    
    var body: some View {
        switch style {
        case .compact:
            CompactBenefitsCard()
        case .expanded:
            ExpandedBenefitsCard()
        case .minimal:
            MinimalBenefitsCard()
        }
    }
}

// MARK: - Compact Style

struct CompactBenefitsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)
                
                Text("Pro Benefits")
                    .font(.headline)
                
                Spacer()
            }
            
            // Benefits Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                BenefitChip(icon: "brain.head.profile", text: "5+ AI Models")
                BenefitChip(icon: "doc.text", text: "Custom Prompts")
                BenefitChip(icon: "key", text: "Own API Keys")
                BenefitChip(icon: "infinity", text: "Lifetime Access")
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

struct BenefitChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Expanded Style

struct ExpandedBenefitsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with gradient
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Features")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Everything you need to succeed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Detailed benefits
            VStack(alignment: .leading, spacing: 16) {
                DetailedBenefit(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: "Multiple AI Providers",
                    description: "Compare insights from OpenAI, Claude, Gemini, and more"
                )
                
                DetailedBenefit(
                    icon: "doc.text.fill",
                    color: .blue,
                    title: "Custom Prompts",
                    description: "Tailor AI analysis to your investment strategy"
                )
                
                DetailedBenefit(
                    icon: "key.fill",
                    color: .green,
                    title: "Use Your Own API Keys",
                    description: "Bring your own keys for maximum control and savings"
                )
                
                DetailedBenefit(
                    icon: "infinity.circle.fill",
                    color: .orange,
                    title: "Lifetime Access",
                    description: "Pay once, get all future Pro features forever"
                )
            }
            
            // Value prop
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                
                Text("One-time purchase • No subscription")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}

struct DetailedBenefit: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Minimal Style

struct MinimalBenefitsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                
                Text("Unlock Pro")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                MinimalBenefit(icon: "brain.head.profile", text: "5+ AI Models")
                MinimalBenefit(icon: "doc.text", text: "Custom Prompts")
                MinimalBenefit(icon: "infinity", text: "Lifetime Updates")
            }
            
            Text("One-time purchase")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
    }
}

struct MinimalBenefit: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Usage Examples

struct ProBenefitsCardExamples: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Example 1: In a list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compact Style - Great for Lists")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ProBenefitsCard(style: .compact)
                        .padding(.horizontal)
                }
                
                Divider()
                
                // Example 2: Dedicated screen
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expanded Style - For Upgrade Screens")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ProBenefitsCard(style: .expanded)
                        .padding(.horizontal)
                }
                
                Divider()
                
                // Example 3: Popover
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimal Style - For Popovers")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ProBenefitsCard(style: .minimal)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Integration Examples

/*
 HOW TO USE:
 
 1. In Settings List:
 ```
 List {
     Section {
         ProBenefitsCard(style: .compact)
             .listRowInsets(EdgeInsets())
             .listRowBackground(Color.clear)
     }
 }
 ```
 
 2. In Upgrade Sheet:
 ```
 ScrollView {
     VStack(spacing: 24) {
         // Your header...
         
         ProBenefitsCard(style: .expanded)
         
         // Purchase button...
     }
 }
 ```
 
 3. As Popover:
 ```
 Button("Learn More") { }
     .popover(isPresented: $showInfo) {
         ProBenefitsCard(style: .minimal)
             .padding()
             .presentationCompactAdaptation(.popover)
     }
 ```
 
 4. In Feature Gate:
 ```
 VStack {
     Text("This feature requires Pro")
     
     ProBenefitsCard(style: .minimal)
     
     Button("Upgrade") { }
 }
 ```
*/

#Preview("All Styles") {
    ProBenefitsCardExamples()
}

#Preview("Compact") {
    ProBenefitsCard(style: .compact)
        .padding()
}

#Preview("Expanded") {
    ProBenefitsCard(style: .expanded)
        .padding()
}

#Preview("Minimal") {
    ProBenefitsCard(style: .minimal)
        .padding()
}
