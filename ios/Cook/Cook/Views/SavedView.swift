import SwiftUI

// MARK: - SavedView wrapper

struct SavedView: View {
    var body: some View {
        NavigationStack {
            SavedAlbumsContent()
                .navigationTitle("Saved")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Saved")
                                .font(.headline.bold())
                        }
                    }
                }
        }
    }
}

// MARK: - Smart album definition

struct SmartAlbum: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let filter: (CookabilityItem) -> Bool
}

// Parses ISO 8601 strings that may or may not include fractional seconds.
private func parseISODate(_ s: String) -> Date? {
    let withFrac = ISO8601DateFormatter()
    withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFrac.date(from: s) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: s)
}

// Ordered list of all possible smart albums.
// Only those with at least one matching recipe are shown.
let allSmartAlbums: [SmartAlbum] = [
    // ── Recently Saved (top, after Favorites) ─────────────────────────────────
    SmartAlbum(id: "recent", name: "Recently Saved", icon: "clock.arrow.circlepath", color: .orange) {
        guard let date = parseISODate($0.createdAt) else { return false }
        return Date().timeIntervalSince(date) <= 5 * 24 * 3600
    },

    SmartAlbum(id: "breakfast", name: "Breakfast",    icon: "sunrise.fill",       color: .orange) {
        $0.mealType == "breakfast"
    },
    SmartAlbum(id: "lunch",     name: "Lunch",        icon: "sun.max.fill",        color: .yellow) {
        $0.mealType == "lunch"
    },
    SmartAlbum(id: "dinner",    name: "Dinner",       icon: "moon.stars.fill",     color: .indigo) {
        $0.mealType == "dinner"
    },
    SmartAlbum(id: "easy",      name: "Easy Meals",   icon: "face.smiling.fill",   color: .green) {
        $0.effort == "easy"
            || ($0.timeMinutes.map { $0 <= 30 } ?? false)
            || $0.ingredientCount < 10
    },
    SmartAlbum(id: "protein",   name: "High Protein", icon: "bolt.fill",           color: .green) {
        $0.proteinLevel == "high"
    },
    SmartAlbum(id: "lowcal",    name: "Low Calories",      icon: "leaf.fill",           color: .mint) {
        $0.calorieLevel == "low"
    },
    SmartAlbum(id: "under1hr",  name: "Under 1hr",    icon: "clock.fill",          color: .blue) {
        $0.timeMinutes.map { $0 < 60 } ?? false
    },
    SmartAlbum(id: "chicken",   name: "Chicken",      icon: "bird.fill",           color: .orange) {
        $0.proteinSource == "chicken"
    },
    SmartAlbum(id: "beef",      name: "Beef",         icon: "flame.fill",          color: .red) {
        $0.proteinSource == "beef"
    },
    SmartAlbum(id: "seafood",   name: "Seafood",      icon: "water.waves",         color: .teal) {
        $0.proteinSource == "seafood" || $0.proteinSource == "fish"
    },
    SmartAlbum(id: "vegan",     name: "Vegan",        icon: "leaf.fill",           color: .green) {
        $0.proteinSource == "vegan"
    },
    SmartAlbum(id: "eggs",      name: "Eggs",         icon: "oval.fill",           color: .yellow) {
        $0.proteinSource == "eggs"
    },
    SmartAlbum(id: "mealprep",  name: "Meal Prep",    icon: "tray.fill",           color: .purple) {
        ($0.servings ?? 0) >= 6
    },
    SmartAlbum(id: "dessert", name: "Dessert", icon: "birthday.cake.fill", color: .red) {
        $0.mealType == "dessert"
    },

    // ── Cuisine ───────────────────────────────────────────────────────────────
    SmartAlbum(id: "cuisine_italian",       name: "Italian",        icon: "fork.knife",        color: .red)     { $0.cuisine == "italian" },
    SmartAlbum(id: "cuisine_mexican",       name: "Mexican",        icon: "flame.fill",        color: .orange)  { $0.cuisine == "mexican" },
    SmartAlbum(id: "cuisine_chinese",       name: "Chinese",        icon: "moon.fill",         color: .yellow)  { $0.cuisine == "chinese" },
    SmartAlbum(id: "cuisine_japanese",      name: "Japanese",       icon: "sun.horizon.fill",  color: .red)     { $0.cuisine == "japanese" },
    SmartAlbum(id: "cuisine_thai",          name: "Thai",           icon: "leaf.fill",         color: .green)   { $0.cuisine == "thai" },
    SmartAlbum(id: "cuisine_indian",        name: "Indian",         icon: "sparkles",          color: .orange)  { $0.cuisine == "indian" },
    SmartAlbum(id: "cuisine_mediterranean", name: "Mediterranean",  icon: "water.waves",       color: .blue)    { $0.cuisine == "mediterranean" },
    SmartAlbum(id: "cuisine_middle_eastern",name: "Middle Eastern", icon: "moon.stars.fill",   color: .purple)  { $0.cuisine == "middle eastern" },
    SmartAlbum(id: "cuisine_french",        name: "French",         icon: "wineglass.fill",    color: .pink)    { $0.cuisine == "french" },
    SmartAlbum(id: "cuisine_american",      name: "American",       icon: "star.fill",         color: .blue)    { $0.cuisine == "american" },
    SmartAlbum(id: "cuisine_korean",        name: "Korean",         icon: "flame.fill",        color: .red)     { $0.cuisine == "korean" },
    SmartAlbum(id: "cuisine_greek",         name: "Greek",          icon: "sun.max.fill",      color: .cyan)    { $0.cuisine == "greek" },
    SmartAlbum(id: "cuisine_spanish",       name: "Spanish",        icon: "sun.max.fill",      color: .yellow)  { $0.cuisine == "spanish" },
    SmartAlbum(id: "cuisine_vietnamese",    name: "Vietnamese",     icon: "leaf.fill",         color: .mint)    { $0.cuisine == "vietnamese" },
    SmartAlbum(id: "cuisine_moroccan",      name: "Moroccan",       icon: "moon.fill",         color: .orange)  { $0.cuisine == "moroccan" },
    SmartAlbum(id: "cuisine_caribbean",     name: "Caribbean",      icon: "water.waves",       color: .teal)    { $0.cuisine == "caribbean" },
    SmartAlbum(id: "cuisine_latin",         name: "Latin American", icon: "flame.fill",        color: .orange)  { $0.cuisine == "latin american" },
    SmartAlbum(id: "cuisine_turkish",       name: "Turkish",        icon: "moon.stars.fill",   color: .indigo)  { $0.cuisine == "turkish" },
    SmartAlbum(id: "cuisine_persian",       name: "Persian",        icon: "sparkles",          color: .purple)  { $0.cuisine == "persian" },
]

