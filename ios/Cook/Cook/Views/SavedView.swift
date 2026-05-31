import SwiftUI

struct SavedView: View {
    @State private var allRecipes: [RecipeListItem] = []
    @State private var albums: [AlbumItem] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false

    private var favoriteRecipes: [RecipeListItem] { allRecipes.filter { $0.isFavorited } }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
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
                                    coverURL: allRecipes.first?.thumbnailURL,
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
                                    coverURL: favoriteRecipes.first?.thumbnailURL,
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
                                        coverURL: album.coverURL,
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
            .task { await load() }
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showCreateSheet) {
                CreateAlbumSheet { name in
                    await createAlbum(name: name)
                }
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
    let coverURL: String?
    var systemIcon: String = "photo.on.rectangle"
    var iconColor: Color = .orange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Square thumbnail
            ZStack {
                if let urlStr = coverURL, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        placeholderView
                    }
                } else {
                    placeholderView
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Name + count
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(count == 1 ? "1 recipe" : "\(count) recipes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: systemIcon)
                .font(.system(size: 32))
                .foregroundStyle(iconColor.opacity(0.5))
        }
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
