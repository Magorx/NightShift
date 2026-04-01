class_name HandAssemblerLogic
extends ConverterLogic

## Manual workbench with craft queue.
## All recipes start disabled. Crafts happen only when a recipe is enabled
## (automated mode) or _craft_queue > 0 (manual queue mode).

var _craft_queue: int = 0

func _build_recipe_configs(_default_enabled: bool = true) -> void:
	super._build_recipe_configs(false)

func _try_start_craft() -> void:
	var sorted := recipe_configs.duplicate()
	sorted.sort_custom(func(a, b): return a.priority < b.priority)
	for config in sorted:
		var use_queue := _craft_queue > 0
		if not config.enabled and not use_queue:
			continue
		if not _can_craft(config.recipe):
			continue
		if config.recipe.energy_cost > 0.0:
			if not energy or energy.energy_stored < config.recipe.energy_cost:
				continue
		if use_queue and not config.enabled:
			_craft_queue -= 1
		_start_craft(config.recipe)
		return

func queue_craft() -> void:
	_craft_queue += 1

func clear_craft_queue() -> void:
	_craft_queue = 0

func serialize_state() -> Dictionary:
	var state := super.serialize_state()
	state["craft_queue"] = _craft_queue
	return state

func deserialize_state(state: Dictionary) -> void:
	super.deserialize_state(state)
	if state.has("craft_queue"):
		_craft_queue = int(state["craft_queue"])
