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
                        StatItem("Meals Cooked",   value: s.recipesThisWeek,   icon: "flame.fill",         color: .orange),
                        StatItem("Servings Made",  value: s.servingsThisWeek,  icon: "person.2.fill",       color: .purple),
                        StatItem("Meals Planned",  value: s.plannedCount,      icon: "checklist",           color: .blue),
                        StatItem("Recipes Saved",  value: s.savedRecipes,      icon: "bookmark.fill",       color: .indigo),
                    ])

                    statSection("Your Kitchen", items: [
                        StatItem("Pantry Items",   value: s.pantryItems,        icon: "cabinet.fill",        color: .green),
                        StatItem("All-Time Cooked", value: s.totalCookedAllTime, icon: "trophy.fill",         color: .yellow),
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

    private func statSection(_ title: String, items: [StatItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
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
        if let s = try? await APIClient.shared.getKitchenStats() {
            stats = s
        }
        isLoading = false
    }
}

// MARK: - Stat item model

struct StatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let icon: String
    let color: Color

    init(_ label: String, value: Int, icon: String, color: Color) {
        self.label = label
        self.value = value
        self.icon  = icon
        self.color = color
    }
}

// MARK: - Stat card view

private struct StatCard: View {
    let item: StatItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundStyle(item.color)

            Text("\(item.value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(item.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
