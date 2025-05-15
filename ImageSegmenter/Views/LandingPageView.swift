import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    
    var onAnalyzeButtonTapped: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            // Top edge gradient: Lavender to Light Blue
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.85, green: 0.75, blue: 0.92), // Lavender
                        Color(red: 0.70, green: 0.85, blue: 0.95), // Light Blue
                        Color.white.opacity(0)
                    ]),
                    startPoint: animate ? .topLeading : .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .opacity(0.7)
                
                Spacer()
            }
            .edgesIgnoringSafeArea(.top)
            
            // Bottom edge gradient: Peach to Soft Pink
            VStack {
                Spacer()
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color(red: 0.98, green: 0.80, blue: 0.90), // Soft Pink
                        Color(red: 0.98, green: 0.80, blue: 0.70)  // Peach
                    ]),
                    startPoint: .top,
                    endPoint: animate ? .bottomTrailing : .bottom
                )
                .frame(height: 100)
                .opacity(0.7)
            }
            .edgesIgnoringSafeArea(.bottom)
            
            // Left edge gradient: Mint Green to Pale Yellow
            HStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.75, green: 0.95, blue: 0.80), // Mint Green
                        Color(red: 0.95, green: 0.95, blue: 0.75), // Pale Yellow
                        Color.white.opacity(0)
                    ]),
                    startPoint: animate ? .bottomLeading : .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                .opacity(0.7)
                
                Spacer()
            }
            .edgesIgnoringSafeArea(.leading)
            
            HStack {
                Spacer()
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color(red: 0.60, green: 0.80, blue: 0.95), // Sky Blue
                        Color(red: 0.95, green: 0.60, blue: 0.50)  // Coral
                    ]),
                    startPoint: .leading,
                    endPoint: animate ? .topTrailing : .trailing
                )
                .frame(width: 100)
                .opacity(0.7)
            }
            .edgesIgnoringSafeArea(.trailing)
            
            VStack {
                Spacer()
                
                Button(action: onAnalyzeButtonTapped) {
                    Text("Analyze Your Colors")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color(red: 0.22, green: 0.64, blue: 0.65))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(AnimatedButtonStyle())
                .accessibilityLabel("Analyze Your Colors")
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 10)
                    .repeatForever(autoreverses: true)
            ) {
                animate.toggle()
            }
        }
    }
}

struct AnimatedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LandingPageView(onAnalyzeButtonTapped: {})
    }
}
