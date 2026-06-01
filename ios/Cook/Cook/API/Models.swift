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
    let mealType: String?
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
        case mealType     = "meal_type"
        case servings, effort
        case timeMinutes  = "time_minutes"
        case isBatchPrep  = "is_batch_prep"
        case proteinLevel = "protein_level"
        case calorieLevel = "calorie_level"
        case proteinSource = "protein_source"
        case isFavorited  = "is_favorited"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self,              forKey: .id)
        dishName      = try c.decode(String.self,              forKey: .dishName)
        creatorName   = try c.decodeIfPresent(String.self,     forKey: .creatorName)
        sourceURL     = try c.decodeIfPresent(String.self,     forKey: .sourceURL)
        thumbnailURL  = try c.decodeIfPresent(String.self,     forKey: .thumbnailURL)
        embedHTML     = try c.decodeIfPresent(String.self,     forKey: .embedHTML)
        platform      = try c.decode(String.self,              forKey: .platform)
        confidence    = try c.decode(Double.self,              forKey: .confidence)
        createdAt     = try c.decode(String.self,              forKey: .createdAt)
        steps         = try c.decodeIfPresent([String].self,   forKey: .steps)         ?? []
        ingredients   = try c.decodeIfPresent([IngredientResponse].self, forKey: .ingredients) ?? []
        mealType      = try c.decodeIfPresent(String.self,     forKey: .mealType)
        servings      = try c.decodeIfPresent(Int.self,        forKey: .servings)
        effort        = try c.decodeIfPresent(String.self,     forKey: .effort)
        timeMinutes   = try c.decodeIfPresent(Int.self,        forKey: .timeMinutes)
        isBatchPrep   = try c.decodeIfPresent(Bool.self,       forKey: .isBatchPrep)   ?? false
        proteinLevel  = try c.decodeIfPresent(String.self,     forKey: .proteinLevel)
        calorieLevel  = try c.decodeIfPresent(String.self,     forKey: .calorieLevel)
        proteinSource = try c.decodeIfPresent(String.self,     forKey: .proteinSource)
        isFavorited   = try c.decodeIfPresent(Bool.self,       forKey: .isFavorited)   ?? false
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
    let mealType: String?
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
        case mealType          = "meal_type"
        case timeMinutes       = "time_minutes"
        case isBatchPrep       = "is_batch_prep"
        case proteinLevel      = "protein_level"
        case calorieLevel      = "calorie_level"
        case proteinSource     = "protein_source"
        case isFavorited       = "is_favorited"
        case missingCount      = "missing_count"
        case missingIngredients = "missing_ingredients"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self,              forKey: .id)
        dishName         = try c.decode(String.self,              forKey: .dishName)
        creatorName      = try c.decodeIfPresent(String.self,     forKey: .creatorName)
        sourceURL        = try c.decodeIfPresent(String.self,     forKey: .sourceURL)
        thumbnailURL     = try c.decodeIfPresent(String.self,     forKey: .thumbnailURL)
        platform         = try c.decode(String.self,              forKey: .platform)
        ingredientCount  = try c.decode(Int.self,                 forKey: .ingredientCount)
        createdAt        = try c.decode(String.self,              forKey: .createdAt)
        mealType         = try c.decodeIfPresent(String.self,     forKey: .mealType)
        servings         = try c.decodeIfPresent(Int.self,        forKey: .servings)
        effort           = try c.decodeIfPresent(String.self,     forKey: .effort)
        timeMinutes      = try c.decodeIfPresent(Int.self,        forKey: .timeMinutes)
        isBatchPrep      = try c.decodeIfPresent(Bool.self,       forKey: .isBatchPrep)      ?? false
        proteinLevel     = try c.decodeIfPresent(String.self,     forKey: .proteinLevel)
        calorieLevel     = try c.decodeIfPresent(String.self,     forKey: .calorieLevel)
        proteinSource    = try c.decodeIfPresent(String.self,     forKey: .proteinSource)
        isFavorited      = try c.decodeIfPresent(Bool.self,       forKey: .isFavorited)      ?? false
        missingCount     = try c.decodeIfPresent(Int.self,        forKey: .missingCount)     ?? 0
        missingIngredients = try c.decodeIfPresent([String].self, forKey: .missingIngredients) ?? []
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
    let missingCount: Int
    let missingIngredients: [String]   // up to 3 names

    enum CodingKeys: String, CodingKey {
        case id, platform
        case recipeId            = "recipe_id"
        case dishName            = "dish_name"
        case thumbnailURL        = "thumbnail_url"
        case addedAt             = "added_at"
        case missingCount        = "missing_count"
        case missingIngredients  = "missing_ingredients"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self,  forKey: .id)
        recipeId            = try c.decode(String.self,  forKey: .recipeId)
        dishName            = try c.decode(String.self,  forKey: .dishName)
        thumbnailURL        = try c.decodeIfPresent(String.self,  forKey: .thumbnailURL)
        platform            = try c.decode(String.self,  forKey: .platform)
        addedAt             = try c.decode(String.self,  forKey: .addedAt)
        missingCount        = try c.decodeIfPresent(Int.self,     forKey: .missingCount)       ?? 0
        missingIngredients  = try c.decodeIfPresent([String].self, forKey: .missingIngredients) ?? []
    }
}

// MARK: - Cooking log entry

struct CookingLogEntry: Codable, Identifiable {
    let id: String
    let recipeId: String
    let dishName: String
    let cookedAt: String
    let servings: Int
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case id, servings
        case recipeId     = "recipe_id"
        case dishName     = "dish_name"
        case cookedAt     = "cooked_at"
        case thumbnailURL = "thumbnail_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        recipeId     = try c.decode(String.self, forKey: .recipeId)
        dishName     = try c.decode(String.self, forKey: .dishName)
        cookedAt     = try c.decode(String.self, forKey: .cookedAt)
        servings     = try c.decode(Int.self,    forKey: .servings)
        thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
    }
}

// MARK: - Cooking history page (paginated)

struct CookingHistoryPage: Decodable {
    let entries: [CookingLogEntry]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case entries
        case hasMore = "has_more"
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
