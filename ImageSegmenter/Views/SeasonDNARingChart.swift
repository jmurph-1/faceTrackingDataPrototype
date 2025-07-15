//
//  SeasonDNARingChart.swift
//  ImageSegmenter
//
//  Enhanced version with micro-animations and refined visual design
//

import SwiftUI

struct SeasonDNARingChart: View {
    
    // MARK: - Properties
    
    let seasonDNA: SeasonDNA
    let primaryColor: Color
    let secondaryColor: Color?
    let tertiaryColor: Color?
    let size: CGFloat
    
    @State private var animationProgress: Double = 0
    @State private var primaryProgress: Double = 0
    @State private var secondaryProgress: Double = 0
    @State private var tertiaryProgress: Double = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var showExpandedCenter: Bool = false
    @State private var selectedSegment: SegmentType? = nil
    @State private var rotationAngle: Double = 0
    @State private var hoveredSegment: SegmentType? = nil
    
    // Ring configuration
    private let ringWidth: CGFloat
    private let backgroundRingOpacity: Double = 0.08
    
    // Animation constants
    private let pulseRange: ClosedRange<Double> = 0.95...1.05
    private let pulseDuration: Double = 2.0
    private let rotationDuration: Double = 60.0
    
    // Segment types for interaction
    enum SegmentType: CaseIterable {
        case primary, secondary, tertiary
        
        var displayName: String {
            switch self {
            case .primary: return "Primary"
            case .secondary: return "Secondary"
            case .tertiary: return "Tertiary"
            }
        }
    }
    
    init(seasonDNA: SeasonDNA,
         primaryColor: Color,
         secondaryColor: Color? = nil,
         tertiaryColor: Color? = nil,
         size: CGFloat = 200) {
        self.seasonDNA = seasonDNA
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.tertiaryColor = tertiaryColor
        self.size = size
        self.ringWidth = size * 0.12
    }
    
