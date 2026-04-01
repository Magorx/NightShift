extends Node

## Research/Tech Tree manager. Tracks unlocked techs, current research target,
## and science pack delivery progress.
##
## Unlock state uses a tag-based system: unlocked_tags maps tag names to bool.
## Any system queries is_tag_unlocked(tag). Unknown tags warn and return unlocked.
## Creative mode reports everything as unlocked.
## When a tag is unlocked, tag_unlocked signal is emitted so listeners can react.

# All tech definitions: tech_id -> TechDef
var tech_defs: Dictionary = {}

# Unlocked techs: tech_id -> true
var unlocked_techs: Dictionary = {}

# Tag-based unlock state: tag_name -> bool (true = unlocked)
var unlocked_tags: Dictionary = {}

# Current research target: TechDef or null
var current_research: Resource = null

# Progress: item_id -> count of packs delivered so far
var research_progress: Dictionary = {}

signal research_completed(tech_id: StringName)
signal research_started(tech_id: StringName)
signal tag_unlocked(tag: StringName)
signal tags_reset  # emitted when tags are cleared (reset/deserialize), listeners should reset their state

func _ready():
	_load_from_json()
	_register_all_tags()
	# Ring 0 normal techs are free — unlock them immediately
	# Ring 0 instant techs must be manually researched (costs taken from player inventory)
	for tech_id in tech_defs:
		var tech: TechDef = tech_defs[tech_id]
		if tech.ring == 0 and tech.type != &"instant":
			unlocked_techs[tech_id] = true
			_apply_effects(tech)

func _load_from_json():
	## Load all tech definitions from research_tree.json (single source of truth).
	var file := FileAccess.open("res://resources/tech/research_tree.json", FileAccess.READ)
	if not file:
		push_warning("ResearchManager: research_tree.json not found, falling back to .tres files")
		_load_tech_defs_tres()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ResearchManager: failed to parse research_tree.json")
		_load_tech_defs_tres()
		return
	var data: Dictionary = json.data
	tech_defs.clear()
	for node_data in data.get("nodes", []):
		var def := TechDef.new()
		def.id = StringName(node_data.get("id", ""))
		def.display_name = node_data.get("display_name", "")
		def.description = node_data.get("description", "")
		def.ring = int(node_data.get("ring", 0))
		def.type = StringName(node_data.get("type", "normal"))
		def.effects = []
		for effect_data in node_data.get("effects", []):
			def.effects.append(effect_data)
		def.cost = []
		for cost_data in node_data.get("cost", []):
			var stack := ItemStack.new()
			stack.item = GameManager.get_item_def(StringName(cost_data.get("item", "")))
			stack.quantity = int(cost_data.get("quantity", 1))
			if stack.item:
				def.cost.append(stack)
		if def.id != &"":
			tech_defs[def.id] = def

func _load_tech_defs_tres():
	## Fallback: load from .tres files if JSON is unavailable.
	var dir = DirAccess.open("res://resources/tech/")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var def = load("res://resources/tech/" + file_name)
			if def and def is TechDef:
				tech_defs[def.id] = def
		file_name = dir.get_next()

# ── Tag system ────────────────────────────────────────────────────────────────

func _register_all_tags() -> void:
	## Scan all tech effects and register every unlock_tag as locked (false).
	unlocked_tags.clear()
	for tech_id in tech_defs:
		var tech: TechDef = tech_defs[tech_id]
		for effect in tech.effects:
			var tag: String = effect.get("unlock_tag", "")
			if tag != "":
				unlocked_tags[StringName(tag)] = false

func is_tag_unlocked(tag: StringName) -> bool:
	## Check if a research tag is unlocked.
	## Creative mode: everything is unlocked.
	## Empty tag: always unlocked (no research requirement).
	## Unknown tag: warn and return unlocked.
	if GameManager.creative_mode:
		return true
	if tag == &"":
		return true
	if not unlocked_tags.has(tag):
		push_warning("ResearchManager: unknown tag '%s' queried — treating as unlocked" % tag)
		return true
	return unlocked_tags[tag]

func _apply_effects(tech: TechDef) -> void:
	## Unlock all tags from a completed tech's effects and emit signals.
	for effect in tech.effects:
		var tag: String = effect.get("unlock_tag", "")
		if tag != "":
			unlocked_tags[StringName(tag)] = true
			tag_unlocked.emit(StringName(tag))

