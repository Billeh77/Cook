import SwiftUI

struct CanCookView: View {
    @State private var items: [CookabilityItem] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var hasSetInitialTab = false
    @State private var groceryConfirmation: String? = nil

    private var canCook:    [CookabilityItem] { items.filter { $0.missingCount == 0 } }
    private var almostThere:[CookabilityItem] { items.filter { $0.missingCount > 0 && $0.missingCount <= 3 } }
    private var needMore:   [CookabilityItem] { items.filter { $0.missingCount > 3 } }

    private let tabTitles = ["Can Cook", "Almost There", "Need More"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topTabBar
                Divider()

                if isLoading && items.isEmpty {
                    Spacer()
                    ProgressView("Checking your pantry…").tint(.orange)
                    Spacer()
                } else {
                    TabView(selection: $selectedTab) {
                        recipePage(
                            canCook,
                            emptyIcon: "flame",
                            emptyTitle: "Nothing ready yet",
                            emptyMessage: "Share a cooking video from TikTok or Instagram to get started."
                        )
                        .tag(0)

                        recipePage(
                            almostThere,
                            emptyIcon: "circle.dotted",
                            emptyTitle: "Nothing close",
                            emptyMessage: "Stock your pantry and save more recipes to see what's almost ready."
                        )
                        .tag(1)

                        recipePage(
                            needMore,
                            emptyIcon: "cart.badge.plus",
                            emptyTitle: "No recipes here",
                            emptyMessage: "Save more recipes to populate this list."
                        )
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Cook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Cook")
                            .font(.headline.bold())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(.orange)
                }
            }
            .task { await load() }
            .onAppear { Task { await load() } }
            .alert("Added to Grocery List", isPresented: Binding(
                get: { groceryConfirmation != nil },
                set: { if !$0 { groceryConfirmation = nil } }
            )) {
                Button("OK") { groceryConfirmation = nil }
            } message: {
                Text(groceryConfirmation ?? "")
            }
        }
    }

    // MARK: - Top tab bar

    private var topTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = i }
                } label: {
                    VStack(spacing: 6) {
                        Text(tabTitles[i])
                            .font(.subheadline.weight(selectedTab == i ? .semibold : .regular))
                            .foregroundStyle(selectedTab == i ? .primary : .secondary)
                        Rectangle()
                            .frame(height: 2)
                            .foregroundStyle(selectedTab == i ? Color.orange : Color.clear)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recipe page

    private func recipePage(
        _ recipes: [CookabilityItem],
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String
    ) -> some View {
        Group {
            if recipes.isEmpty {
                emptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(recipes) { item in
                            NavigationLink(destination: RecipeDetailView(
                                recipeId: item.id,
                                recipeTitle: item.dishName,
                                missingIngredients: item.missingIngredients
                            )) {
                                VerticalRecipeCard(
                                    item: item,
                                    onDelete: {
                                        Task {
                                            try? await APIClient.shared.deleteRecipe(id: item.id)
                                            await load()
                                        }
                                    },
                                    onAddToGroceries: {
                                        Task {
                                            if let added = try? await APIClient.shared.generateGroceryList(recipeIds: [item.id]) {
                                                let n = added.count
                                                groceryConfirmation = n > 0
                                                    ? "\(n) item\(n == 1 ? "" : "s") added to your grocery list"
                                                    : "Ingredients already on your grocery list"
                                            }
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.4))
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        items = (try? await APIClient.shared.getCookability()) ?? []
        // Only auto-select on first load — never reset the tab the user is on
        if !hasSetInitialTab {
            if !canCook.isEmpty          { selectedTab = 0 }
            else if !almostThere.isEmpty { selectedTab = 1 }
            else if !needMore.isEmpty    { selectedTab = 2 }
            else                         { selectedTab = 0 }
            hasSetInitialTab = true
        }
        isLoading = false
    }
}

// MARK: - Vertical recipe card

struct VerticalRecipeCard: View {
    let item: CookabilityItem
    var onDelete: () -> Void = {}
    var onAddToGroceries: () -> Void = {}

    @State private var isFavorited: Bool

    init(item: CookabilityItem,
         onDelete: @escaping () -> Void = {},
         onAddToGroceries: @escaping () -> Void = {}) {
        self.item = item
        self.onDelete = onDelete
        self.onAddToGroceries = onAddToGroceries
        self._isFavorited = State(initialValue: item.isFavorited)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Thumbnail — square with action buttons overlaid bottom-right
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(thumbnailContent)
                    .clipped()

                HStack(spacing: 10) {
                    CardActionButton(
                        systemImage: isFavorited ? "heart.fill" : "heart",
                        color: isFavorited ? .red : .white
                    ) {
                        let newValue = !isFavorited
                        isFavorited = newValue          // optimistic
                        Task {
                            do {
                                try await APIClient.shared.setFavorite(id: item.id, isFavorited: newValue)
                            } catch {
                                isFavorited = !newValue // revert on failure
                            }
                        }
                    }

                    if item.missingCount > 0 {
                        CardActionButton(systemImage: "cart.badge.plus") {
                            onAddToGroceries()
                        }
                    }

                    CardActionButton(systemImage: "trash") {
                        onDelete()
                    }
                }
                .padding(12)
            }

            // Info panel
            VStack(alignment: .leading, spacing: 10) {

                Text(item.dishName)
                    .font(.headline)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(.primary)

                if hasTags {
                    TagFlow(spacing: 5) {
                        if let effort = item.effort {
                            TagChip(effortTag: effort)
                        }
                        if let mins = item.timeMinutes {
                            TagChip(text: timeLabel(mins), icon: "clock", color: .blue)
                        }
                        if let servings = item.servings {
                            TagChip(
                                text: "\(servings) serving\(servings == 1 ? "" : "s")",
                                icon: "person.2",
                                color: .purple
                            )
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

                if item.missingCount > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "cart.badge.plus").font(.caption2)
                        if item.missingCount <= 3 {
                            // Almost there — show exactly which ingredients
                            Text("Missing: \(item.missingIngredients.joined(separator: ", "))")
                                .font(.caption2)
                                .lineLimit(2)
                        } else {
                            // Need more — just show the count
                            Text("Missing \(item.missingCount) ingredients")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray5)
            }
        } else {
            Color(.systemGray5)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                )
        }
    }

    private var hasTags: Bool {
        item.effort != nil || item.timeMinutes != nil || item.servings != nil
        || item.proteinLevel == "high" || item.calorieLevel != nil || item.proteinSource != nil
    }

    private func timeLabel(_ mins: Int) -> String {
        mins < 60 ? "\(mins) min" : "\(mins / 60)h \(mins % 60 > 0 ? "\(mins % 60)m" : "")"
    }
}

// MARK: - Card action button (overlaid on image)

struct CardActionButton: View {
    let systemImage: String
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Tag chip

struct TagChip: View {
    var text: String
    var icon: String? = nil
    var color: Color = .gray

    init(effortTag: String) {
        switch effortTag.lowercased() {
        case "easy":  self.init(text: "Easy",   icon: "face.smiling", color: .green)
        case "hard":  self.init(text: "Hard",   icon: "flame",        color: .red)
        default:      self.init(text: "Medium", icon: "minus.circle", color: .orange)
        }
    }

    init(calorieTag: String) {
        switch calorieTag.lowercased() {
        case "low":  self.init(text: "Low cal",  icon: "leaf",       color: .green)
        case "high": self.init(text: "High cal", icon: "flame.fill", color: .red)
        default:     self.init(text: "Med cal",  icon: "equal",      color: .orange)
        }
    }

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
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            }
            Text(text).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Wrapping flow layout (iOS 16+)

struct TagFlow: Layout {
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
