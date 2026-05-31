import SwiftUI

// SavedView: standalone wrapper (kept for any direct use)
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

// MARK: - Album grid content (embeddable — works inside any NavigationStack)

struct SavedAlbumsContent: View {
    @State private var allRecipes: [RecipeListItem] = []
    @State private var albums: [AlbumItem] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false

    private var favoriteRecipes: [RecipeListItem] { allRecipes.filter { $0.isFavorited } }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        Group {
            if isLoading && allRecipes.isEmpty {
                ProgressView("Loading…").tint(.orange)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 20) {

                        // ── Virtual: All ──────────────────────────────────
                        NavigationLink(destination: AlbumDetailView(kind: .all)) {
                            AlbumGridCell(
                                name: "All",
                                count: allRecipes.count,
                                coverURLs: allRecipes.prefix(4).compactMap { $0.thumbnailURL },
                                systemIcon: "photo.on.rectangle",
                                iconColor: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        // ── Virtual: Favorites ────────────────────────────
                        NavigationLink(destination: AlbumDetailView(kind: .favorites)) {
                            AlbumGridCell(
                                name: "Favorites",
                                count: favoriteRecipes.count,
                                coverURLs: favoriteRecipes.prefix(4).compactMap { $0.thumbnailURL },
                                systemIcon: "heart.fill",
                                iconColor: .red
                            )
                        }
                        .buttonStyle(.plain)

                        // ── Custom albums ─────────────────────────────────
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

                        // ── Create album ──────────────────────────────────
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
        async let r = try? APIClient.shared.getRecipes()
        async let a = try? APIClient.shared.getAlbums()
        if let recipes = await r { allRecipes = recipes }
        if let albs   = await a  { albums = albs }
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

// MARK: - Album grid cell

struct AlbumGridCell: View {
    let name: String
    let count: Int
    let coverURLs: [String]   // up to 4
    var systemIcon: String = "photo.on.rectangle"
    var iconColor: Color = .orange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Force a perfect square using GeometryReader, then clip
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

        default: // 4
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
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.orange)
                }
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
