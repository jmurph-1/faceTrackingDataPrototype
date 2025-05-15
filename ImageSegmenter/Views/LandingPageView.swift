import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    
    var onAnalyzeButtonTapped: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.85, green: 0.75, blue: 0.92), // Lavender
                    Color(red: 0.70, green: 0.85, blue: 0.95)  // Light Blue
                ]),
                startPoint: animate ? .topLeading : .top,
                endPoint: animate ? .center : .topTrailing
            )
            .opacity(0.7)
            .ignoresSafeArea(edges: .top)
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.80, blue: 0.70), // Peach
                    Color(red: 0.98, green: 0.80, blue: 0.90)  // Soft Pink
                ]),
                startPoint: animate ? .bottomTrailing : .bottom,
                endPoint: animate ? .center : .bottomLeading
            )
            .opacity(0.7)
            .ignoresSafeArea(edges: .bottom)
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.75, green: 0.95, blue: 0.80), // Mint Green
                    Color(red: 0.95, green: 0.95, blue: 0.75)  // Pale Yellow
                ]),
                startPoint: animate ? .bottomLeading : .leading,
                endPoint: animate ? .center : .topLeading
            )
            .opacity(0.7)
            .ignoresSafeArea(edges: .leading)
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.60, blue: 0.50), // Coral
                    Color(red: 0.60, green: 0.80, blue: 0.95)  // Sky Blue
                ]),
                startPoint: animate ? .topTrailing : .trailing,
                endPoint: animate ? .center : .bottomTrailing
            )
            .opacity(0.7)
            .ignoresSafeArea(edges: .trailing)
            
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
