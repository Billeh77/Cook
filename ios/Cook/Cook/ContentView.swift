import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1 — Home (Can Cook)
            CanCookView()
                .tabItem { Label("Cook", systemImage: "flame.fill") }

            // Tab 2 — Grocery List
            GroceryListView()
                .tabItem { Label("Grocery", systemImage: "cart.fill") }

            // Tab 3 — Pantry / Inventory
            InventoryView()
                .tabItem { Label("Pantry", systemImage: "archivebox.fill") }

            // Tab 4 — Saved Recipes (album grid)
            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
        }
        .tint(.orange)
    }
}

