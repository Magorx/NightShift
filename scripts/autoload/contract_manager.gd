extends Node

## Dynamic Contract System. Manages gate contracts (unlock research rings)
## and procedurally generated side contracts (reward currency + research points).
## Registered as an autoload singleton.

## Contract data structure:
## {
##   id: int,
##   title: String,
##   requirements: Array[{item_id: StringName, quantity: int, delivered: int}],
##   reward_currency: int,
##   reward_research_points: int,
##   is_gate: bool,
##   gate_ring: int,
##   completed: bool,
## }

var active_contracts: Array = []
var completed_contract_ids: Array = []
var _next_id: int = 1
var _contracts_completed_in_ring: Dictionary = {}  # ring -> count
var _current_ring: int = 0  # Highest ring unlocked (0 = starting)

## Items available at each ring tier for side contract generation.
const RING_ITEMS: Dictionary = {
	0: [&"iron_ore", &"copper_ore", &"coal", &"stone", &"iron_plate"],
	1: [&"copper_plate", &"tin_plate", &"copper_wire", &"iron_gear", &"iron_tube", &"glass", &"brick"],
	2: [&"circuit_board", &"motor", &"battery_cell", &"steel_frame", &"steel", &"steel_beam"],
	3: [&"advanced_circuit", &"processor", &"engine", &"robo_frame"],
}

## Gate contract definitions: ring -> {requirements, title}
const GATE_DEFS: Dictionary = {
	1: {
		title = "Gate: Unlock Ring 1",
		requirements = [
			{item_id = &"iron_plate", quantity = 20},
			{item_id = &"copper_wire", quantity = 10},
		],
	},
	2: {
		title = "Gate: Unlock Ring 2",
		requirements = [
			{item_id = &"motor", quantity = 10},
			{item_id = &"circuit_board", quantity = 10},
		],
	},
	3: {
		title = "Gate: Unlock Ring 3",
		requirements = [
			{item_id = &"processor", quantity = 5},
			{item_id = &"robo_frame", quantity = 5},
		],
	},
}

## Maximum number of active side contracts (gate contracts are extra).
const MAX_SIDE_CONTRACTS := 3

signal contract_completed(contract: Dictionary)
signal contract_added(contract: Dictionary)

func _ready():
	call_deferred("_generate_initial_contracts")

func _generate_initial_contracts():
	if not active_contracts.is_empty():
		return  # Already have contracts (loaded from save)
	# Start with 2 simple side contracts
	_add_contract(_generate_side_contract(0))
	_add_contract(_generate_side_contract(0))
	# Add ring 1 gate contract
	_add_contract(_generate_gate_contract(1))

# ── Contract Generation ──────────────────────────────────────────────────────

func _generate_gate_contract(ring: int) -> Dictionary:
	var gate_def: Dictionary = GATE_DEFS.get(ring, {})
	if gate_def.is_empty():
		return {}
	var reqs: Array = []
	for r in gate_def.requirements:
		reqs.append({item_id = r.item_id, quantity = int(r.quantity), delivered = 0})
	# Gate rewards: generous currency + research points
	var total_value := 0
	for req in reqs:
		var item_def = GameManager.get_item_def(req.item_id)
		var ev: int = item_def.export_value if item_def else 1
		total_value += ev * req.quantity
	return {
		id = _next_id,
		title = gate_def.title,
		requirements = reqs,
		reward_currency = total_value * 3,
		reward_research_points = total_value * 2,
		is_gate = true,
		gate_ring = ring,
		completed = false,
	}

func _generate_side_contract(ring: int) -> Dictionary:
	# Collect all items available up to this ring
	var available_items: Array = []
	for r in range(ring + 1):
		if RING_ITEMS.has(r):
			available_items.append_array(RING_ITEMS[r])

	if available_items.is_empty():
		return {}

	# Pick 1-3 different items
	available_items.shuffle()
	var num_items: int = mini(randi_range(1, 3), available_items.size())
	var chosen: Array = available_items.slice(0, num_items)

	var completed_count: int = _contracts_completed_in_ring.get(ring, 0)
	var base_quantity: int = (ring + 1) * 5
	var scaling: float = pow(1.3, completed_count)

	var reqs: Array = []
	var total_value := 0
	for item_id in chosen:
		var qty: int = ceili(base_quantity * scaling)
		# Add some randomness: +/- 30%
		var jitter: float = randf_range(0.7, 1.3)
		qty = maxi(1, ceili(qty * jitter))
		reqs.append({item_id = item_id, quantity = qty, delivered = 0})
		var item_def = GameManager.get_item_def(item_id)
		var ev: int = item_def.export_value if item_def else 1
		total_value += ev * qty

	# Build title from item names
	var title_parts: Array = []
	for req in reqs:
		var item_def = GameManager.get_item_def(req.item_id)
		var name: String = item_def.display_name if item_def else str(req.item_id)
		title_parts.append("%d %s" % [req.quantity, name])
	var title: String = "Deliver: " + ", ".join(title_parts)

	return {
		id = _next_id,
		title = title,
		requirements = reqs,
		reward_currency = ceili(total_value * 1.5),
		reward_research_points = ceili(total_value * 0.5),
		is_gate = false,
		gate_ring = -1,
		completed = false,
	}

