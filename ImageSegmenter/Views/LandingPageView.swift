import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    var onAnalyzeButtonTapped: () -> Void

    // how thick your edge gradients and border should be
    private let edgeSize: CGFloat = 50
    private let borderWidth: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1) White background
                Color.white
                    .edgesIgnoringSafeArea(.all)

                // 2) Top edge gradient
                VStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.92),    // Lavender
                            Color(red: 0.70, green: 0.85, blue: 0.95),    // Light Blue
                            Color.white.opacity(0)
                        ]),
                        startPoint: animate ? .topLeading : .top,
                        endPoint: .bottom
                    )
                    .frame(width: geometry.size.width, height: edgeSize)
                    Spacer()
                }

                // 3) Bottom edge gradient
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color(red: 0.70, green: 0.85, blue: 0.95),
                            Color(red: 0.85, green: 0.75, blue: 0.92)
                        ]),
                        startPoint: .top,
                        endPoint: animate ? .bottomTrailing : .bottom
                    )
                    .frame(width: geometry.size.width, height: edgeSize)
                }

                // 4) Left edge gradient
                HStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.92),
                            Color(red: 0.70, green: 0.85, blue: 0.95),
                            Color.white.opacity(0)
                        ]),
                        startPoint: animate ? .topLeading : .leading,
                        endPoint: .trailing
                    )
                    .frame(width: edgeSize, height: geometry.size.height)
                    Spacer()
                }

                // 5) Right edge gradient
                HStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color(red: 0.70, green: 0.85, blue: 0.95),
                            Color(red: 0.85, green: 0.75, blue: 0.92)
                        ]),
                        startPoint: .leading,
                        endPoint: animate ? .bottomTrailing : .trailing
                    )
                    .frame(width: edgeSize, height: geometry.size.height)
                }

                // 6) Your main content (e.g. Analyze button)
                VStack {
                    Spacer()
                    Button(action: onAnalyzeButtonTapped) {
                        Text("Analyze Your Colors")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Capsule().fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.85, green: 0.75, blue: 0.92),
                                        Color(red: 0.70, green: 0.85, blue: 0.95)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            ))
                    }
                    Spacer().frame(height: 45)
                }
            }
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 60)
                        .repeatForever(autoreverses: true)
                ) {
                    animate.toggle()
                }
            }
            // 7) Gradient border overlay
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.85, green: 0.75, blue: 0.92),
                                Color(red: 0.70, green: 0.85, blue: 0.95)                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
                    .edgesIgnoringSafeArea(.all)
            )
        }
    }
}

struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LandingPageView(onAnalyzeButtonTapped: { })
    }
}