    var body: some View {
        ZStack {
            // Subtle background glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            primaryColor.opacity(0.1),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .scaleEffect(pulseAnimation)
                .animation(
                    .easeInOut(duration: pulseDuration)
                    .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            
            ZStack {
                // Background ring with subtle gradient
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(backgroundRingOpacity),
                                Color.gray.opacity(backgroundRingOpacity * 0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: ringWidth
                    )
                    .frame(width: size, height: size)
                
                // Primary season arc with tap gesture
                primarySeasonArc
                
                // Secondary season arc (if exists)
                if seasonDNA.secondary != nil {
                    secondarySeasonArc
                }
                
                // Tertiary season arc (if exists)
                if seasonDNA.tertiary != nil {
                    tertiarySeasonArc
                }
                
                // Center content with improved layout
                centerContent
                    .scaleEffect(showExpandedCenter ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showExpandedCenter)
            }
            
            // Animated confidence indicators for primary season
            primaryConfidenceIndicators
            
            // Secondary season confidence indicators
            if seasonDNA.secondary != nil {
                secondaryConfidenceIndicators
            }
            
            // Tertiary season confidence indicators
            if seasonDNA.tertiary != nil {
                tertiaryConfidenceIndicators
            }
        }
        .onAppear {
            // Calculate dynamic durations based on segment weights
            let baseDurationMultiplier = 2.0
            let initialDelay = 0.5
            
            // Primary animation
            let primaryDuration = max(0.5, min(1.5, Double(seasonDNA.primary.weight) * baseDurationMultiplier))
            let primaryDelay = initialDelay
            
            withAnimation(.easeInOut(duration: primaryDuration).delay(primaryDelay)) {
                primaryProgress = 1.0
            }
            
            // Secondary animation (if exists)
            if let secondary = seasonDNA.secondary {
                let secondaryDuration = max(0.4, min(1.2, Double(secondary.weight) * baseDurationMultiplier))
                let secondaryDelay = primaryDelay + primaryDuration
                
                withAnimation(.easeInOut(duration: secondaryDuration).delay(secondaryDelay)) {
                    secondaryProgress = 1.0
                }
                
                // Tertiary animation (if exists)
                if let tertiary = seasonDNA.tertiary {
                    let tertiaryDuration = max(0.3, min(1.0, Double(tertiary.weight) * baseDurationMultiplier))
                    let tertiaryDelay = secondaryDelay + secondaryDuration
                    
                    withAnimation(.easeInOut(duration: tertiaryDuration).delay(tertiaryDelay)) {
                        tertiaryProgress = 1.0
                    }
                }
            } else if let tertiary = seasonDNA.tertiary {
                // Handle case where there's tertiary but no secondary
                let tertiaryDuration = max(0.3, min(1.0, Double(tertiary.weight) * baseDurationMultiplier))
                let tertiaryDelay = primaryDelay + primaryDuration
                
                withAnimation(.easeInOut(duration: tertiaryDuration).delay(tertiaryDelay)) {
                    tertiaryProgress = 1.0
                }
            }
            
            // Keep the overall animation progress for dots (total duration)
            let totalDuration = primaryDuration +
                (seasonDNA.secondary != nil ? max(0.4, min(1.2, Double(seasonDNA.secondary!.weight) * baseDurationMultiplier)) : 0) +
                (seasonDNA.tertiary != nil ? max(0.3, min(1.0, Double(seasonDNA.tertiary!.weight) * baseDurationMultiplier)) : 0)
            
            withAnimation(.easeInOut(duration: totalDuration).delay(initialDelay)) {
                animationProgress = 1.0
            }
            
            pulseAnimation = pulseRange.upperBound
            
            withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
    
    // MARK: - Ring Segments
    
    @ViewBuilder
    private var primarySeasonArc: some View {
        Circle()
            .trim(from: 0, to: CGFloat(seasonDNA.primary.weight) * animationProgress)
            .stroke(
                primaryColor.opacity(hoveredSegment == .primary ? 0.9 : 0.8),
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
            .shadow(color: primaryColor.opacity(0.3), radius: 6, x: 0, y: 3)
            .scaleEffect(hoveredSegment == .primary ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: hoveredSegment)
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    selectedSegment = selectedSegment == .primary ? nil : .primary
                }
            }
            .onHover { isHovering in
                hoveredSegment = isHovering ? .primary : nil
            }
    }
    
    @ViewBuilder
    private var secondarySeasonArc: some View {
        if let secondary = seasonDNA.secondary,
           let secondaryColor = secondaryColor {
            Circle()
                .trim(
                    from: CGFloat(seasonDNA.primary.weight),
                    to: CGFloat(seasonDNA.primary.weight + secondary.weight) * animationProgress
                )
                .stroke(
                    secondaryColor.opacity(hoveredSegment == .secondary ? 0.9 : 0.8),
                    style: StrokeStyle(lineWidth: ringWidth * 0.85, lineCap: .butt)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: secondaryColor.opacity(0.2), radius: 4, x: 0, y: 2)
                .scaleEffect(hoveredSegment == .secondary ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: hoveredSegment)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedSegment = selectedSegment == .secondary ? nil : .secondary
                    }
                }
                .onHover { isHovering in
                    hoveredSegment = isHovering ? .secondary : nil
                }
        }
    }
    
