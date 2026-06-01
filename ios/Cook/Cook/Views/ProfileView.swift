import SwiftUI

// MARK: - Profile page (tab 4)

struct ProfileView: View {
    @State private var selectedTab = 0
    @State private var stats: KitchenStats?
    @State private var showAvatarEditor = false

    private let tabTitles = ["Planner", "Cooked", "Saved"]
    private let tabIcons  = ["calendar", "flame.fill", "bookmark.fill"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                profileHeader
                topTabBar
                Divider()
                TabView(selection: $selectedTab) {
                    MealPlannerView()
                        .tag(0)
                    CookedView()
                        .tag(1)
                    SavedAlbumsContent()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadStats() }
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 28) {

            // ── Identity ──────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                avatarView
                Text("\(AuthManager.shared.firstName.prefix(1).uppercased() + AuthManager.shared.firstName.dropFirst())'s Kitchen")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }

            // ── Stats ─────────────────────────────────────────────────────────
            if let s = stats {
                statsPanel(s)
            } else {
                statsPanel(.placeholder)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
    }

    // MARK: - Minimalist stats (2 × 2, no cards)

    private func statsPanel(_ s: KitchenStats) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 5) {
            GridRow {
                statItem(value: "\(s.mealsThisWeek)",      label: "meals cooked this week", icon: "flame.fill",    color: .orange)
            }
            GridRow {
                statItem(value: "\(s.savedRecipes)",       label: "recipes saved",    icon: "bookmark.fill", color: .indigo)
            }
            GridRow {
                statItem(value: "\(s.totalCookedAllTime)",  label: "cooking sessions", icon: "trophy.fill",   color: .orange)
            }
            GridRow {
                statItem(value: "\(s.uniqueRecipesCooked)", label: "unique recipes learned",  icon: "star.fill",     color: .yellow)
            }
        }
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        Button { showAvatarEditor = true } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let url = AuthManager.shared.avatarURL {
                        CachedAsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            chefPlaceholder
                        }
                    } else {
                        chefPlaceholder
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(.orange.opacity(0.35), lineWidth: 2.5))

                // Camera badge signals it's tappable
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                    .background(Circle().fill(.background).padding(2))
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAvatarEditor) {
            AvatarEditorView()
        }
    }

    private var chefPlaceholder: some View {
        ZStack {
            Color.orange.opacity(0.1)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange.opacity(0.45))
        }
    }

    // MARK: - Two-tab bar

    private var topTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = i }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: tabIcons[i])
                                .font(.system(size: 13, weight: selectedTab == i ? .semibold : .regular))
                                .foregroundStyle(selectedTab == i ? Color.orange : .secondary)
                            Text(tabTitles[i])
                                .font(.subheadline.weight(selectedTab == i ? .semibold : .regular))
                                .foregroundStyle(selectedTab == i ? .primary : .secondary)
                        }
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

    // MARK: - Data

    private func loadStats() async {
        if let s = try? await APIClient.shared.getKitchenStats() { stats = s }
    }
}

// MARK: - Placeholder for skeleton state

private extension KitchenStats {
    static let placeholder = KitchenStats(
        mealsThisWeek: 12,
        recipesThisWeek: 5,
        plannedCount: 3,
        ingredientsUsedThisWeek: 0,
        moneySpentThisWeek: 0,
        pantryItems: 0,
        uniqueRecipesCooked: 47,
        totalCookedAllTime: 89,
        savedRecipes: 32
    )
}
