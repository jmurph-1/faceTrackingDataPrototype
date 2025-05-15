import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    @State private var isPressed = false
    var onAnalyzeButtonTapped: () -> Void

    private let edgeSize: CGFloat = 50

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Order Changed: Left and Right gradients are now drawn first
                // so top and bottom can blend over them.

                // Left edge gradient
                HStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.7, green: 0.9, blue: 0.7), location: 0.0),  // Mint Green
                            .init(color: Color(red: 0.95, green: 0.95, blue: 0.7), location: 0.1), // Pale Yellow
                            .init(color: Color.clear, location: 0.6)
                        ]),
                        startPoint: animate ? .bottomLeading : .topLeading,
                        endPoint: .trailing
                    )
                    .frame(width: edgeSize, height: geometry.size.height)
                    Spacer()
                }

                // Right edge gradient
                HStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color(red: 0.8, green: 0.7, blue: 0.9), location: 0.4),  // Coral (approx)
                            .init(color: Color(red: 0.5, green: 0.8, blue: 0.95), location: 0.9) // Sky Blue
                        ]),
                        startPoint: .leading,
                        endPoint: animate ? .topTrailing : .bottomTrailing
                    )
                    .frame(width: edgeSize, height: geometry.size.height)
                }
                
                // Top edge gradient (drawn after sides)
                VStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.85, green: 0.75, blue: 0.92), location: 0.0),    // Lavender
                            .init(color: Color(red: 0.70, green: 0.85, blue: 0.95), location: 0.1),    // Light Blue
                            .init(color: Color.clear, location: 0.6)
                        ]),
                        startPoint: animate ? .topTrailing : .topLeading,
                        endPoint: .bottom
                    )
                    .frame(width: geometry.size.width, height: edgeSize)
                    Spacer()
                }

                // Bottom edge gradient (drawn after sides)
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color(red: 1.0, green: 0.8, blue: 0.7), location: 0.4), // Peach
                            .init(color: Color(red: 0.95, green: 0.75, blue: 0.8), location: 0.9) // Soft Pink
                        ]),
                        startPoint: .top,
                        endPoint: animate ? .bottomLeading : .bottomTrailing
                    )
                    .frame(width: geometry.size.width, height: edgeSize)
                }

                // Button VStack
                VStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                             isPressed = false
                             onAnalyzeButtonTapped()
                        }
                    }) {
                        Image(systemName: "camera.filters")
                            .font(.title) // Make icon larger
                            .foregroundColor(Color(white: 0.15)) // Dark icon for contrast on silver
                            .padding(16) // Adjust padding for the icon
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        Capsule().fill( // Maintain capsule shape
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(white: 0.95), // Brightest silver for highlight
                                    Color(white: 0.80), // Main silver body
                                    Color(white: 0.70), // Darker silver for depth
                                    Color(white: 0.85)  // Subtle reflected light
                                ]),
                                // Use the existing 'animate' state to make the shine move
                                startPoint: animate ? UnitPoint(x: 0.1, y: 0.1) : UnitPoint(x: 0.9, y: 0.9),
                                endPoint: animate ? UnitPoint(x: 0.9, y: 0.9) : UnitPoint(x: 0.1, y: 0.1)
                            )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.white.opacity(0.7), location: 0),
                                            .init(color: Color.white.opacity(0.2), location: 0.3),
                                            .init(color: Color.clear, location: 0.5),
                                            .init(color: Color.black.opacity(0.1), location: 0.7),
                                            .init(color: Color.black.opacity(0.3), location: 1.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3) // Adjusted shadow slightly
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .accessibilityLabel("Analyze Your Colors") // Keep accessibility label
                    .padding(.bottom, 24)
                }
                 .padding(.top, geometry.safeAreaInsets.top)
                 .padding(.bottom, geometry.safeAreaInsets.bottom)
                 .padding(.leading, geometry.safeAreaInsets.leading)
                 .padding(.trailing, geometry.safeAreaInsets.trailing)
            }
            .background(Color.white)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 50)
                        .repeatForever(autoreverses: true)
                ) {
                    animate.toggle()
                }
            }
        }
    }
}

struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LandingPageView(onAnalyzeButtonTapped: { })
    }
}
