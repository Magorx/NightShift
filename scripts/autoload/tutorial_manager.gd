extends Node

## Emitted when the active step changes (for UI updates).
signal step_changed(step_index: int)
## Emitted when a task for the current step is completed.
signal task_completed(step_index: int)
## Emitted when the entire tutorial finishes.
signal tutorial_finished
## Emitted when task progress changes (counter or inventory).
signal task_progress_changed(current: int, required: int)
## Emitted when a HUD button should be unlocked.
signal button_unlocked(button_name: StringName)

# ── Tutorial Steps ────────────────────────────────────────────────────────────
# Edit this array to change tutorial content and order.
# Each step is a dictionary with:
#   text        — what the player reads
#   task        — (optional) description shown as an objective; locks ">" until done
#   signal_source — (optional) "game_manager", "player", "research_manager", "contract_manager"
#   signal_name   — (optional) signal to listen for
#   check_building — (optional) only count building_placed if id matches
#   check_item     — (optional) only count item_mined if id matches
#   required_count — (optional, default 1) how many signal fires needed
#   unlocks     — (optional) Array of HUD button names to enable on step completion
#                  valid names: "buildings", "inventory", "research", "recipes"
#   setup       — (optional) method name on TutorialManager to call when step becomes active

var steps: Array[Dictionary] = [
	{
		"text": "Welcome to Factor!\nUse [WASD] to walk around.\nHold [Shift] to sprint.\nLook around — you'll see colored deposits on the ground.",
		"task": "",
	},
	{
		"text": "Those colored patches are resource deposits.\nIron deposits are dark grey.\nWalk up to one and hold [Left Mouse Button] to hand-mine it.",
		"task": "Mine 10 iron ore by hand",
		"signal_source": "player",
		"signal_name": "item_mined",
		"check_item": "iron_ore",
		"required_count": 10,
	},
	{
		"text": "Nice! Open your inventory with the button that just appeared on the right.\nYou can see the ore you mined in your inventory slots.\nYou can also press keys [1]-[8] to select hotbar slots.",
		"task": "Open the Inventory panel",
		"signal_source": "hud",
		"signal_name": "inventory_opened",
		"unlocks": ["inventory"],
	},
	{
		"text": "Now let's process that ore.\nThe Buildings panel lets you place machines.\nOpen it with the button that just appeared.",
		"task": "Open the Buildings panel",
		"signal_source": "hud",
		"signal_name": "buildings_opened",
		"unlocks": ["buildings"],
	},
	{
		"text": "Find the Hand Assembler in the Converters category.\nIt's a manual workbench — place it anywhere nearby.\n[R] to rotate, [Left Click] to place.",
		"task": "Place a Hand Assembler",
		"signal_source": "game_manager",
		"signal_name": "building_placed",
		"check_building": "hand_assembler",
	},
	{
		"text": "Click the Hand Assembler to open its popup.\nDrop iron ore into it from your inventory (click the ore, then click the assembler).\nThen click the recipe row to craft iron plates.\n10 iron ore makes 3 iron plates.",
		"task": "Craft iron plates (have 3 in inventory)",
		"check_inventory": "iron_plate",
		"required_count": 3,
	},
	{
		"text": "Great work! But hand-crafting is slow.\nLet's automate with machines.\nFind the Drill in the Extractors category.\nPlace it on an iron deposit — it will auto-extract ore.",
		"task": "Place a Drill on a deposit",
		"signal_source": "game_manager",
		"signal_name": "building_placed",
		"check_building": "drill",
	},
	{
		"text": "The drill extracts ore, but it needs somewhere to send it.\nConveyors transport items between buildings.\nPlace a Conveyor leading away from the drill's output side.",
		"task": "Place a Conveyor",
		"signal_source": "game_manager",
		"signal_name": "building_placed",
		"check_building": "conveyor",
	},
	{
		"text": "Now let's process the ore automatically!\nA Smelter turns raw ore into materials.\nPlace a Smelter at the end of your conveyor line.\nIt will auto-select a recipe based on input.",
		"task": "Place a Smelter",
		"signal_source": "game_manager",
		"signal_name": "building_placed",
		"check_building": "smelter",
	},
	{
		"text": "Your first production line is taking shape.\nNow you need a Sink — it consumes items and earns currency.\nConnect the smelter output to a Sink via conveyors.",
		"task": "Deliver an item to a Sink",
		"signal_source": "game_manager",
		"signal_name": "item_delivered",
	},
	{
		"text": "Excellent! You're earning currency from deliveries.\nContracts give you specific goals and rewards.\nCheck the top-right corner — a tutorial contract appeared.\nDeliver 3 Iron Plates and 3 Copper Rings to complete it.",
		"task": "Complete the tutorial contract",
		"signal_source": "contract_manager",
		"signal_name": "contract_completed",
		"check_contract_title": "Tutorial: First Delivery",
		"setup": "_setup_tutorial_contract",
	},
	{
		"text": "The Recipe Browser shows all recipes in the game.\nUse it to plan your factory — see what inputs each machine needs.\nOpen it with the button that just appeared.",
		"task": "Open the Recipe Browser",
		"signal_source": "hud",
		"signal_name": "recipes_opened",
		"unlocks": ["recipes"],
	},
	{
		"text": "Finally, the Research panel lets you unlock new buildings and upgrades.\nResearch requires Science Packs delivered by Research Labs.\nOpen the Research panel to see the tech tree.",
		"task": "Open the Research panel",
		"signal_source": "hud",
		"signal_name": "research_opened",
		"unlocks": ["research"],
	},
	{
		"text": "That covers the basics!\nExtract → Transport → Process → Deliver.\nExperiment, expand, and automate everything.\nGood luck, engineer!",
		"task": "",
	},
]

