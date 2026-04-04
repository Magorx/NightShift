# Resources

## Structure
- `items/` — ItemDef `.tres` resources + sprite atlas
- `recipes/` — RecipeDef `.tres` resources (input items -> output items)
- `sprites/terrain/` — terrain tile atlas (Aseprite source + generate script)
- `tech/` — tech tree definitions (will be removed for Night Shift)

## Data-Driven Design
Items and recipes are defined as `.tres` Resource files, not in code. To add a new item:
1. Create `items/<name>.tres` (ItemDef with id, display_name, color, texture region)
2. Add the sprite to the item atlas via `items/sprites/generate_items.lua`
3. Reference it in any RecipeDef that uses it

## Sprite Generation
Each sprite directory has a `generate.lua` Aseprite script that builds the atlas.
Run via: `aseprite -b --script <path>/generate.lua`