# ── Research flow ─────────────────────────────────────────────────────────────

func start_research(tech_id: StringName) -> bool:
	if unlocked_techs.has(tech_id):
		return false
	var def: TechDef = tech_defs.get(tech_id)
	if not def:
		return false
	if def.type == &"instant":
		return _try_instant_research(def)
	current_research = def
	research_progress = {}
	research_started.emit(tech_id)
	return true

func can_afford_instant(tech: TechDef) -> bool:
	## Check if the player has enough items in inventory for an instant tech.
	var player: Player = GameManager.player
	if not player:
		return false
	for stack in tech.cost:
		if player.count_item(stack.item.id) < stack.quantity:
			return false
	return true

func _try_instant_research(tech: TechDef) -> bool:
	## Attempt to complete an instant tech by consuming items from player inventory.
	var player: Player = GameManager.player
	if not player:
		return false
	if not can_afford_instant(tech):
		return false
	for stack in tech.cost:
		player.remove_item(stack.item.id, stack.quantity)
	unlocked_techs[tech.id] = true
	_apply_effects(tech)
	research_completed.emit(tech.id)
	return true

func deliver_science_pack(item_id: StringName) -> bool:
	## Called by research labs when they consume a science pack.
	## Returns true if the pack was accepted (needed for current research).
	if not current_research:
		return false
	for stack in current_research.cost:
		if stack.item.id == item_id:
			var current = research_progress.get(item_id, 0)
			if current < stack.quantity:
				research_progress[item_id] = current + 1
				_check_completion()
				return true
	return false

func needs_pack(item_id: StringName) -> bool:
	## Check if the current research needs more of this pack type.
	if not current_research:
		return false
	for stack in current_research.cost:
		if stack.item.id == item_id:
			var current = research_progress.get(item_id, 0)
			return current < stack.quantity
	return false

func _check_completion():
	if not current_research:
		return
	for stack in current_research.cost:
		if research_progress.get(stack.item.id, 0) < stack.quantity:
			return
	var completed_tech: TechDef = current_research
	var completed_id: StringName = completed_tech.id
	unlocked_techs[completed_id] = true
	current_research = null
	research_progress = {}
	_apply_effects(completed_tech)
	research_completed.emit(completed_id)

func get_available_techs() -> Array:
	## Return all techs that are not yet unlocked.
	var result = []
	for tech_id in tech_defs:
		if unlocked_techs.has(tech_id):
			continue
		result.append(tech_defs[tech_id])
	return result

func get_progress_fraction() -> float:
	## Return overall progress as 0.0-1.0 for current research.
	if not current_research:
		return 0.0
	var total_needed := 0
	var total_done := 0
	for stack in current_research.cost:
		total_needed += stack.quantity
		total_done += mini(research_progress.get(stack.item.id, 0), stack.quantity)
	if total_needed == 0:
		return 1.0
	return float(total_done) / float(total_needed)

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data = {}
	data["unlocked"] = []
	for tech_id in unlocked_techs:
		data["unlocked"].append(str(tech_id))
	if current_research:
		data["current"] = str(current_research.id)
		data["progress"] = {}
		for item_id in research_progress:
			data["progress"][str(item_id)] = research_progress[item_id]
	return data

func deserialize(data: Dictionary):
	unlocked_techs.clear()
	_register_all_tags()
	tags_reset.emit()
	for tech_id_str in data.get("unlocked", []):
		var tid := StringName(tech_id_str)
		unlocked_techs[tid] = true
		if tech_defs.has(tid):
			_apply_effects(tech_defs[tid])
	var current_id = data.get("current", "")
	if current_id != "":
		current_research = tech_defs.get(StringName(current_id))
	else:
		current_research = null
	research_progress = {}
	for item_id_str in data.get("progress", {}):
		research_progress[StringName(item_id_str)] = int(data["progress"][item_id_str])

func reset() -> void:
	unlocked_techs.clear()
	current_research = null
	research_progress = {}
	_register_all_tags()
	tags_reset.emit()
	for tech_id in tech_defs:
		var tech: TechDef = tech_defs[tech_id]
		if tech.ring == 0 and tech.type != &"instant":
			unlocked_techs[tech_id] = true
			_apply_effects(tech)
