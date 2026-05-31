import SwiftUI

struct MealPlannerView: View {
    @State private var planned: [PlannedMealItem] = []
    @State private var history: [CookingLogEntry] = []
    @State private var isLoading = false
    @State private var showAddSheet = false

    // Cook confirmation state
    @State private var cookingMeal: PlannedMealItem?
    @State private var servingsInput = 2
    @State private var showCookConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {

                // ── Up Next ──────────────────────────────────────────────────
                Section {
                    if isLoading && planned.isEmpty {
                        ProgressView().tint(.orange)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    } else if planned.isEmpty {
                        plannerEmptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(planned) { meal in
                                PlannerRow(meal: meal) {
                                    cookingMeal = meal
                                    servingsInput = 2
                                    showCookConfirm = true
                                }
                                if meal.id != planned.last?.id { Divider().padding(.leading, 70) }
                            }
                        }
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                    }
                } header: {
                    sectionHeader(title: "Up Next", count: planned.count) {
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // ── History ──────────────────────────────────────────────────
                if !history.isEmpty {
                    Section {
                        VStack(spacing: 0) {
                            ForEach(history) { entry in
                                HistoryRow(entry: entry)
                                if entry.id != history.last?.id { Divider().padding(.leading, 70) }
                            }
                        }
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                    } header: {
                        sectionHeader(title: "Cooked", count: history.count)
                    }
                }

                Spacer().frame(height: 32)
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showAddSheet, onDismiss: { Task { await loadPlanned() } }) {
            AddToPlannerSheet(existingIds: Set(planned.map { $0.recipeId }))
        }
        .sheet(isPresented: $showCookConfirm) {
            if let meal = cookingMeal {
                ServingsSheet(
                    mealName: meal.dishName,
                    servings: $servingsInput
                ) {
                    showCookConfirm = false
                    Task { await markCooked(meal: meal, servings: servingsInput) }
                } onCancel: {
                    showCookConfirm = false
                }
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(
        title: String,
        count: Int,
        trailing: (() -> some View)? = nil
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
            trailing?()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.background)
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
            Button {
                showAddSheet = true
            } label: {
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
        await loadPlanned()
        await loadHistory()
        isLoading = false
    }

    private func loadPlanned() async {
        if let p = try? await APIClient.shared.getPlannedMeals() { planned = p }
    }

    private func loadHistory() async {
        if let h = try? await APIClient.shared.getCookingHistory() { history = h }
    }

    private func markCooked(meal: PlannedMealItem, servings: Int) async {
        // Optimistically remove from planner
        planned.removeAll { $0.id == meal.id }

        if let entry = try? await APIClient.shared.logCooked(recipeId: meal.recipeId, servings: servings) {
            history.insert(entry, at: 0)
        } else {
            // Revert if API call failed
            if let p = try? await APIClient.shared.getPlannedMeals() { planned = p }
        }
    }
}

// MARK: - Planner row

private struct PlannerRow: View {
    let meal: PlannedMealItem
    let onCheck: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let urlStr = meal.thumbnailURL, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: "fork.knife").foregroundStyle(.tertiary))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.dishName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(meal.platform.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Check button
            Button(action: onCheck) {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: CookingLogEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 52, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.dishName)
                    .font(.subheadline.weight(.semibold))
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

// MARK: - Servings confirmation sheet

private struct ServingsSheet: View {
    let mealName: String
    @Binding var servings: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

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
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onConfirm() }
                        .tint(.orange)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add to planner sheet

struct AddToPlannerSheet: View {
    let existingIds: Set<String>   // recipe IDs already in planner

    @Environment(\.dismiss) private var dismiss
    @State private var allRecipes: [RecipeListItem] = []
    @State private var selected = Set<String>()
    @State private var isLoading = true
    @State private var isAdding = false

    private var available: [RecipeListItem] { allRecipes.filter { !existingIds.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
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
                                Text("\(recipe.ingredientCount) ingredients")
                                    .font(.caption).foregroundStyle(.secondary)
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
                            for id in selected {
                                try? await APIClient.shared.addToPlanner(recipeId: id)
                            }
                            dismiss()
                        }
                    }
                    .disabled(selected.isEmpty || isAdding)
                    .tint(.orange)
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
