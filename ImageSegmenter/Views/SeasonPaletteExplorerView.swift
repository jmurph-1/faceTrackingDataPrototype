import SwiftUI

struct SeasonPaletteExplorerView: View {
    let colorItems: [ColorItem]
    private let columns: [GridItem]

    init(colorItems: [ColorItem], columns: Int = 6) {
        self.colorItems = colorItems
        self.columns = Array(repeating: GridItem(.flexible()), count: columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Palette")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(colorItems) { item in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(Color(hex: item.hexValue))
                                    .frame(width: 40, height: 40)

                                if item.isRecommended {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                        .offset(x: 6, y: -6)
                                }
                            }

                            Text(item.name)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .frame(width: 44)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)
        }
    }
}
