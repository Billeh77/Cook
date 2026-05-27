import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1 — Home (Can Cook) — placeholder until Stage 4
            NavigationStack {
                CanCookPlaceholderView()
            }
            .tabItem { Label("Cook", systemImage: "flame.fill") }

            // Tab 2 — Grocery List
            GroceryListView()
                .tabItem { Label("Grocery", systemImage: "cart.fill") }

            // Tab 3 — Pantry / Inventory
            InventoryView()
                .tabItem { Label("Pantry", systemImage: "archivebox.fill") }

            // Tab 4 — Saved Recipes
            RecipesListView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
        }
        .tint(.orange)
    }
}

// MARK: - Placeholder for Stage 4

private struct CanCookPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.5))
            Text("Can Cook")
                .font(.title2.bold())
            Text("Coming soon — recipes you can make\nwith what's already in your pantry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .navigationTitle("Cook")
    }
}