## Title used for the fixed tutorial contract.
const TUTORIAL_CONTRACT_TITLE := "Tutorial: First Delivery"

# ── State ─────────────────────────────────────────────────────────────────────

## Current step index. -1 means tutorial is finished/disabled.
var current_step: int = 0
## Whether the tutorial is active.
var active: bool = true
## Accumulator for multi-count tasks (e.g. "mine 3 ore").
var _task_counter: int = 0
## Whether the current step's task is completed (unlocks ">").
var task_done: bool = false

## Tracks which HUD buttons have been unlocked by the tutorial.
## Buttons not in this set should be hidden/disabled.
var unlocked_buttons: Dictionary = {}  # StringName -> true

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_rebuild_unlocked_buttons()

func start() -> void:
	active = true
	current_step = 0
	_task_counter = 0
	task_done = false
	unlocked_buttons.clear()
	_rebuild_unlocked_buttons()
	_connect_current_step()
	_save_to_account()
	step_changed.emit(current_step)

func _rebuild_unlocked_buttons() -> void:
	unlocked_buttons.clear()
	for i in range(current_step):
		var step: Dictionary = steps[i]
		if step.has("unlocks"):
			for btn_name in step["unlocks"]:
				unlocked_buttons[StringName(btn_name)] = true

func get_task_progress() -> Vector2i:
	## Returns (current, required) for the active step. (0,0) if no countable task.
	if current_step < 0 or current_step >= steps.size():
		return Vector2i.ZERO
	var step: Dictionary = steps[current_step]
	var required: int = step.get("required_count", 0)
	if required <= 1 and not step.has("check_inventory"):
		return Vector2i.ZERO
	return Vector2i(_task_counter, required)

func is_button_unlocked(btn_name: StringName) -> bool:
	if not active:
		return true
	return unlocked_buttons.has(btn_name)

# ── Navigation ────────────────────────────────────────────────────────────────

func can_go_next() -> bool:
	if current_step < 0 or current_step >= steps.size():
		return false
	var step: Dictionary = steps[current_step]
	if step.get("task", "") != "" and not task_done:
		return false
	return current_step < steps.size() - 1

func can_go_prev() -> bool:
	return current_step > 0

func go_next() -> void:
	if not can_go_next():
		return
	_disconnect_current_step()
	current_step += 1
	_task_counter = 0
	task_done = false
	_connect_current_step()
	_save_to_account()
	step_changed.emit(current_step)
	if current_step >= steps.size():
		finish()

func go_prev() -> void:
	if not can_go_prev():
		return
	_disconnect_current_step()
	current_step -= 1
	_task_counter = 0
	task_done = true
	step_changed.emit(current_step)

func finish() -> void:
	_disconnect_current_step()
	active = false
	current_step = -1
	for btn_name in ["buildings", "inventory", "research", "recipes"]:
		unlocked_buttons[StringName(btn_name)] = true
		button_unlocked.emit(StringName(btn_name))
	_save_to_account()
	# Generate normal contracts now that tutorial is done
	if ContractManager.active_contracts.is_empty():
		ContractManager._generate_normal_contracts()
	tutorial_finished.emit()

func skip() -> void:
	finish()

# ── Step Setup Callbacks ─────────────────────────────────────────────────────

func _setup_tutorial_contract() -> void:
	# Only add if not already present
	for c in ContractManager.active_contracts:
		if c.title == TUTORIAL_CONTRACT_TITLE:
			return
	var contract := {
		id = 0,
		title = TUTORIAL_CONTRACT_TITLE,
		requirements = [
			{item_id = &"iron_plate", quantity = 3, delivered = 0},
			{item_id = &"copper_ring", quantity = 3, delivered = 0},
		],
		reward_currency = 50,
		reward_research_points = 0,
		is_gate = false,
		gate_ring = -1,
		completed = false,
	}
	ContractManager._add_contract(contract)

# ── Signal Wiring ─────────────────────────────────────────────────────────────

var _connected_object: Object = null
var _connected_signal: StringName = &""

