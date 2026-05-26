# Product Spec — Grocery List

## Problem

Users discover cooking videos on TikTok and Instagram but never cook the recipes because:
1. They forget about the video by the time they go shopping
2. At the grocery store they don't have the list and buy default items
3. They are missing just a few ingredients and don't realize it

## Solution

An inventory-aware grocery assistant that:
- Accepts shared TikTok / Instagram recipe videos
- Extracts the recipe and ingredient list automatically
- Compares ingredients against the user's current pantry
- Generates a smart grocery list that unlocks the most recipes
- Shows which saved recipes are cookable right now

---

## User stories

### Core flow

**US-01**: As a user, I can share a TikTok or Instagram video to the app from the native iOS share sheet, and within a few seconds see the extracted recipe name and ingredient list.

**US-02**: As a user, I can see all my saved recipes and how many ingredients I am missing for each one.

**US-03**: As a user, I can manage my pantry inventory — marking items as in stock, low, or out of stock.

**US-04**: As a user, I can generate a grocery list from selected recipes, which automatically excludes items I already have.

**US-05**: As a user, I can check off items as I add them to my cart at the grocery store, and the app updates my inventory automatically.

**US-06**: As a user, I can see a "Can Cook Now" list of recipes where I have all ingredients in stock.

**US-07**: As a user, I can see a "Almost There" list sorted by fewest missing ingredients.

### Inventory

**US-08**: As a user, I can manually add items to my inventory.

**US-09**: As a user, I can mark items as "always have" (salt, oil, water) so they are never added to a grocery list.

**US-10**: As a user, I can remove items from my inventory.

### Recipes

**US-11**: As a user, I can view the original video for any saved recipe by tapping a link.

**US-12**: As a user, I can delete a saved recipe.

**US-13**: As a user, I can see the full ingredient list and cooking steps for any recipe.

---

## Screens

### 1. Saved Recipes
- List of all saved recipes
- Each card: dish name, creator, thumbnail, "X missing" badge
- Tap → Recipe Detail
- Filter: All / Can Cook / Almost There

### 2. Recipe Detail
- Dish name + creator
- Thumbnail + link to original video
- Full ingredient list (green checkmark = in stock, red = missing)
- Cooking steps
- "Add missing to grocery list" button

### 3. Inventory
- Searchable list of all pantry items
- Status toggle: in_stock / low / out_of_stock / always_have
- Add item manually
- Remove item

### 4. Grocery List
- Current shopping list
- Items grouped by category (produce, dairy, meat, pantry)
- Check off items → marks as purchased + updates inventory
- "Clear checked" after shopping trip

### 5. Can Cook
- Recipes sorted by cookability
- "Ready now" section
- "Missing 1", "Missing 2", etc.

---

## Out of scope for v1

- User accounts / cloud sync (local only first)
- Receipt scanning / automatic inventory update
- Instagram ingestion (TikTok first)
- Serving size adjustment
- Nutritional info
- Price estimation
- Social / sharing with others
