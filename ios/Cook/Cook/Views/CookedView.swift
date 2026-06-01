import SwiftUI

// MARK: - Cooked meals history view

struct CookedView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var isLoading = false
    @State private var showLogSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header ────────────────────────────────────────────────────
                HStack {
                    Text("COOKED")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !store.history.isEmpty {
                        Text("\(store.history.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    }
                    Spacer()
                    Button { showLogSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)

                // ── Content ───────────────────────────────────────────────────
                if isLoading && store.history.isEmpty {
                    ProgressView().tint(.orange)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if store.history.isEmpty {
                    cookedEmptyState
                } else {
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
        .sheet(isPresented: $showLogSheet, onDismiss: { Task { await store.load() } }) {
            LogCookedSheet { recipeId, servings in
                showLogSheet = false
                Task { await store.logDirectly(recipeId: recipeId, servings: servings) }
            }
        }
    }

    // MARK: - Empty state

    private var cookedEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange.opacity(0.4))
            Text("No meals cooked yet")
                .font(.headline)
            Text("Every time you cook a recipe from your planner,\nit appears here. You can also log a meal directly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showLogSheet = true } label: {
                Label("Log a Cooked Meal", systemImage: "plus")
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

// MARK: - History row

private struct HistoryRow: View {
    let entry: CookingLogEntry
    @EnvironmentObject var store: RecipeStore

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
