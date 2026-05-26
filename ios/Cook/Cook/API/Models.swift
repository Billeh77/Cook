import Foundation

// MARK: - Recipe list

struct RecipeListItem: Codable, Identifiable {
    let id: String
    let dishName: String
    let creatorName: String?
    let sourceURL: String?
    let thumbnailURL: String?
    let platform: String
    let ingredientCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, platform
        case dishName = "dish_name"
        case creatorName = "creator_name"
        case sourceURL = "source_url"
        case thumbnailURL = "thumbnail_url"
        case ingredientCount = "ingredient_count"
        case createdAt = "created_at"
    }
}

// MARK: - Shared ingredient model

struct IngredientResponse: Codable, Identifiable {
    let id: String
    let rawText: String
    let canonicalName: String
    let quantity: String?
    let unit: String?
    let notes: String?
    let category: String

    enum CodingKeys: String, CodingKey {
        case id, quantity, unit, notes, category
        case rawText = "raw_text"
        case canonicalName = "canonical_name"
    }
}

// MARK: - Full recipe detail (GET /recipes/{id})

struct RecipeDetail: Codable, Identifiable {
    let id: String
    let dishName: String
    let creatorName: String?
    let sourceURL: String?
    let thumbnailURL: String?
    let embedHTML: String?
    let platform: String
    let confidence: Double
    let createdAt: String
    let steps: [String]
    let ingredients: [IngredientResponse]

    enum CodingKeys: String, CodingKey {
        case id, platform, confidence, steps, ingredients
        case dishName = "dish_name"
        case creatorName = "creator_name"
        case sourceURL = "source_url"
        case thumbnailURL = "thumbnail_url"
        case embedHTML = "embed_html"
        case createdAt = "created_at"
    }
}

// MARK: - Ingest response

struct IngestResponse: Codable {
    let id: String?
    let status: String
    let dishName: String?
    let creatorName: String?
    let sourceURL: String?
    let thumbnailURL: String?
    let confidence: Double
    let ingredients: [IngredientResponse]

    enum CodingKeys: String, CodingKey {
        case id, status, confidence, ingredients
        case dishName = "dish_name"
        case creatorName = "creator_name"
        case sourceURL = "source_url"
        case thumbnailURL = "thumbnail_url"
    }

    var isSuccess: Bool { status == "success" }
}
