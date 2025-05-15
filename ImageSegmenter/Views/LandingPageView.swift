import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    
    var onAnalyzeButtonTapped: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                // Top edge gradient: Lavender to Light Blue
                VStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.92), // Lavender
                            Color(red: 0.70, green: 0.85, blue: 0.95), // Light Blue
                            Color.white.opacity(0)
                        ]),
                        startPoint: animate ? .topLeading : .top,
                        endPoint: .bottom
                    )
                    .frame(width: geometry.size.width, height: 100)
                    .opacity(0.7)
                    
                    Spacer()
                }
                .edgesIgnoringSafeArea(.all)
                .padding(0)
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Bottom edge gradient: Peach to Soft Pink
                VStack(spacing: 0) {
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
                    .frame(width: geometry.size.width, height: 100)
                    .opacity(0.7)
                }
                .edgesIgnoringSafeArea(.all)
                .padding(0)
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Left edge gradient: Mint Green to Pale Yellow
                HStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.75, green: 0.95, blue: 0.80), // Mint Green
                            Color(red: 0.95, green: 0.95, blue: 0.75), // Pale Yellow
                            Color.white.opacity(0)
                        ]),
                        startPoint: animate ? .bottomLeading : .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 100, height: geometry.size.height)
                    .opacity(0.7)
                    
                    Spacer()
                }
                .edgesIgnoringSafeArea(.all)
                .padding(0)
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                HStack(spacing: 0) {
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
                    .frame(width: 100, height: geometry.size.height)
                    .opacity(0.7)
                }
                .edgesIgnoringSafeArea(.all)
                .padding(0)
                .frame(width: geometry.size.width, height: geometry.size.height)
                
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
            .ignoresSafeArea(.all)
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
