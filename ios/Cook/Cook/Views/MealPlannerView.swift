import SwiftUI

// MARK: - Active sheet discriminator

private enum ActiveSheet: Identifiable {
    case addMeals
    case cookConfirm(CookabilityItem)   // uses CookabilityItem — missingCount is always correct
    case logCooked

    var id: String {
        switch self {
        case .addMeals:             return "addMeals"
        case .cookConfirm(let m):   return "cook-\(m.id)"
        case .logCooked:            return "logCooked"
        }
    }
}

// MARK: - Meal planner view

struct MealPlannerView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var isLoading = false
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // ── Up Next ───────────────────────────────────────────────────
                sectionHeader(title: "Up Next", count: store.plannedItems.count) {
                    Button { activeSheet = .addMeals } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }

                if isLoading && store.plannedItems.isEmpty {
                    ProgressView().tint(.orange)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if store.plannedItems.isEmpty {
                    plannerEmptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.plannedItems) { meal in
                            PlannerRow(
                                meal: meal,
                                onCheck: { activeSheet = .cookConfirm(meal) },
                                onRemove: {
                                    Task { await store.removeFromPlanner(id: meal.id) }
                                }
                            )
                            if meal.id != store.plannedItems.last?.id {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }

                // ── History ───────────────────────────────────────────────────
                // Header always visible so user can log a cooked meal directly
                sectionHeader(title: "Cooked", count: store.history.count) {
                    Button { activeSheet = .logCooked } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }

                if !store.history.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(store.history) { entry in
                            HistoryRow(entry: entry)
                            if entry.id != store.history.last?.id {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 32)
            }
            .padding(.top, 8)
        }
        .refreshable { await load() }
        .task { await load() }
        // Single sheet driven by the enum — no competing presenters
        .sheet(item: $activeSheet, onDismiss: { Task { await store.load() } }) { sheet in
            switch sheet {
            case .addMeals:
                AddToPlannerSheet()
            case .cookConfirm(let meal):
                ServingsSheet(mealName: meal.dishName) { servings in
                    activeSheet = nil
                    Task { await store.markCooked(recipeId: meal.id, servings: servings) }
                }
            case .logCooked:
                LogCookedSheet { recipeId, servings in
                    activeSheet = nil
                    Task { await store.logDirectly(recipeId: recipeId, servings: servings) }
                }
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader<T: View>(
        title: String,
        count: Int,
        @ViewBuilder trailing: () -> T = { EmptyView() }
    ) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange, in: Capsule())
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    // MARK: - Empty state

    private var plannerEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
                .foregroundStyle(.orange.opacity(0.4))
            Text("Nothing planned yet")
                .font(.headline)
            Text("Tap + to add meals you want to cook next.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { activeSheet = .addMeals } label: {
                Label("Add Meals", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.orange, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        await store.load()
        isLoading = false
    }
}

// MARK: - Planner row

private struct PlannerRow: View {
    let meal: CookabilityItem   // backed by cookability data — missingCount is always accurate
    let onCheck: () -> Void
    let onRemove: () -> Void

    private var statusText: String {
        if meal.missingCount == 0 { return "Ready to cook now" }
        if meal.missingCount <= 3 { return "Missing \(meal.missingIngredients.joined(separator: ", "))" }
        return "Missing \(meal.missingCount) ingredients"
    }

    private var statusColor: Color {
        meal.missingCount == 0 ? .green : .orange
    }

    var body: some View {
        NavigationLink {
            RecipeDetailView(recipeId: meal.id, recipeTitle: meal.dishName,
                             missingIngredients: meal.missingIngredients)
        } label: {
            HStack(spacing: 14) {
                // Thumbnail
                Group {
                    if let urlStr = meal.thumbnailURL, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                            placeholder: { Color(.systemGray5) }
                    } else {
                        Color(.systemGray5)
                            .overlay(Image(systemName: "fork.knife").foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.dishName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                // Remove button — .borderless prevents NavigationLink from capturing the tap
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)

                // Mark as cooked
                Button(action: onCheck) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: CookingLogEntry
    @EnvironmentObject var store: RecipeStore

    /// Best-available thumbnail: from cookability store (always current) or
    /// from the log entry itself (populated by backend for new entries).
    private var thumbnailURL: String? {
        store.cookabilityItems.first { $0.id == entry.recipeId }?.thumbnailURL
            ?? entry.thumbnailURL
    }

    var body: some View {
        NavigationLink {
            RecipeDetailView(recipeId: entry.recipeId, recipeTitle: entry.dishName)
        } label: {
            HStack(spacing: 14) {
                // Thumbnail with green checkmark badge
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let urlStr = thumbnailURL, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color(.systemGray5) }
                        } else {
                            Color(.systemGray5)
                                .overlay(Image(systemName: "fork.knife").foregroundStyle(.tertiary))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white, .green)
                        .offset(x: 5, y: 5)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.dishName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(formattedDate(entry.cookedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(entry.servings) serving\(entry.servings == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(_ isoString: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString) {
            if Calendar.current.isDateInToday(date) { return "Today" }
            if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            return fmt.string(from: date)
        }
        return isoString
    }
}

// MARK: - Servings confirmation sheet (self-contained state)

private struct ServingsSheet: View {
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
                    Text("Used to track your weekly cooking stats.")
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

// MARK: - Add to planner sheet

struct AddToPlannerSheet: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<String>()
    @State private var isAdding = false

    /// Recipes not already on the plan, ordered by ascending missing count (cookable first).
    private var available: [CookabilityItem] {
        store.cookabilityItems
            .filter { !store.plannedRecipeIds.contains($0.id) }
            .sorted { $0.missingCount < $1.missingCount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cookabilityItems.isEmpty {
                    ProgressView("Loading recipes…").tint(.orange)
                } else if available.isEmpty {
                    Text("All your recipes are already planned.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List(available) { recipe in
                        HStack(spacing: 12) {
                            Image(systemName: selected.contains(recipe.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(recipe.id) ? .orange : Color(.tertiaryLabel))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.dishName).font(.body)
                                // Readiness instead of raw ingredient count
                                Group {
                                    if recipe.missingCount == 0 {
                                        Text("Ready to cook")
                                            .foregroundStyle(.green)
                                    } else if recipe.missingCount <= 3 {
                                        Text("Missing \(recipe.missingIngredients.joined(separator: ", "))")
                                            .foregroundStyle(.orange)
                                    } else {
                                        Text("Missing \(recipe.missingCount) ingredients")
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .font(.caption)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selected.contains(recipe.id) { selected.remove(recipe.id) }
                            else { selected.insert(recipe.id) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Plan Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "Adding…" : "Add\(selected.isEmpty ? "" : " (\(selected.count))")") {
                        isAdding = true
                        Task {
                            // Add all selected recipes to the plan
                            for id in selected {
                                await store.addToPlanner(id: id)
                            }
                            // Generate grocery list for any that have missing ingredients
                            let idsWithMissing = selected.filter { id in
                                store.cookabilityItems.first { $0.id == id }?.missingCount ?? 0 > 0
                            }
                            if !idsWithMissing.isEmpty {
                                _ = try? await APIClient.shared.generateGroceryList(recipeIds: Array(idsWithMissing))
                            }
                            dismiss()
                        }
                    }
                    .disabled(selected.isEmpty || isAdding)
                    .tint(.orange)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Log cooked directly (skips planning step)
// Two-screen NavigationStack inside the sheet: recipe list → servings page.

struct LogCookedSheet: View {
    /// Called with (recipeId, servings) when the user confirms a cook.
    let onLog: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allRecipes: [RecipeListItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading recipes…").tint(.orange)
                } else if allRecipes.isEmpty {
                    Text("No saved recipes yet.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List(allRecipes) { recipe in
                        NavigationLink {
                            LogServingsPage(recipe: recipe) { servings in
                                onLog(recipe.id, servings)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.dishName).font(.body)
                                Text("\(recipe.ingredientCount) ingredients")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Log Cooked Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                allRecipes = (try? await APIClient.shared.getRecipes()) ?? []
                isLoading = false
            }
        }
        .presentationDetents([.large])
    }
}

private struct LogServingsPage: View {
    let recipe: RecipeListItem
    let onConfirm: (Int) -> Void

    @State private var servings = 2

    var body: some View {
        Form {
            Section {
                Stepper("Servings: \(servings)", value: $servings, in: 1...20)
            } header: {
                Text(recipe.dishName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            } footer: {
                Text("Logged to your cooking history and weekly stats.")
            }
        }
        .navigationTitle("How many servings?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onConfirm(servings) }
                    .tint(.orange)
            }
        }
    }
}