    @ViewBuilder
    private var tertiarySeasonArc: some View {
        if let tertiary = seasonDNA.tertiary,
           let tertiaryColor = tertiaryColor {
            Circle()
                .trim(
                    from: CGFloat(seasonDNA.primary.weight + (seasonDNA.secondary?.weight ?? 0)),
                    to: CGFloat(seasonDNA.primary.weight + (seasonDNA.secondary?.weight ?? 0) + tertiary.weight) * animationProgress
                )
                .stroke(
                    tertiaryColor.opacity(hoveredSegment == .tertiary ? 0.9 : 0.8),
                    style: StrokeStyle(lineWidth: ringWidth * 0.7, lineCap: .butt)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: tertiaryColor.opacity(0.15), radius: 3, x: 0, y: 1)
                .scaleEffect(hoveredSegment == .tertiary ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: hoveredSegment)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedSegment = selectedSegment == .tertiary ? nil : .tertiary
                    }
                }
                .onHover { isHovering in
                    hoveredSegment = isHovering ? .tertiary : nil
                }
        }
    }
    
    // MARK: - Confidence Indicators
    
    @ViewBuilder
    private var primaryConfidenceIndicators: some View {
        let primaryWeight = seasonDNA.primary.weight
        let dotCount = max(3, Int(primaryWeight * 12)) // More dots for primary
        
        ForEach(0..<dotCount, id: \.self) { index in
            let arcSpan = Double(primaryWeight) * 360.0
            let angle = -90.0 + (Double(index) / Double(max(1, dotCount - 1))) * arcSpan
            let delay = Double(index) * 0.1
            
            Circle()
                .fill(primaryColor.opacity(0.7))
                .frame(width: 4, height: 4)
                .offset(y: -(size * 0.62))
                .rotationEffect(.degrees(angle))
                .scaleEffect(primaryProgress)
                .opacity(primaryProgress)
                .animation(
                    .easeInOut(duration: 0.5).delay(1.5 + delay),
                    value: primaryProgress
                )
        }
    }
    
    @ViewBuilder
    private var secondaryConfidenceIndicators: some View {
        if let secondary = seasonDNA.secondary,
           let secondaryColor = secondaryColor {
            let secondaryWeight = secondary.weight
            let dotCount = max(2, Int(secondaryWeight * 8)) // Fewer dots for secondary
            
            ForEach(0..<dotCount, id: \.self) { index in
                let baseAngle = Double(seasonDNA.primary.weight) * 360.0 - 90.0
                let arcSpan = Double(secondaryWeight) * 360.0
                let angle = baseAngle + (Double(index) / Double(max(1, dotCount - 1))) * arcSpan
                let delay = Double(index) * 0.15
                
                Circle()
                    .fill(secondaryColor.opacity(0.7))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: -(size * 0.62))
                    .rotationEffect(.degrees(angle))
                    .scaleEffect(secondaryProgress)
                    .opacity(secondaryProgress)
                    .animation(
                        .easeInOut(duration: 0.5).delay(2.0 + delay),
                        value: secondaryProgress
                    )
            }
        }
    }
    
    @ViewBuilder
    private var tertiaryConfidenceIndicators: some View {
        if let tertiary = seasonDNA.tertiary,
           let tertiaryColor = tertiaryColor {
            let tertiaryWeight = tertiary.weight
            let dotCount = max(1, Int(tertiaryWeight * 6)) // Even fewer dots for tertiary
            
            ForEach(0..<dotCount, id: \.self) { index in
                let baseAngle = Double(seasonDNA.primary.weight + (seasonDNA.secondary?.weight ?? 0)) * 360.0 - 90.0
                let arcSpan = Double(tertiaryWeight) * 360.0
                let angle = baseAngle + (Double(index) / Double(max(1, dotCount - 1))) * arcSpan
                let delay = Double(index) * 0.2
                
                Circle()
                    .fill(tertiaryColor.opacity(0.7))
                    .frame(width: 3, height: 3)
                    .offset(y: -(size * 0.62))
                    .rotationEffect(.degrees(angle))
                    .scaleEffect(tertiaryProgress)
                    .opacity(tertiaryProgress)
                    .animation(
                        .easeInOut(duration: 0.5).delay(2.5 + delay),
                        value: tertiaryProgress
                    )
            }
        }
    }
    
    // MARK: - Center Content
    
    @ViewBuilder
    private var centerContent: some View {
        ZStack {
            // Subtle background for better readability
            Circle()
                .fill(Color(UIColor.systemBackground).opacity(0.95))
                .frame(width: size * 0.7, height: size * 0.7)
                .blur(radius: 1)
                .allowsHitTesting(false) // Allow taps to pass through to rings

            VStack(spacing: 0) {
                if let selectedSegment = selectedSegment {
                    segmentDetailView(for: selectedSegment)
                } else {
                    defaultCenterView
                }
            }
            .frame(width: size * 0.65)
            // Add contentShape to make sure the VStack's gesture only applies to its bounds
            .contentShape(Rectangle()) 
            .onTapGesture {
                if selectedSegment != nil {
                    // If a segment detail is showing, tapping it closes it
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedSegment = nil
                    }
                } else {
                    // If default view is showing, tapping it toggles its expanded state
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showExpandedCenter.toggle()
                    }
                }
            }
            .onLongPressGesture {
                 if selectedSegment == nil { // Only allow long press to expand if default view is showing
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showExpandedCenter = true // Force expand default view
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var defaultCenterView: some View {
        if showExpandedCenter {
            expandedCenterDetails
        } else {
            VStack(spacing: 4) {
                // Season name - centered and most prominent
                Text(formatSeasonName(seasonDNA.primary.season))
                    .font(.system(size: size * 0.12, weight: .bold, design: .serif))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Match indicator - directly below season name
                matchIndicator
            }
        }
    }
    
    @ViewBuilder
    private var expandedCenterDetails: some View {
        VStack(spacing: 5) {
            // Primary season details
            HStack(spacing: 6) {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 6, height: 6)
                
                Text(formatSeasonName(seasonDNA.primary.season))
                    .font(.system(size: size * 0.08, weight: .semibold))
                    .foregroundColor(primaryColor)
                
                Text(seasonDNA.primary.percentageString)
                    .font(.system(size: size * 0.08, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            // Secondary season details
            if let secondary = seasonDNA.secondary {
                HStack(spacing: 6) {
                    Circle()
                        .fill(secondaryColor ?? .secondary)
                        .frame(width: 6, height: 6)
                    
                    Text(formatSeasonName(secondary.season))
                        .font(.system(size: size * 0.08, weight: .semibold))
                        .foregroundColor(secondaryColor ?? .secondary)
                    
                    Text(secondary.percentageString)
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            
            // Tertiary season details
            if let tertiary = seasonDNA.tertiary {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tertiaryColor ?? .secondary)
                        .frame(width: 6, height: 6)
                    
                    Text(formatSeasonName(tertiary.season))
                        .font(.system(size: size * 0.08, weight: .semibold))
                        .foregroundColor(tertiaryColor ?? .secondary)
                    
                    Text(tertiary.percentageString)
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            
            // Confidence level
            HStack(spacing: 3) {
                Image(systemName: confidenceIcon)
                    .font(.system(size: size * 0.06))
                    .foregroundColor(confidenceColor)
                
                Text("Confidence: \(Int(seasonDNA.classificationConfidence * 100))%")
                    .font(.system(size: size * 0.07, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private var matchIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: seasonDNA.isPureMatch ? "checkmark.circle.fill" : "shuffle.circle.fill")
                .font(.system(size: size * 0.06))
                .foregroundColor(seasonDNA.isPureMatch ? .green : .orange)
            
            Text(seasonDNA.isPureMatch ? "Pure Match" : "Blended")
                .font(.system(size: size * 0.065, weight: .medium))
                .foregroundColor(seasonDNA.isPureMatch ? .green : .orange)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private func segmentDetailView(for segment: SegmentType) -> some View {
        VStack(spacing: 8) {
            // Segment indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(colorForSegment(segment))
                    .frame(width: 8, height: 8)
                
                Text("\(segment.displayName) Season")
                    .font(.system(size: size * 0.08, weight: .semibold))
                    .foregroundColor(colorForSegment(segment))
            }
            
            // Season name and percentage
            Text(nameForSegment(segment))
                .font(.system(size: size * 0.095, weight: .bold, design: .serif))
                .foregroundColor(colorForSegment(segment))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(percentageForSegment(segment))
                .font(.system(size: size * 0.11, weight: .heavy))
                .foregroundColor(colorForSegment(segment))
            
            // Tap to close hint
            Text("Tap ring again to close")
                .font(.system(size: size * 0.055))
                .foregroundColor(.secondary)
                .opacity(0.7)
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForSegment(_ segment: SegmentType) -> Color {
        switch segment {
        case .primary: return primaryColor
        case .secondary: return secondaryColor ?? .secondary
        case .tertiary: return tertiaryColor ?? .secondary
        }
    }
    
    private func nameForSegment(_ segment: SegmentType) -> String {
        switch segment {
        case .primary: return formatSeasonName(seasonDNA.primary.season)
        case .secondary: return formatSeasonName(seasonDNA.secondary?.season ?? "")
        case .tertiary: return formatSeasonName(seasonDNA.tertiary?.season ?? "")
        }
    }
    
    private func percentageForSegment(_ segment: SegmentType) -> String {
        switch segment {
        case .primary: return seasonDNA.primary.percentageString
        case .secondary: return seasonDNA.secondary?.percentageString ?? "0%"
        case .tertiary: return seasonDNA.tertiary?.percentageString ?? "0%"
        }
    }
    
    private var confidenceIcon: String {
        let confidence = seasonDNA.classificationConfidence
        if confidence >= 0.9 {
            return "star.fill"
        } else if confidence >= 0.7 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private var confidenceColor: Color {
        let confidence = seasonDNA.classificationConfidence
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatSeasonName(_ season: String, short: Bool = false) -> String {
        if short {
            let words = season.components(separatedBy: " ")
            if words.count > 1 {
                return words.last ?? season
            }
        }
        return season
    }
}

// MARK: - Animated Percentage Component

struct AnimatedPercentage: View {
    let percentage: Double
    let color: Color
    let fontSize: CGFloat
    let animationProgress: Double
    
    @State private var displayedPercentage: Double = 0
    
    var body: some View {
        Text("\(Int(displayedPercentage * 100))%")
            .font(.system(size: fontSize, weight: .heavy))
            .foregroundColor(color)
            .onReceive([animationProgress].publisher.first()) { newValue in
                withAnimation(.easeInOut(duration: 1.2).delay(0.8)) {
                    displayedPercentage = percentage * newValue
                }
            }
    }
}

// MARK: - Preview

struct SeasonDNARingChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Pure season example
            SeasonDNARingChart(
                seasonDNA: SeasonDNA(
                    primary: SeasonWeight(season: "True Autumn", weight: 1.0),
                    explanation: "Pure True Autumn characteristics",
                    classificationConfidence: 0.92
                ),
                primaryColor: .orange,
                size: 200
            )
            
            // Blended season example
            SeasonDNARingChart(
                seasonDNA: SeasonDNA(
                    primary: SeasonWeight(season: "Soft Summer", weight: 0.75),
                    secondary: SeasonWeight(season: "Soft Autumn", weight: 0.25),
                    explanation: "Soft Summer with Autumn influences",
                    classificationConfidence: 0.85,
                    blendJustification: "Muted qualities suggest autumn overlap"
                ),
                primaryColor: .blue,
                secondaryColor: .orange,
                size: 200
            )
            
            // Complex blend example
            SeasonDNARingChart(
                seasonDNA: SeasonDNA(
                    primary: SeasonWeight(season: "Light Spring", weight: 0.65),
                    secondary: SeasonWeight(season: "Light Summer", weight: 0.25),
                    tertiary: SeasonWeight(season: "Clear Spring", weight: 0.10),
                    explanation: "Light Spring with summer and clear influences",
                    classificationConfidence: 0.78,
                    blendJustification: "Light qualities with cool and clear elements"
                ),
                primaryColor: .yellow,
                secondaryColor: .blue,
                tertiaryColor: .green,
                size: 200
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
