import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    @State private var isPressed = false
    @State private var animateBackground = false
    var onAnalyzeButtonTapped: () -> Void
    var onSubSeasonTapped: (String) -> Void

    private struct MainSeasonDisplay: Identifiable {
        let id = UUID()
        let name: String
        let subSeasons: [String]
    }

    private let mainSeasonDisplays: [MainSeasonDisplay] = [
        MainSeasonDisplay(name: "SPRING", subSeasons: ["Light Spring", "True Spring", "Bright Spring"]),
        MainSeasonDisplay(name: "SUMMER", subSeasons: ["Light Summer", "True Summer", "Soft Summer"]),
        MainSeasonDisplay(name: "AUTUMN", subSeasons: ["Soft Autumn", "True Autumn", "Dark Autumn"]),
        MainSeasonDisplay(name: "WINTER", subSeasons: ["Bright Winter", "True Winter", "Dark Winter"])
    ]

    private func getAbbreviation(for subSeasonName: String) -> String {
        let words = subSeasonName.split(separator: " ").map { String($0) }
        var abbreviation = ""
        if let firstWord = words.first?.lowercased() {
            switch firstWord {
            case "bright": abbreviation = "brt"
            case "true": abbreviation = "tru"
            case "dark": abbreviation = "drk"
            case "light": abbreviation = "lgt"
            case "soft": abbreviation = "sft"
            default:
                if words.count >= 2 { abbreviation = String(words[0].prefix(1) + words[1].prefix(1)).lowercased() } else if let first = words.first { abbreviation = String(first.prefix(1)).lowercased() }
            }
        }
        return abbreviation
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Text("S13")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundColor(Color(white: 0.2))
                        .padding(.top, geometry.safeAreaInsets.top + 20)
                        .padding(.bottom, 10)

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(mainSeasonDisplays) { mainSeason in
                                seasonModuleView(mainSeason: mainSeason)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .frame(maxHeight: .infinity)

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
                            .font(.title)
                            .foregroundColor(Color(white: 0.15))
                            .padding(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(white: 0.95),
                                    Color(white: 0.80),
                                    Color(white: 0.70),
                                    Color(white: 0.85)
                                ]),
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
                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .accessibilityLabel("Analyze Your Colors")
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 24)
                }
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
                withAnimation(
                    Animation.easeInOut(duration: 20)
                        .repeatForever(autoreverses: true)
                ) {
                    animateBackground.toggle()
                }
            }
        }
    }

    @ViewBuilder
    private func seasonModuleView(mainSeason: MainSeasonDisplay) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(mainSeason.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(SeasonTheme.getTheme(for: mainSeason.subSeasons.first ?? "Soft Summer").textColor.opacity(0.8))

            HStack(spacing: 15) {
                ForEach(mainSeason.subSeasons, id: \.self) { subSeasonName in
                    Button(action: {
                        print("LandingPageView: Subseason circle tapped - \(subSeasonName)")
                        onSubSeasonTapped(subSeasonName)
                    }) {
                        let theme = SeasonTheme.getTheme(for: subSeasonName)
                        let abbreviation = getAbbreviation(for: subSeasonName)

                        ZStack {
                            Circle()
                                .fill(theme.primaryColor)
                                .frame(width: 50, height: 50)
                                .shadow(color: theme.primaryColor.opacity(0.3), radius: 3, x: 0, y: 2)

                            Text(abbreviation)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))

                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                .frame(width: 50, height: 50)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 60, height: 60) // Slightly larger hit area than the visual circle
                    .contentShape(Circle()) // Apply content shape to the button itself
                }
            }
            .zIndex(1) // Ensure buttons are on top of any background
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Season gradient backgrounds
                if mainSeason.name == "WINTER" {
                    // Winter gradient - cool blues and silvers
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#4682b4"), location: 0.0),  // Steel Blue
                            .init(color: Color(hex: "#6a7faf"), location: 0.4),  // Blue Gray
                            .init(color: Color(hex: "#7986cb"), location: 0.7),  // Cornflower Blue
                            .init(color: Color(hex: "#5c6bc0"), location: 1.0)   // Indigo
                        ]),
                        startPoint: animateBackground ? UnitPoint(x: 0.1, y: 0.1) : UnitPoint(x: 0.9, y: 0.9),
                        endPoint: animateBackground ? UnitPoint(x: 0.9, y: 0.9) : UnitPoint(x: 0.1, y: 0.1)
                    )
                    .blur(radius: 0.5)
                    .overlay(
                        ZStack {
                            // Subtle gleam effect
                            RadialGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.1), Color.clear]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 300
                            )
                        }
                    )
                    .allowsHitTesting(false)
                } else if mainSeason.name == "SPRING" {
                    // Spring gradient - fresh greens and soft pinks
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#8BC34A"), location: 0.0),  // Light Green
                            .init(color: Color(hex: "#AEEA00"), location: 0.3),  // Lime
                            .init(color: Color(hex: "#C6FF00"), location: 0.6),  // Lime Accent
                            .init(color: Color(hex: "#7CB342"), location: 1.0)   // Light Green
                        ]),
                        startPoint: animateBackground ? UnitPoint(x: 0.9, y: 0.1) : UnitPoint(x: 0.1, y: 0.9),
                        endPoint: animateBackground ? UnitPoint(x: 0.1, y: 0.9) : UnitPoint(x: 0.9, y: 0.1)
                    )
                    .blur(radius: 0.5)
                    .overlay(
                        ZStack {
                            // Subtle pink accent
                            RadialGradient(
                                gradient: Gradient(colors: [Color(hex: "#FFC0CB").opacity(0.2), Color.clear]),
                                center: .bottomTrailing,
                                startRadius: 20,
                                endRadius: 250
                            )
                        }
                    )
                    .allowsHitTesting(false)
                } else if mainSeason.name == "SUMMER" {
                    // Summer gradient - soft blues and gentle purples
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#90CAF9"), location: 0.0),  // Light Blue
                            .init(color: Color(hex: "#80DEEA"), location: 0.3),  // Light Cyan
                            .init(color: Color(hex: "#B39DDB"), location: 0.7),  // Light Purple
                            .init(color: Color(hex: "#BBDEFB"), location: 1.0)   // Very Light Blue
                        ]),
                        startPoint: animateBackground ? UnitPoint(x: 0.1, y: 0.9) : UnitPoint(x: 0.9, y: 0.1),
                        endPoint: animateBackground ? UnitPoint(x: 0.9, y: 0.1) : UnitPoint(x: 0.1, y: 0.9)
                    )
                    .blur(radius: 0.5)
                    .overlay(
                        ZStack {
                            // Subtle gleam effect
                            RadialGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 200
                            )
                        }
                    )
                    .allowsHitTesting(false)
                } else if mainSeason.name == "AUTUMN" {
                    // Autumn gradient - warm oranges, reds and golden hues
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#FF9800"), location: 0.0),  // Orange
                            .init(color: Color(hex: "#FF5722"), location: 0.3),  // Deep Orange
                            .init(color: Color(hex: "#F57C00"), location: 0.6),  // Dark Orange
                            .init(color: Color(hex: "#BF360C"), location: 1.0)   // Deep Orange Dark
                        ]),
                        startPoint: animateBackground ? UnitPoint(x: 0.9, y: 0.9) : UnitPoint(x: 0.1, y: 0.1),
                        endPoint: animateBackground ? UnitPoint(x: 0.1, y: 0.1) : UnitPoint(x: 0.9, y: 0.9)
                    )
                    .blur(radius: 0.5)
                    .overlay(
                        ZStack {
                            // Subtle gold accent
                            RadialGradient(
                                gradient: Gradient(colors: [Color(hex: "#FFD700").opacity(0.15), Color.clear]),
                                center: .bottomLeading,
                                startRadius: 20,
                                endRadius: 250
                            )
                        }
                    )
                    .allowsHitTesting(false)
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            SeasonTheme.getTheme(for: mainSeason.subSeasons.first ?? "Soft Summer").backgroundColor.opacity(0.7),
                            SeasonTheme.getTheme(for: mainSeason.subSeasons.first ?? "Soft Summer").secondaryBackgroundColor.opacity(0.5)
                        ]),
                        startPoint: animateBackground ? UnitPoint(x: 0.2, y: 0.8) : UnitPoint(x: 0.8, y: 0.2),
                        endPoint: animateBackground ? UnitPoint(x: 0.8, y: 0.2) : UnitPoint(x: 0.2, y: 0.8)
                    )
                    .allowsHitTesting(false) // Prevent the gradient from intercepting touches
                }
            }
            .opacity(0.4) // Reduce background intensity
        )
        .cornerRadius(12)
        .clipped()
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
    }
}

extension Color {
    func isDark() -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.5
    }
}
