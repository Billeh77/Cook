import SwiftUI

// MARK: - Cooked meals history view

struct CookedView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var isLoading = false
    @State private var showLogSheet = false

    // MARK: - Timeline grouping

    private var groupedByDay: [(label: String, entries: [CookingLogEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.history) { entry -> Date in
            let date = parsedDate(entry.cookedAt)
            return calendar.startOfDay(for: date)
        }
        return grouped
            .sorted { $0.key > $1.key }               // most recent day first
            .map { date, entries in
                (
                    label: dayLabel(for: date, calendar: calendar),
                    entries: entries.sorted { $0.cookedAt > $1.cookedAt }
                )
            }
    }

    private func parsedDate(_ isoString: String) -> Date {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: isoString)
            ?? ISO8601DateFormatter().date(from: isoString)
            ?? Date()
    }

    private func dayLabel(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date)     { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"     // e.g. "Monday, Jun 1"
        return fmt.string(from: date)
    }

    // MARK: - Body

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
                } else if store.history.isEmpty && !store.historyHasMore {
                    cookedEmptyState
                } else if store.history.isEmpty && store.historyHasMore {
                    // Entries exist but not in the last 7 days
                    nothingRecentState
                } else {
                    timeline
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

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(groupedByDay, id: \.label) { group in
                VStack(alignment: .leading, spacing: 8) {

                    // Day header
                    Text(group.label.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    // Rows for this day
                    VStack(spacing: 0) {
                        ForEach(group.entries) { entry in
                            HistoryRow(entry: entry)
                            if entry.id != group.entries.last?.id {
                                Divider().padding(.leading, 80)
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }
            }

            // ── Load more ─────────────────────────────────────────────────────
            if store.historyHasMore {
                Button {
                    Task { await store.loadMoreHistory() }
                } label: {
                    Group {
                        if store.historyIsLoadingMore {
                            ProgressView().tint(.orange)
                        } else {
                            Label("Load previous weeks", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .disabled(store.historyIsLoadingMore)
            }
        }
    }

    // MARK: - Empty / no-recent states

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

    private var nothingRecentState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(.orange.opacity(0.4))
            Text("Nothing cooked this week")
                .font(.headline)
            Text("You have older cooking sessions saved.\nLoad them below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await store.loadMoreHistory() }
            } label: {
                Label("Load previous weeks", systemImage: "clock.arrow.circlepath")
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
                    Text(formattedTime(entry.cookedAt))
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

    /// Since the date is shown in the section header, show time of day here.
    private func formattedTime(_ isoString: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString) {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            fmt.dateStyle = .none
            return fmt.string(from: date)
        }
        return ""
    }
}