func _add_contract(contract: Dictionary) -> void:
	if contract.is_empty():
		return
	contract.id = _next_id
	_next_id += 1
	active_contracts.append(contract)
	contract_added.emit(contract)

# ── Delivery Integration ─────────────────────────────────────────────────────

func on_item_delivered(item_id: StringName) -> void:
	for contract in active_contracts:
		if contract.completed:
			continue
		for req in contract.requirements:
			if req.item_id == item_id and req.delivered < req.quantity:
				req.delivered += 1
				break
		_check_contract_completion(contract)

func _check_contract_completion(contract: Dictionary) -> void:
	if contract.completed:
		return
	for req in contract.requirements:
		if req.delivered < req.quantity:
			return
	# Contract complete!
	contract.completed = true

	# Award rewards
	GameManager.total_currency += contract.reward_currency

	# Track completion
	completed_contract_ids.append(contract.id)
	var ring: int = _current_ring
	if not _contracts_completed_in_ring.has(ring):
		_contracts_completed_in_ring[ring] = 0
	_contracts_completed_in_ring[ring] += 1

	# Handle gate contract: advance ring
	if contract.is_gate:
		var new_ring: int = contract.gate_ring
		if new_ring > _current_ring:
			_current_ring = new_ring

	contract_completed.emit(contract)

	# Remove from active and generate replacements (deferred to avoid modifying array during iteration)
	call_deferred("_post_completion", contract)

func _post_completion(contract: Dictionary) -> void:
	active_contracts.erase(contract)

	if contract.is_gate:
		# Add next gate if one exists
		var next_ring: int = contract.gate_ring + 1
		if GATE_DEFS.has(next_ring):
			_add_contract(_generate_gate_contract(next_ring))

	# Ensure we have enough side contracts
	var side_count := 0
	for c in active_contracts:
		if not c.is_gate:
			side_count += 1
	while side_count < MAX_SIDE_CONTRACTS:
		_add_contract(_generate_side_contract(_current_ring))
		side_count += 1

# ── Serialization ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data := {}
	data["next_id"] = _next_id
	data["current_ring"] = _current_ring
	data["completed_ids"] = completed_contract_ids.duplicate()

	var ring_counts := {}
	for ring_key in _contracts_completed_in_ring:
		ring_counts[str(ring_key)] = _contracts_completed_in_ring[ring_key]
	data["ring_counts"] = ring_counts

	var contracts_data: Array = []
	for contract in active_contracts:
		var reqs: Array = []
		for req in contract.requirements:
			reqs.append({
				item_id = str(req.item_id),
				quantity = req.quantity,
				delivered = req.delivered,
			})
		contracts_data.append({
			id = contract.id,
			title = contract.title,
			requirements = reqs,
			reward_currency = contract.reward_currency,
			reward_research_points = contract.reward_research_points,
			is_gate = contract.is_gate,
			gate_ring = contract.gate_ring,
			completed = contract.completed,
		})
	data["active"] = contracts_data
	return data

func deserialize(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	_current_ring = int(data.get("current_ring", 0))

	completed_contract_ids.clear()
	for cid in data.get("completed_ids", []):
		completed_contract_ids.append(int(cid))

	_contracts_completed_in_ring.clear()
	var ring_counts: Dictionary = data.get("ring_counts", {})
	for ring_str in ring_counts:
		_contracts_completed_in_ring[int(ring_str)] = int(ring_counts[ring_str])

	active_contracts.clear()
	for entry in data.get("active", []):
		var reqs: Array = []
		for req_data in entry.get("requirements", []):
			reqs.append({
				item_id = StringName(req_data.get("item_id", "")),
				quantity = int(req_data.get("quantity", 0)),
				delivered = int(req_data.get("delivered", 0)),
			})
		active_contracts.append({
			id = int(entry.get("id", 0)),
			title = str(entry.get("title", "")),
			requirements = reqs,
			reward_currency = int(entry.get("reward_currency", 0)),
			reward_research_points = int(entry.get("reward_research_points", 0)),
			is_gate = bool(entry.get("is_gate", false)),
			gate_ring = int(entry.get("gate_ring", -1)),
			completed = bool(entry.get("completed", false)),
		})

func reset() -> void:
	active_contracts.clear()
	completed_contract_ids.clear()
	_next_id = 1
	_contracts_completed_in_ring.clear()
	_current_ring = 0
