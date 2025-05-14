import SwiftUI

/// View for displaying frame quality indicators and feedback
struct FrameQualityIndicatorView: View {
    
    /// The quality score to display
    let qualityScore: FrameQualityService.QualityScore
    
    /// Show detailed scores
    var showDetailed: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
            // Overall quality indicator
            HStack {
                Label(
                    "Frame Quality",
                    systemImage: qualityScore.isAcceptableForAnalysis ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundColor(qualityScore.isAcceptableForAnalysis ? .green : .orange)
                .font(.headline)
                
                Spacer()
                
                // Progress indicator
                ProgressView(value: Double(qualityScore.overall))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 80)
                    .accentColor(qualityScore.isAcceptableForAnalysis ? .green : .orange)
            }
            .padding(.horizontal)
            
            // Feedback message if quality is not acceptable
            if let feedback = qualityScore.feedbackMessage {
                Text(feedback)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(8)
            }
            
            // Detailed scores (optional)
            if showDetailed {
                VStack(spacing: 6) {
                    detailedScoreRow(label: "Face Size", value: qualityScore.faceSize, threshold: FrameQualityService.minimumFaceSizeScoreForAnalysis)
                    detailedScoreRow(label: "Position", value: qualityScore.facePosition, threshold: FrameQualityService.minimumFacePositionScoreForAnalysis)
                    detailedScoreRow(label: "Brightness", value: qualityScore.brightness, threshold: FrameQualityService.minimumBrightnessScoreForAnalysis)
                    detailedScoreRow(label: "Sharpness", value: qualityScore.sharpness, threshold: 0.5)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(qualityScore.isAcceptableForAnalysis ? Color.green.opacity(0.6) : Color.orange.opacity(0.6), lineWidth: 1)
        )
    }
    
    // MARK: - Helper views
    
    /// Create a row for displaying a detailed score
    private func detailedScoreRow(label: String, value: Float, threshold: Float) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            
            ProgressView(value: Double(value), total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 6)
                .accentColor(value >= threshold ? .green : .orange)
            
            Text(String(format: "%.0f%%", value * 100))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 40)
        }
    }
}

// MARK: - Preview
struct FrameQualityIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Good quality
            FrameQualityIndicatorView(
                qualityScore: FrameQualityService.QualityScore(
                    overall: 0.85,
                    faceSize: 0.9,
                    facePosition: 0.8,
                    brightness: 0.9,
                    sharpness: 0.7
                ),
                showDetailed: true
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.black)
            
            // Poor quality
            FrameQualityIndicatorView(
                qualityScore: FrameQualityService.QualityScore(
                    overall: 0.55,
                    faceSize: 0.4,
                    facePosition: 0.6,
                    brightness: 0.7,
                    sharpness: 0.5
                ),
                showDetailed: true
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.black)
        }
    }
} 