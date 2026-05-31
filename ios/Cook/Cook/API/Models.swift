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
    let isFavorited: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, platform
        case dishName        = "dish_name"
        case creatorName     = "creator_name"
        case sourceURL       = "source_url"
        case thumbnailURL    = "thumbnail_url"
        case ingredientCount = "ingredient_count"
        case isFavorited     = "is_favorited"
        case createdAt       = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        dishName       = try c.decode(String.self, forKey: .dishName)
        creatorName    = try c.decodeIfPresent(String.self, forKey: .creatorName)
        sourceURL      = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        thumbnailURL   = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        platform       = try c.decode(String.self, forKey: .platform)
        ingredientCount = try c.decode(Int.self, forKey: .ingredientCount)
        isFavorited    = try c.decodeIfPresent(Bool.self, forKey: .isFavorited) ?? false
        createdAt      = try c.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - Album

struct AlbumItem: Codable, Identifiable {
    let id: String
    let name: String
    let recipeCount: Int
    let coverURLs: [String]   // up to 4 thumbnails
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case recipeCount = "recipe_count"
        case coverURLs   = "cover_urls"
        case createdAt   = "created_at"
    }
}

// MARK: - Ingredient

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
        case rawText      = "raw_text"
        case canonicalName = "canonical_name"
    }
}

// MARK: - Full recipe detail

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
    let servings: Int?
    let effort: String?
    let timeMinutes: Int?
    let isBatchPrep: Bool
    let proteinLevel: String?
    let calorieLevel: String?
    let proteinSource: String?
    let isFavorited: Bool

    enum CodingKeys: String, CodingKey {
        case id, platform, confidence, steps, ingredients
        case dishName     = "dish_name"
        case creatorName  = "creator_name"
        case sourceURL    = "source_url"
        case thumbnailURL = "thumbnail_url"
        case embedHTML    = "embed_html"
        case createdAt    = "created_at"
        case servings, effort
        case timeMinutes  = "time_minutes"
        case isBatchPrep  = "is_batch_prep"
        case proteinLevel = "protein_level"
        case calorieLevel = "calorie_level"
        case proteinSource = "protein_source"
        case isFavorited  = "is_favorited"
    }
}

// MARK: - Cookability (home screen)

struct CookabilityItem: Codable, Identifiable {
    let id: String
    let dishName: String
    let creatorName: String?
    let sourceURL: String?
    let thumbnailURL: String?
    let platform: String
    let ingredientCount: Int
    let createdAt: String
    let servings: Int?
    let effort: String?
    let timeMinutes: Int?
    let isBatchPrep: Bool
    let proteinLevel: String?
    let calorieLevel: String?
    let proteinSource: String?
    let isFavorited: Bool
    let missingCount: Int
    let missingIngredients: [String]

    enum CodingKeys: String, CodingKey {
        case id, platform, servings, effort
        case dishName          = "dish_name"
        case creatorName       = "creator_name"
        case sourceURL         = "source_url"
        case thumbnailURL      = "thumbnail_url"
        case ingredientCount   = "ingredient_count"
        case createdAt         = "created_at"
        case timeMinutes       = "time_minutes"
        case isBatchPrep       = "is_batch_prep"
        case proteinLevel      = "protein_level"
        case calorieLevel      = "calorie_level"
        case proteinSource     = "protein_source"
        case isFavorited       = "is_favorited"
        case missingCount      = "missing_count"
        case missingIngredients = "missing_ingredients"
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
        case dishName    = "dish_name"
        case creatorName = "creator_name"
        case sourceURL   = "source_url"
        case thumbnailURL = "thumbnail_url"
    }

    var isSuccess: Bool { status == "success" }
}

// MARK: - Inventory

struct InventoryItem: Codable, Identifiable {
    let id: String
    let canonicalName: String
    let status: String        // "in_stock" | "low" | "out_of_stock" | "always_have"
    let category: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, category
        case canonicalName = "canonical_name"
        case updatedAt     = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        canonicalName = try c.decode(String.self, forKey: .canonicalName)
        status       = try c.decode(String.self, forKey: .status)
        category     = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        updatedAt    = try c.decode(String.self, forKey: .updatedAt)
    }
}

// MARK: - Planned meal

struct PlannedMealItem: Codable, Identifiable {
    let id: String
    let recipeId: String
    let dishName: String
    let thumbnailURL: String?
    let platform: String
    let addedAt: String

    enum CodingKeys: String, CodingKey {
        case id, platform
        case recipeId     = "recipe_id"
        case dishName     = "dish_name"
        case thumbnailURL = "thumbnail_url"
        case addedAt      = "added_at"
    }
}

// MARK: - Cooking log entry

struct CookingLogEntry: Codable, Identifiable {
    let id: String
    let recipeId: String
    let dishName: String
    let cookedAt: String
    let servings: Int

    enum CodingKeys: String, CodingKey {
        case id, servings
        case recipeId = "recipe_id"
        case dishName = "dish_name"
        case cookedAt = "cooked_at"
    }
}

// MARK: - Kitchen stats

struct KitchenStats: Codable {
    // This week
    let mealsThisWeek: Int          // total servings
    let recipesThisWeek: Int        // distinct cooking sessions
    let plannedCount: Int
    let ingredientsUsedThisWeek: Int
    let moneySpentThisWeek: Double  // placeholder

    // Your kitchen
    let pantryItems: Int
    let uniqueRecipesCooked: Int
    let totalCookedAllTime: Int
    let savedRecipes: Int

    enum CodingKeys: String, CodingKey {
        case mealsThisWeek          = "meals_cooked_this_week"
        case recipesThisWeek        = "recipes_cooked_this_week"
        case plannedCount           = "planned_count"
        case ingredientsUsedThisWeek = "ingredients_used_this_week"
        case moneySpentThisWeek     = "money_spent_this_week"
        case pantryItems            = "pantry_items"
        case uniqueRecipesCooked    = "unique_recipes_cooked"
        case totalCookedAllTime     = "total_cooked_all_time"
        case savedRecipes           = "saved_recipes"
    }
}

// MARK: - Grocery list

struct GroceryListItem: Codable, Identifiable {
    let id: String
    let canonicalName: String
    let category: String
    let checked: Bool
    let recipeId: String?

    enum CodingKeys: String, CodingKey {
        case id, category, checked
        case canonicalName = "canonical_name"
        case recipeId      = "recipe_id"
    }
}
