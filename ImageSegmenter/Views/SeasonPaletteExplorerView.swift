import SwiftUI

struct SeasonPaletteExplorerView: View {
    /// All palette colors
    private let allColorItems: [ColorItem]
    private let columns: [GridItem]

    /// Segmented control tabs
    private enum PaletteSegment: String, CaseIterable, Identifiable {
        case best = "Best Colors"
        case all = "All Colors"
        var id: String { rawValue }
    }

    // MARK: - State

    @State private var selectedSegment: PaletteSegment = .best
    @State private var favoriteIds: Set<UUID>
    @State private var selectedColor: ColorItem?
    @State private var magnification: CGFloat = 1.0

    init(colorItems: [ColorItem], columns: Int = 6) {
        self.allColorItems = colorItems
        self.columns = Array(repeating: GridItem(.flexible()), count: columns)
        // Initialize favorites with recommended colors
        _favoriteIds = State(initialValue: Set(colorItems.filter { $0.isRecommended }.map { $0.id }))
    }

    // MARK: - Computed

    private var displayedItems: [ColorItem] {
        switch selectedSegment {
        case .best:
            return allColorItems.filter { favoriteIds.contains($0.id) }
        case .all:
            return allColorItems
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $selectedSegment) {
                ForEach(PaletteSegment.allCases) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)

            ScrollView([.vertical, .horizontal]) {
                ZStack {
                    if selectedSegment == .best {
                        paletteGrid(for: displayedItems)
                            .id("best")
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        paletteGrid(for: displayedItems)
                            .id("all")
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(magnification)
                .gesture(MagnificationGesture()
                    .onChanged { value in
                        magnification = value
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            magnification = max(1.0, magnification)
                        }
                    })
            }
            .frame(maxHeight: 200)
        }
        .animation(.spring(), value: selectedSegment)
        .sheet(item: $selectedColor) { item in
            ColorDetailCard(
                colorItem: item,
                isAvoidanceMode: false,
                onDismiss: { selectedColor = nil },
                onSaveFavorite: { toggleFavorite(item) }
            )
        }
    }

    // MARK: - Subviews

    private func paletteGrid(for items: [ColorItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(hex: item.hexValue))
                            .frame(width: 40, height: 40)
                            .onLongPressGesture {
                                selectedColor = item
                            }

                        Button(action: { toggleFavorite(item) }) {
                            Image(systemName: favoriteIds.contains(item.id) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                                .padding(4)
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
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Actions

    private func toggleFavorite(_ item: ColorItem) {
        if favoriteIds.contains(item.id) {
            favoriteIds.remove(item.id)
        } else {
            favoriteIds.insert(item.id)
        }
    }
}
