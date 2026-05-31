import SwiftUI

struct KitchenStatsView: View {
    @State private var stats: KitchenStats?
    @State private var isLoading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            if isLoading && stats == nil {
                ProgressView("Loading stats…").tint(.orange)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let s = stats {
                VStack(alignment: .leading, spacing: 24) {

                    statSection("This Week", items: [
                        StatCard.Item(label: "Meals Cooked",       display: "\(s.mealsThisWeek)",             icon: "flame.fill",         color: .orange),
                        StatCard.Item(label: "Recipes Cooked",     display: "\(s.recipesThisWeek)",           icon: "fork.knife",          color: .red),
                        StatCard.Item(label: "Meals Planned",      display: "\(s.plannedCount)",              icon: "checklist",           color: .blue),
                        StatCard.Item(label: "Ingredients Used",   display: "\(s.ingredientsUsedThisWeek)",   icon: "leaf.fill",           color: .green),
                        StatCard.Item(label: "Money Spent",        display: "$0",                             icon: "dollarsign.circle.fill", color: .mint,
                                      note: "Coming soon"),
                    ])

                    statSection("Your Kitchen", items: [
                        StatCard.Item(label: "Pantry Items",       display: "\(s.pantryItems)",               icon: "cabinet.fill",        color: .brown),
                        StatCard.Item(label: "Unique Recipes",     display: "\(s.uniqueRecipesCooked)",       icon: "star.fill",           color: .yellow),
                        StatCard.Item(label: "All-Time Cooked",    display: "\(s.totalCookedAllTime)",        icon: "trophy.fill",         color: .orange),
                        StatCard.Item(label: "Recipes Saved",      display: "\(s.savedRecipes)",              icon: "bookmark.fill",       color: .indigo),
                    ])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            } else {
                emptyState
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: - Section builder

    private func statSection(_ title: String, items: [StatCard.Item]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(items) { item in
                    StatCard(item: item)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.4))
            Text("No stats yet")
                .font(.headline)
            Text("Start cooking to see your kitchen stats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding()
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        if let s = try? await APIClient.shared.getKitchenStats() { stats = s }
        isLoading = false
    }
}

// MARK: - Stat card

private struct StatCard: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let display: String     // formatted value to show (number or "$0" etc.)
        let icon: String
        let color: Color
        var note: String? = nil // optional small note e.g. "Coming soon"
    }

    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundStyle(item.color)

            Text(item.display)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(item.note != nil ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let note = item.note {
                    Text(note)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
