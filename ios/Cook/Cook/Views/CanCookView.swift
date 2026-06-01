import SwiftUI

struct CanCookView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var hasSetInitialTab = false

    // Grocery toast (existing)
    @State private var showGroceryToast = false

    // Cook / plan action
    @State private var cookPlanTarget: CookabilityItem?   // drives confirmationDialog
    @State private var servingsItem: CookabilityItem?     // drives ServingsSheet
    @State private var actionToastMessage: String?        // short confirmation toast

    private var canCook:    [CookabilityItem] { store.cookabilityItems.filter { $0.missingCount == 0 } }
    private var almostThere:[CookabilityItem] { store.cookabilityItems.filter { $0.missingCount > 0 && $0.missingCount <= 3 } }
    private var needMore:   [CookabilityItem] { store.cookabilityItems.filter { $0.missingCount > 3 } }

    private let tabTitles = ["Can Cook", "Almost There", "Need More"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topTabBar
                Divider()

                if isLoading && store.cookabilityItems.isEmpty {
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
            }
            .task { await load() }
            .onAppear { Task { await load() } }
            // ── Grocery toast ──────────────────────────────────────────────
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if let msg = actionToastMessage {
                        actionToastView(msg)
                    }
                    if showGroceryToast {
                        groceryToastView
                    }
                }
                .padding(.bottom, 28)
            }
            .animation(.spring(duration: 0.35), value: showGroceryToast)
            .animation(.spring(duration: 0.35), value: actionToastMessage)
            // ── Cook / Plan confirmation dialog ────────────────────────────
            .confirmationDialog(
                cookPlanTarget?.dishName ?? "",
                isPresented: Binding(
                    get: { cookPlanTarget != nil },
                    set: { if !$0 { cookPlanTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: cookPlanTarget,
            ) { target in
                if store.plannedRecipeIds.contains(target.id) {
                    Button("Cook Now") {
                        let t = target; cookPlanTarget = nil
                        servingsItem = t
                    }
                    Button("Remove from Plan", role: .destructive) {
                        let id = target.id; cookPlanTarget = nil
                        Task {
                            await store.removeFromPlanner(id: id)
                            await showActionToast("Removed from your plan")
                        }
                    }
                } else {
                    Button("Cook Now") {
                        let t = target; cookPlanTarget = nil
                        servingsItem = t
                    }
                    Button("Add to Plan") {
                        let id = target.id
                        let hasMissing = target.missingCount > 0
                        cookPlanTarget = nil
                        Task {
                            await store.addToPlanner(id: id)
                            if hasMissing {
                                _ = try? await APIClient.shared.generateGroceryList(recipeIds: [id])
                                await showActionToast("Added to plan · missing items → grocery list")
                            } else {
                                await showActionToast("Added to your meal plan")
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) { cookPlanTarget = nil }
            } message: { target in
                Text(store.plannedRecipeIds.contains(target.id) ? "This recipe is already in your plan." : "What would you like to do?")
            }
            // ── Servings sheet ─────────────────────────────────────────────
            .sheet(item: $servingsItem) { target in
                CookServingsSheet(mealName: target.dishName) { servings in
                    servingsItem = nil
                    Task {
                        await store.markCooked(recipeId: target.id, servings: servings)
                        await showActionToast("Cooked! Added to your history 🎉")
                    }
                }
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
                                    isPlanned: store.plannedRecipeIds.contains(item.id),
                                    onAddToGroceries: {
                                        Task {
                                            _ = try? await APIClient.shared.generateGroceryList(recipeIds: [item.id])
                                            showGroceryToast = true
                                            try? await Task.sleep(for: .seconds(2))
                                            showGroceryToast = false
                                        }
                                    },
                                    onCookPlanTapped: { cookPlanTarget = item }
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

    // MARK: - Toast views

    private var groceryToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "cart.badge.checkmark")
                .font(.subheadline.weight(.semibold))
            Text("Missing items added to grocery list")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.green.opacity(0.92), in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func actionToastView(_ message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.orange.opacity(0.92), in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
        await store.load()
        if !hasSetInitialTab {
            if !canCook.isEmpty          { selectedTab = 0 }
            else if !almostThere.isEmpty { selectedTab = 1 }
            else if !needMore.isEmpty    { selectedTab = 2 }
            else                         { selectedTab = 0 }
            hasSetInitialTab = true
        }
        isLoading = false
    }

    @MainActor
    private func showActionToast(_ message: String) async {
        withAnimation { actionToastMessage = message }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { actionToastMessage = nil }
    }
}

// MARK: - Vertical recipe card

struct VerticalRecipeCard: View {
    let item: CookabilityItem
    var isPlanned: Bool = false
    var onAddToGroceries: () -> Void = {}
    var onCookPlanTapped: () -> Void = {}

    @State private var isFavorited: Bool

    init(item: CookabilityItem,
         isPlanned: Bool = false,
         onAddToGroceries: @escaping () -> Void = {},
         onCookPlanTapped: @escaping () -> Void = {}) {
        self.item = item
        self.isPlanned = isPlanned
        self.onAddToGroceries = onAddToGroceries
        self.onCookPlanTapped = onCookPlanTapped
        self._isFavorited = State(initialValue: item.isFavorited)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Thumbnail — square with overlays
            Rectangle()
                .aspectRatio(1, contentMode: .fit)
                .overlay(thumbnailContent)
                .clipped()
                // Missing badge — top left
                .overlay(alignment: .topLeading) {
                    if item.missingCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 11, weight: .bold))
                            if item.missingCount <= 3 {
                                Text("Missing \(item.missingIngredients.joined(separator: ", "))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(2)
                            } else {
                                Text("Missing \(item.missingCount) ingredients")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(10)
                    }
                }
                // Action buttons — bottom right
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 10) {
                        // Favorite
                        CardActionButton(
                            systemImage: isFavorited ? "heart.fill" : "heart",
                            color: isFavorited ? .red : .white
                        ) {
                            let newValue = !isFavorited
                            isFavorited = newValue
                            Task {
                                do {
                                    try await APIClient.shared.setFavorite(id: item.id, isFavorited: newValue)
                                } catch {
                                    isFavorited = !newValue
                                }
                            }
                        }

                        // Grocery (only when missing ingredients)
                        if item.missingCount > 0 {
                            CardActionButton(systemImage: "cart.badge.plus") {
                                onAddToGroceries()
                            }
                        }

                        // Cook / Plan — replaces trash
                        CardActionButton(
                            systemImage: isPlanned ? "list.bullet.clipboard.fill" : "list.bullet.clipboard",
                            color: isPlanned ? .orange : .white
                        ) {
                            onCookPlanTapped()
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
                        if let mt = item.mealType { TagChip(mealTypeTag: mt) }
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
                        if let src = item.proteinSource { TagChip(proteinSourceTag: src) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        item.mealType != nil || item.timeMinutes != nil || item.servings != nil
        || item.proteinLevel == "high" || item.proteinSource != nil
    }

    private func timeLabel(_ mins: Int) -> String {
        mins < 60 ? "\(mins) min" : "\(mins / 60)h \(mins % 60 > 0 ? "\(mins % 60)m" : "")"
    }
}

// MARK: - Servings sheet for CanCookView (self-contained)

private struct CookServingsSheet: View {
    let mealName: String
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var servings = 2

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                } header: {
                    Text(mealName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                } footer: {
                    Text("Logged to your cooking history and weekly stats.")
                }
            }
            .navigationTitle("Mark as Cooked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onConfirm(servings) }
                        .tint(.orange)
                }
            }
        }
        .presentationDetents([.medium])
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

    init(mealTypeTag: String) {
        switch mealTypeTag.lowercased() {
        case "breakfast": self.init(text: "Breakfast", icon: "sunrise.fill",  color: .orange)
        case "lunch":     self.init(text: "Lunch",     icon: "sun.max.fill",  color: .yellow)
        case "dessert":   self.init(text: "Dessert",   icon: "birthday.cake.fill", color: .pink)
        default:          self.init(text: "Dinner",    icon: "moon.stars.fill", color: .indigo)
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
