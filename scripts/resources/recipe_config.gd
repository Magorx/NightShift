class_name RecipeConfig
extends RefCounted

## Per-building, per-recipe configuration: priority and enabled state.

var recipe: RecipeDef
var priority: int = 1    # lower = tried first
var enabled: bool = true  # false = recipe is skipped

func _init(p_recipe: RecipeDef = null, p_priority: int = 1) -> void:
	recipe = p_recipe
	priority = p_priority

func serialize() -> Dictionary:
	return {
		"recipe_id": str(recipe.id),
		"priority": priority,
		"enabled": enabled,
	}

static func deserialize_into(configs: Array, data: Array) -> void:
	for entry in data:
		var rid := StringName(entry["recipe_id"])
		for config in configs:
			if config.recipe.id == rid:
				config.priority = int(entry["priority"])
				config.enabled = bool(entry["enabled"])
				break
