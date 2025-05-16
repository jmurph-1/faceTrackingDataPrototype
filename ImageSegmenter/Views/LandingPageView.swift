import SwiftUI

struct LandingPageView: View {
    @State private var animate = false
    @State private var isPressed = false
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
                if words.count >= 2 { abbreviation = String(words[0].prefix(1) + words[1].prefix(1)).lowercased() }
                else if let first = words.first { abbreviation = String(first.prefix(1)).lowercased() }
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
                        
                        let circleTextColor = theme.primaryColor.isDark() ? Color.white : Color.black.opacity(0.7)

                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(abbreviation)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.8)) // Ensure text is visible, might need adjustment based on theme
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                            )
                            .shadow(color: theme.primaryColor.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            if mainSeason.name == "WINTER" {
                Image("winter_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if mainSeason.name == "SPRING" {
                Image("spring_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if mainSeason.name == "SUMMER" {
                Image("summer_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if mainSeason.name == "AUTUMN" {
                Image("autumn_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        SeasonTheme.getTheme(for: mainSeason.subSeasons.first ?? "Soft Summer").backgroundColor.opacity(0.7),
                        SeasonTheme.getTheme(for: mainSeason.subSeasons.first ?? "Soft Summer").secondaryBackgroundColor.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .cornerRadius(12)
        .clipped()
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
    }
}

extension Color {
    func isDark() -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }
}

struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LandingPageView(onAnalyzeButtonTapped: { }, onSubSeasonTapped: { seasonName in print("\(seasonName) tapped") })
    }
}
