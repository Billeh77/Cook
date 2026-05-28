import SwiftUI

struct CanCookView: View {
    @State private var items: [CookabilityItem] = []
    @State private var isLoading = false

    private var canCook:   [CookabilityItem] { items.filter { $0.missingCount == 0 } }
    private var almostThere: [CookabilityItem] { items.filter { $0.missingCount > 0 && $0.missingCount <= 2 } }
    private var needMore:  [CookabilityItem] { items.filter { $0.missingCount > 2 } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Checking your pantry…").tint(.orange)
                } else if items.isEmpty {
                    emptyState
                } else {
                    scrollContent
                }
            }
            .navigationTitle("Cook")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(.orange)
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onAppear { Task { await load() } }
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView (showsIndicators: false){
            LazyVStack(alignment: .leading, spacing: 24) {
                if !canCook.isEmpty {
                    sectionHeader("Ready to cook", icon: "checkmark.circle.fill", color: .green)
                    cardGrid(canCook)
                }

                if !almostThere.isEmpty {
                    Divider()
                    sectionHeader("Almost there", icon: "circle.dotted", color: .orange)
                    Text("Missing 1–2 ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, -20)
                    cardGrid(almostThere)
                }

                if !needMore.isEmpty {
                    Divider()
                    sectionHeader("Need more ingredients", icon: "cart.badge.plus", color: .secondary)
                    cardGrid(needMore)
                }
            }
            .padding(.vertical)
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.title3.bold())
            .foregroundStyle(color)
            .padding(.horizontal)
    }

    private func cardGrid(_ items: [CookabilityItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(items) { item in
                    NavigationLink(destination: RecipeDetailView(recipeId: item.id, recipeTitle: item.dishName)) {
                        RecipeCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.4))
            Text("Nothing saved yet")
                .font(.headline)
            Text("Share cooking videos using the Share button in TikTok.\nThey'll appear here sorted by what you can cook now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        items = (try? await APIClient.shared.getCookability()) ?? []
        isLoading = false
    }
}

// MARK: - Recipe card

private struct RecipeCard: View {
    let item: CookabilityItem
    private let cardWidth: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square thumbnail
            Rectangle()
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Group {
                        if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray5)
                            }
                        } else {
                            Color(.systemGray5)
                                .overlay(Image(systemName: "fork.knife")
                                    .foregroundStyle(.tertiary))
                        }
                    }
                )
                .clipped()

            // Info panel
            VStack(alignment: .leading, spacing: 8) {
                // Title — always reserves 2-line height so cards stay uniform
                Text(item.dishName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                    .foregroundStyle(.primary)

                // Tag chips — wrapping flow, no scroll
                if hasTags {
                    TagFlow(spacing: 5) {
                        if let effort = item.effort {
                            TagChip(effortTag: effort)
                        }
                        if let mins = item.timeMinutes {
                            TagChip(text: timeLabel(mins), icon: "clock", color: .blue)
                        }
                        if let servings = item.servings {
                            TagChip(text: "\(servings) serving\(servings == 1 ? "" : "s")",
                                    icon: "person.2", color: .purple)
                        }
                        if let protein = item.proteinLevel, protein == "high" {
                            TagChip(text: "High protein", icon: "bolt.fill", color: .green)
                        }
                        if let cal = item.calorieLevel {
                            TagChip(calorieTag: cal)
                        }
                        if let src = item.proteinSource {
                            TagChip(proteinSourceTag: src)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Missing ingredients warning
                if item.missingCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.badge.plus")
                            .font(.caption2)
                        Text("Missing: \(item.missingIngredients.prefix(3).joined(separator: ", "))\(item.missingIngredients.count > 3 ? "…" : "")")
                            .font(.caption2)
                            .lineLimit(2)
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(10)
        }
        .frame(width: cardWidth)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    private var hasTags: Bool {
        item.effort != nil || item.timeMinutes != nil || item.servings != nil
        || item.proteinLevel == "high"
        || item.calorieLevel != nil || item.proteinSource != nil
    }

    private func timeLabel(_ mins: Int) -> String {
        mins < 60 ? "\(mins) min" : "\(mins / 60)h \(mins % 60 > 0 ? "\(mins % 60)m" : "")"
    }
}

// MARK: - Tag chip

private struct TagChip: View {
    var text: String
    var icon: String? = nil
    var color: Color = .gray

    // Convenience init for effort tags
    init(effortTag: String) {
        switch effortTag.lowercased() {
        case "easy":   self.init(text: "Easy",   icon: "face.smiling",  color: .green)
        case "hard":   self.init(text: "Hard",   icon: "flame",         color: .red)
        default:       self.init(text: "Medium", icon: "minus.circle",  color: .orange)
        }
    }

    // Convenience init for calorie level tags
    init(calorieTag: String) {
        switch calorieTag.lowercased() {
        case "low":  self.init(text: "Low cal",  icon: "leaf",       color: .green)
        case "high": self.init(text: "High cal", icon: "flame.fill", color: .red)
        default:     self.init(text: "Med cal",  icon: "equal",      color: .orange)
        }
    }

    // Convenience init for protein source tags
    init(proteinSourceTag: String) {
        let icon: String
        switch proteinSourceTag.lowercased() {
        case "chicken":    icon = "bird"
        case "beef":       icon = "circle.fill"
        case "pork":       icon = "circle.fill"
        case "fish":       icon = "fish"
        case "seafood":    icon = "water.waves"
        case "eggs":       icon = "oval"
        case "lamb":       icon = "circle.fill"
        case "turkey":     icon = "bird"
        case "vegan":      icon = "leaf.fill"
        case "vegetarian": icon = "carrot"
        default:           icon = "fork.knife"
        }
        let label = proteinSourceTag.prefix(1).uppercased() + proteinSourceTag.dropFirst()
        self.init(text: label, icon: icon, color: .teal)
    }

    init(text: String, icon: String? = nil, color: Color = .gray) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Wrapping flow layout (iOS 16+)

private struct TagFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, in: proposal.replacingUnspecifiedDimensions().width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: .unspecified
            )
        }
    }

    private func layout(subviews: Subviews, in width: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: sz))
            x += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }
        return (frames, CGSize(width: width, height: y + rowHeight))
    }
}
