# Grocery List — iOS App

SwiftUI app + Share Extension.

## Build phases

### Phase 1 (current): backend-first
The iOS project is a placeholder. Build and validate the backend pipeline first.

### Phase 2: SwiftUI app skeleton
- 4-tab app: Recipes | Inventory | Grocery List | Can Cook
- URLSession async/await networking against the local backend
- SwiftData for local persistence

### Phase 3: Share Extension
- Target: GroceryListShareExtension
- Captures TikTok/Instagram URL from share sheet
- POSTs to backend /ingest/link
- Shows recipe preview card
- Uses App Groups to share data with main app

## Structure (when built)

```
GroceryList/
  App/
    GroceryListApp.swift
    ContentView.swift
  Features/
    Recipes/
      RecipesView.swift
      RecipeDetailView.swift
      RecipeCardView.swift
    Inventory/
      InventoryView.swift
      InventoryItemRow.swift
    GroceryList/
      GroceryListView.swift
      GroceryListItemRow.swift
    CanCook/
      CanCookView.swift
  Services/
    APIClient.swift
    ShareExtensionBridge.swift
  Models/
    Recipe.swift
    Ingredient.swift
    InventoryItem.swift
    GroceryListItem.swift

GroceryListShareExtension/
  ShareViewController.swift
  SharedURLExtractor.swift
```

## Requirements
- Xcode 16+
- iOS 17+ deployment target
- Swift 5.10+