// MARK: - Album grid content

struct SavedAlbumsContent: View {
    @EnvironmentObject var store: RecipeStore

    @State private var albums: [AlbumItem] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    // Precompute all smart album matches once
    private var smartAlbumMatches: [(SmartAlbum, [CookabilityItem])] {
        allSmartAlbums.compactMap { album in
            let matches = store.cookabilityItems.filter(album.filter)
            return matches.isEmpty ? nil : (album, matches)
        }
    }

    private var allItems: [CookabilityItem] { store.cookabilityItems }
    private var favoriteItems: [CookabilityItem] { store.cookabilityItems.filter { $0.isFavorited } }

    var body: some View {
        Group {
            if isLoading && store.cookabilityItems.isEmpty {
                ProgressView("Loading…").tint(.orange)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 20) {

                        // ── All ───────────────────────────────────────────────
                        NavigationLink(destination: AlbumDetailView(kind: .all)) {
                            AlbumGridCell(
                                name: "All",
                                count: allItems.count,
                                coverURLs: allItems.prefix(4).compactMap { $0.thumbnailURL },
                                systemIcon: "photo.on.rectangle",
                                iconColor: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        // ── Favorites (only if non-empty) ─────────────────────
                        if !favoriteItems.isEmpty {
                            NavigationLink(destination: AlbumDetailView(kind: .favorites)) {
                                AlbumGridCell(
                                    name: "Favorites",
                                    count: favoriteItems.count,
                                    coverURLs: favoriteItems.prefix(4).compactMap { $0.thumbnailURL },
                                    systemIcon: "heart.fill",
                                    iconColor: .red
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // ── Smart albums (non-empty only) ─────────────────────
                        ForEach(smartAlbumMatches, id: \.0.id) { album, matches in
                            NavigationLink(destination: SmartAlbumDetailView(album: album)) {
                                AlbumGridCell(
                                    name: album.name,
                                    count: matches.count,
                                    coverURLs: matches.prefix(4).compactMap { $0.thumbnailURL },
                                    systemIcon: album.icon,
                                    iconColor: album.color
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // ── Custom albums ─────────────────────────────────────
                        ForEach(albums) { album in
                            NavigationLink(destination: AlbumDetailView(kind: .custom(id: album.id, name: album.name))) {
                                AlbumGridCell(
                                    name: album.name,
                                    count: album.recipeCount,
                                    coverURLs: album.coverURLs,
                                    systemIcon: "rectangle.stack",
                                    iconColor: .orange
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await deleteAlbum(album) }
                                } label: {
                                    Label("Delete Album", systemImage: "trash")
                                }
                            }
                        }

                        // ── New album ─────────────────────────────────────────
                        Button { showCreateSheet = true } label: {
                            NewAlbumCell()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .task { await load() }
        .onAppear { Task { await load() } }
        .sheet(isPresented: $showCreateSheet) {
            CreateAlbumSheet { name in
                await createAlbum(name: name)
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        async let albs = APIClient.shared.getAlbums()
        await store.reloadCookability()
        if let a = try? await albs { albums = a }
        isLoading = false
    }

    private func createAlbum(name: String) async {
        guard let album = try? await APIClient.shared.createAlbum(name: name) else { return }
        albums.append(album)
    }

    private func deleteAlbum(_ album: AlbumItem) async {
        try? await APIClient.shared.deleteAlbum(id: album.id)
        albums.removeAll { $0.id == album.id }
    }
}

// MARK: - Smart album detail view

struct SmartAlbumDetailView: View {
    let album: SmartAlbum
    @EnvironmentObject var store: RecipeStore
    @State private var searchText = ""

    private var recipes: [CookabilityItem] {
        store.cookabilityItems.filter(album.filter)
    }

    private var filtered: [CookabilityItem] {
        searchText.isEmpty
            ? recipes
            : recipes.filter { $0.dishName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if recipes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: album.icon)
                        .font(.system(size: 52))
                        .foregroundStyle(album.color.opacity(0.4))
                    Text("No \(album.name) recipes yet")
                        .font(.headline)
                    Text("Add more recipes and they'll appear here automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { item in
                    NavigationLink(destination: RecipeDetailView(
                        recipeId: item.id,
                        recipeTitle: item.dishName,
                        missingIngredients: item.missingIngredients
                    )) {
                        SmartAlbumRow(item: item)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search recipes")
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Smart album row (matches RecipeRow layout exactly)

private struct SmartAlbumRow: View {
    let item: CookabilityItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        placeholder
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(item.dishName)
                    .font(.headline)
                    .lineLimit(2)

                if let creator = item.creatorName {
                    Text(creator)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(item.ingredientCount) ingredients")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.orange.opacity(0.12))
            Image(systemName: "fork.knife")
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Album grid cell

struct AlbumGridCell: View {
    let name: String
    let count: Int
    let coverURLs: [String]
    var systemIcon: String = "photo.on.rectangle"
    var iconColor: Color = .orange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let size = geo.size.width
                thumbnailGrid(size: size)
                    .frame(width: size, height: size)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(count == 1 ? "1 recipe" : "\(count) recipes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func thumbnailGrid(size: CGFloat) -> some View {
        let urls = coverURLs.prefix(4).compactMap { URL(string: $0) }
        let gap: CGFloat = 2
        let half = (size - gap) / 2

        switch urls.count {
        case 0:
            placeholder(width: size, height: size)
        case 1:
            thumb(url: urls[0], width: size, height: size)
        case 2:
            HStack(spacing: gap) {
                thumb(url: urls[0], width: half, height: size)
                thumb(url: urls[1], width: half, height: size)
            }
        case 3:
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    thumb(url: urls[0], width: half, height: half)
                    thumb(url: urls[1], width: half, height: half)
                }
                thumb(url: urls[2], width: size, height: half)
            }
        default:
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    thumb(url: urls[0], width: half, height: half)
                    thumb(url: urls[1], width: half, height: half)
                }
                HStack(spacing: gap) {
                    thumb(url: urls[2], width: half, height: half)
                    thumb(url: urls[3], width: half, height: half)
                }
            }
        }
    }

    private func thumb(url: URL, width: CGFloat, height: CGFloat) -> some View {
        CachedAsyncImage(url: url) { img in
            img.resizable().scaledToFill()
        } placeholder: {
            Color(.systemGray5)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func placeholder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: systemIcon)
                .font(.system(size: 32))
                .foregroundStyle(iconColor.opacity(0.5))
        }
        .frame(width: width, height: height)
    }
}

// MARK: - New album cell

private struct NewAlbumCell: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .aspectRatio(1, contentMode: .fit)
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.orange)
            }
            Text("New Album")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(" ")
                .font(.caption)
        }
    }
}

// MARK: - Create album sheet

private struct CreateAlbumSheet: View {
    let onCreate: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Album Name") {
                    TextField("e.g. Weeknight dinners, Meal prep…", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating…" : "Create") {
                        isCreating = true
                        Task {
                            await onCreate(name.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
