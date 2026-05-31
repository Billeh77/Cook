import SwiftUI

// MARK: - Profile page (tab 4)

struct ProfileView: View {
    @State private var selectedTab = 0
    private let tabTitles = ["Stats", "Planner", "Saved"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                profileHeader
                topTabBar
                Divider()
                TabView(selection: $selectedTab) {
                    KitchenStatsView()
                        .tag(0)
                    MealPlannerView()
                        .tag(1)
                    SavedAlbumsContent()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            avatarView
            Text("\(AuthManager.shared.firstName)'s Kitchen")
                .font(.title2.bold())
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
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
            .frame(width: 90, height: 90)
            .clipShape(Circle())
            .overlay(Circle().stroke(.orange.opacity(0.35), lineWidth: 2.5))

            // Kitchen badge
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
                .background(Circle().fill(.background).padding(2))
                .offset(x: 4, y: 4)
        }
    }

    private var chefPlaceholder: some View {
        ZStack {
            Color.orange.opacity(0.1)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.orange.opacity(0.45))
        }
    }

    // MARK: - Top tab bar (same design as CanCookView)

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
}
