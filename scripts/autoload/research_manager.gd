extends Node

## Research/Tech Tree manager. Tracks unlocked techs, current research target,
## and science pack delivery progress. Registered as an autoload singleton.

# All tech definitions: tech_id -> TechDef
var tech_defs: Dictionary = {}

# Unlocked techs: tech_id -> true
var unlocked_techs: Dictionary = {}

# Current research target: TechDef or null
var current_research: Resource = null

# Progress: item_id -> count of packs delivered so far
var research_progress: Dictionary = {}

signal research_completed(tech_id: StringName)
signal research_started(tech_id: StringName)

func _ready():
	_load_tech_defs()
	# Ring 0 techs are free — unlock them immediately
	for tech_id in tech_defs:
		if tech_defs[tech_id].ring == 0:
			unlocked_techs[tech_id] = true

func _load_tech_defs():
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

func is_building_unlocked(building_id: StringName) -> bool:
	## Check if a building is unlocked by any completed tech.
	var def = GameManager.get_building_def(building_id)
	if not def or def.unlock_tech == &"":
		return true  # No tech requirement = always available
	return unlocked_techs.has(def.unlock_tech)

func start_research(tech_id: StringName) -> bool:
	if unlocked_techs.has(tech_id):
		return false
	var def = tech_defs.get(tech_id)
	if not def:
		return false
	current_research = def
	research_progress = {}
	research_started.emit(tech_id)
	return true

func deliver_science_pack(item_id: StringName) -> bool:
	## Called by research labs when they consume a science pack.
	## Returns true if the pack was accepted (needed for current research).
	if not current_research:
		return false
	# Check if this pack type is needed
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
	# Complete!
	var completed_id: StringName = current_research.id
	unlocked_techs[completed_id] = true
	current_research = null
	research_progress = {}
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
	for tech_id_str in data.get("unlocked", []):
		unlocked_techs[StringName(tech_id_str)] = true
	var current_id = data.get("current", "")
	if current_id != "":
		current_research = tech_defs.get(StringName(current_id))
	else:
		current_research = null
	research_progress = {}
	for item_id_str in data.get("progress", {}):
		research_progress[StringName(item_id_str)] = int(data["progress"][item_id_str])