func _connect_current_step() -> void:
	if current_step < 0 or current_step >= steps.size():
		return
	var step: Dictionary = steps[current_step]

	# Unlock buttons required by this step (so the player can complete the task)
	if step.has("unlocks"):
		for btn_name in step["unlocks"]:
			var sn := StringName(btn_name)
			if not unlocked_buttons.has(sn):
				unlocked_buttons[sn] = true
				button_unlocked.emit(sn)

	# Run setup callback if defined
	var setup_method: String = step.get("setup", "")
	if not setup_method.is_empty() and has_method(setup_method):
		call(setup_method)

	var sig_name: String = step.get("signal_name", "")
	if sig_name.is_empty():
		if step.get("task", "") == "":
			task_done = true
		return

	# Inventory check uses polling, not signals
	if step.has("check_inventory"):
		return

	var source: Object = _get_signal_source(step.get("signal_source", ""))
	if not source:
		return

	var sig := StringName(sig_name)
	if source.has_signal(sig):
		source.connect(sig, _on_task_signal)
		_connected_object = source
		_connected_signal = sig

func _disconnect_current_step() -> void:
	if _connected_object and is_instance_valid(_connected_object) and _connected_signal != &"":
		if _connected_object.is_connected(_connected_signal, _on_task_signal):
			_connected_object.disconnect(_connected_signal, _on_task_signal)
	_connected_object = null
	_connected_signal = &""

func _get_signal_source(source_name: String) -> Object:
	match source_name:
		"game_manager":
			return GameManager
		"player":
			return GameManager.player if GameManager.player else null
		"research_manager":
			return ResearchManager
		"contract_manager":
			return ContractManager
		"hud":
			return _get_hud()
	return null

func _get_hud() -> Control:
	var tree := get_tree()
	if not tree:
		return null
	var nodes := tree.get_nodes_in_group("hud")
	if nodes.size() > 0:
		return nodes[0]
	return null

func _on_task_signal(arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if not active or current_step < 0 or current_step >= steps.size():
		return
	if task_done:
		return

	var step: Dictionary = steps[current_step]

	# Check building filter
	if step.has("check_building") and arg1 is StringName:
		if arg1 != StringName(step["check_building"]):
			return

	# Check item filter
	if step.has("check_item") and arg1 is StringName:
		if arg1 != StringName(step["check_item"]):
			return

	# Check contract title filter
	if step.has("check_contract_title") and arg1 is Dictionary:
		if arg1.get("title", "") != step["check_contract_title"]:
			return

	# Count-based tasks
	var required: int = step.get("required_count", 1)
	_task_counter += 1
	task_progress_changed.emit(_task_counter, required)
	if _task_counter >= required:
		task_done = true
		task_completed.emit(current_step)

# ── Inventory Polling ─────────────────────────────────────────────────────────
# For the "craft iron plates" step — polls player inventory each frame.

func _process(_delta: float) -> void:
	if not active or task_done:
		return
	if current_step < 0 or current_step >= steps.size():
		return
	var step: Dictionary = steps[current_step]
	if not step.has("check_inventory"):
		return
	var item_id := StringName(step["check_inventory"])
	var required: int = step.get("required_count", 1)
	var player: Player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	var count := 0
	for slot in player.inventory:
		if slot != null and slot.item_id == item_id:
			count += slot.quantity
	if count != _task_counter:
		_task_counter = count
		task_progress_changed.emit(count, required)
	if count >= required:
		task_done = true
		task_completed.emit(current_step)

# ── Per-Account Persistence ──────────────────────────────────────────────────
# Tutorial progress is saved in the account meta.json, not in the run save.
# This means it persists across new games within the same account slot.

func _save_to_account() -> void:
	var slot_id := AccountManager.active_slot
	var meta := AccountManager.load_meta(slot_id)
	if active:
		meta["tutorial_step"] = current_step
	else:
		meta["tutorial_step"] = -1
	AccountManager.save_meta(slot_id, meta)

func load_from_account() -> void:
	var slot_id := AccountManager.active_slot
	var meta := AccountManager.load_meta(slot_id)
	if not meta.has("tutorial_step"):
		# First time — tutorial not started yet, will be started by game_world
		return
	var saved_step: int = int(meta["tutorial_step"])
	if saved_step < 0:
		# Tutorial was completed/skipped
		active = false
		current_step = -1
		_rebuild_unlocked_buttons()
		# Ensure all buttons unlocked
		for btn_name in ["buildings", "inventory", "research", "recipes"]:
			unlocked_buttons[StringName(btn_name)] = true
		tutorial_finished.emit()
		return
	# Resume from saved step
	active = true
	current_step = saved_step
	_task_counter = 0
	task_done = false
	_rebuild_unlocked_buttons()
	_connect_current_step()
	step_changed.emit(current_step)

# ── Serialization (run save compatibility) ────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"active": active,
		"current_step": current_step,
	}

func deserialize(data: Dictionary) -> void:
	# Run save stores tutorial state for backward compat, but account meta
	# is the primary source. Only use run save if account meta has no data.
	var slot_id := AccountManager.active_slot
	var meta := AccountManager.load_meta(slot_id)
	if meta.has("tutorial_step"):
		return  # Account meta takes priority
	active = data.get("active", true)
	current_step = data.get("current_step", 0)
	_task_counter = 0
	task_done = false
	_rebuild_unlocked_buttons()
	if active and current_step >= 0:
		_connect_current_step()
	step_changed.emit(current_step)
