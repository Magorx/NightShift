## Dynamically builds factory production lines across a large map.
## Reads the building library and recipes at runtime — no hardcoded building IDs.
## Each deposit cluster gets: extractors → varied conveyor paths (tunnels, L-turns,
## junctions) → horizontal bus → splitter → multiple converters → sinks,
## and sinks.

const TILE_SIZE := 32
const BLOCK_SPACING := 28   # tiles between factory block centers
const CLUSTER_RADIUS := 3   # deposit cluster radius in tiles
const BUS_OFFSET := 5       # rows below lowest deposit for the collection bus
const CONV_GAP := 3         # conveyors between splitter and converter input
const BRANCH_DROP := 4      # rows below bus for second converter branch
const SINK_GAP := 4         # conveyors after converter output relay before sink

# Tile source IDs — must match game_world.gd / world_generator.gd
const TILE_IRON := 1
const TILE_COPPER := 2
const TILE_COAL := 3

const ITEM_TILE := {
	&"iron_ore": TILE_IRON,
	&"copper_ore": TILE_COPPER,
	&"coal": TILE_COAL,
}

var _bids: Dictionary  # discovered building IDs by role

# ── Public entry point ────────────────────────────────────────────────────────

func generate(tile_map: TileMapLayer, map_size: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.world_seed + 54321

	_bids = _discover_buildings()
	if _bids.extractor.is_empty() or _bids.conveyor.is_empty():
		push_warning("StressTest: missing extractor or conveyor — aborting")
		return

	var chains := _build_processing_chains()
	var clusters := _create_deposit_clusters(tile_map, map_size, rng)

	for cluster in clusters:
		_build_factory_line(cluster, chains, map_size, rng)

	print("StressTest: placed %d factory blocks across %dx%d map" % [clusters.size(), map_size, map_size])

# ── Building discovery ────────────────────────────────────────────────────────

func _discover_buildings() -> Dictionary:
	var result := {
		extractor = &"",
		conveyor = &"",
		sink = &"",
		junction = &"",
		splitter = &"",
		tunnel_in = &"",
		tunnel_out = &"",
		converters = {},   # converter_type (String) → building id
	}
	# First pass: collect only unlocked (no research_tag) buildings
	for id: StringName in GameManager.building_defs:
		var def: Resource = GameManager.building_defs[id]
		if def.research_tag != &"":
			continue
		match def.category:
			"extractor":
				if result.extractor.is_empty(): result.extractor = id
			"conveyor":
				if result.conveyor.is_empty(): result.conveyor = id
			"sink":
				if result.sink.is_empty(): result.sink = id
			"converter":
				result.converters[str(id)] = id
			"junction":
				if result.junction.is_empty(): result.junction = id
			"splitter":
				if result.splitter.is_empty(): result.splitter = id
			"tunnel":
				if result.tunnel_in.is_empty(): result.tunnel_in = id
			"tunnel_output":
				if result.tunnel_out.is_empty(): result.tunnel_out = id
	return result

## Maps item_id → {converter_id, recipe} for the first matching recipe.
func _build_processing_chains() -> Dictionary:
	var chains := {}
	for conv_type: String in GameManager.recipes_by_type:
		var conv_id := StringName(conv_type)
		if not GameManager.building_defs.has(conv_id):
			continue
		var recipes: Array = GameManager.recipes_by_type[conv_type]
		for recipe in recipes:
			for inp_stack in recipe.inputs:
				var item_id: StringName = inp_stack.item.id
				if not chains.has(item_id):
					chains[item_id] = {converter_id = conv_id, recipe = recipe}
	return chains

# ── Deposit cluster creation ──────────────────────────────────────────────────

func _create_deposit_clusters(tile_map: TileMapLayer, map_size: int, rng: RandomNumberGenerator) -> Array:
	var clusters: Array = []
	var margin := 10
	var center := map_size / 2
	var center_exclusion := 20

	var deposit_items: Array = ITEM_TILE.keys()
	if deposit_items.is_empty():
		return clusters
	var type_idx := 0

	var bx := margin
	while bx < map_size - margin:
		var by := margin
		while by < map_size - margin:
			if absi(bx - center) < center_exclusion and absi(by - center) < center_exclusion:
				by += BLOCK_SPACING
				continue

			var item_id: StringName = deposit_items[type_idx % deposit_items.size()]
			type_idx += 1
			var tile_id: int = ITEM_TILE[item_id]

			var positions: Array[Vector2i] = []
			for dx in range(-CLUSTER_RADIUS, CLUSTER_RADIUS + 1):
				for dy in range(-CLUSTER_RADIUS, CLUSTER_RADIUS + 1):
					if dx * dx + dy * dy > CLUSTER_RADIUS * CLUSTER_RADIUS:
						continue
					var pos := Vector2i(bx + dx, by + dy)
					if pos.x < 2 or pos.y < 2 or pos.x >= map_size - 2 or pos.y >= map_size - 2:
						continue
					if GameManager.walls.has(pos):
						continue
					if rng.randf() < 0.6:
						tile_map.set_cell(pos, tile_id, Vector2i(0, 0))
						GameManager.deposits[pos] = item_id
						positions.append(pos)

			if positions.size() >= 3:
				clusters.append({center = Vector2i(bx, by), item_id = item_id, positions = positions})

			by += BLOCK_SPACING
		bx += BLOCK_SPACING
	return clusters

# ── Factory line builder ──────────────────────────────────────────────────────

func _build_factory_line(cluster: Dictionary, chains: Dictionary, map_size: int, rng: RandomNumberGenerator) -> void:
	var positions: Array = cluster.positions
	var item_id: StringName = cluster.item_id

	# ── Compute bounds ──
	var min_x := 99999
	var max_x := -99999
	var max_y := -99999
	for pos: Vector2i in positions:
		min_x = mini(min_x, pos.x)
		max_x = maxi(max_x, pos.x)
		max_y = maxi(max_y, pos.y)

	var bus_y := max_y + BUS_OFFSET
	if bus_y >= map_size - 12:
		return

	# ── Phase 1: Place drills ──
	var columns: Dictionary = {}   # x → topmost y
	for pos: Vector2i in positions:
		if not columns.has(pos.x) or pos.y < columns[pos.x]:
			columns[pos.x] = pos.y

	var drill_xs: Array[int] = []
	for x: int in columns:
		var y: int = columns[x]
		if not GameManager.can_place_building(_bids.extractor, Vector2i(x, y), map_size, 1):
			continue
		GameManager.place_building(_bids.extractor, Vector2i(x, y), 1)  # rotation=1 → output DOWN
		drill_xs.append(x)

	if drill_xs.is_empty():
		return
	drill_xs.sort()

	# ── Phase 2: Vertical feeds from drills to bus (varied paths) ──
	var col_idx := 0
	for x: int in drill_xs:
		var drill_y: int = columns[x]
		var feed_start := drill_y + 1
		var feed_end := bus_y - 1
		var feed_len := feed_end - feed_start + 1
		var feed_type := col_idx % 3
		col_idx += 1

		if feed_type == 0 and feed_len >= 3 and _has_tunnels():
			_place_tunnel_feed(x, feed_start, feed_end, map_size)
		elif feed_type == 1 and feed_len >= 4 and not _bids.junction.is_empty():
			_place_junction_feed(x, feed_start, feed_end, map_size)
		else:
			for y in range(feed_start, feed_end + 1):
				_try_place(_bids.conveyor, Vector2i(x, y), map_size, 1)

	# ── Phase 3: Horizontal bus with junctions mixed in ──
	var splitter_x := max_x + 3
	if splitter_x >= map_size - 2:
		return

	var bus_idx := 0
	for x in range(min_x, splitter_x):
		if bus_idx % 5 == 3 and not _bids.junction.is_empty():
			if not _try_place(_bids.junction, Vector2i(x, bus_y), map_size):
				_try_place(_bids.conveyor, Vector2i(x, bus_y), map_size, 0)
		else:
			_try_place(_bids.conveyor, Vector2i(x, bus_y), map_size, 0)
		bus_idx += 1

	# ── Phase 4: Processing ──
	var chain = chains.get(item_id)
	var is_coal := (item_id == &"coal")

	if chain and not _bids.splitter.is_empty() and splitter_x + 14 < map_size:
		# Has recipe → splitter → 2 converter branches
		if _try_place(_bids.splitter, Vector2i(splitter_x, bus_y), map_size, 0):
			_place_dual_converter_lines(chain, splitter_x, bus_y, map_size)
		else:
			_try_place(_bids.conveyor, Vector2i(splitter_x, bus_y), map_size, 0)
			_place_single_line(chain, splitter_x + 1, bus_y, map_size)

	else:
		# Fallback: bus → sink
		_try_place(_bids.conveyor, Vector2i(splitter_x, bus_y), map_size, 0)
		_place_simple_sink(splitter_x + 1, bus_y, map_size)

# ── Vertical feed patterns ────────────────────────────────────────────────────

func _has_tunnels() -> bool:
	return not _bids.tunnel_in.is_empty() and not _bids.tunnel_out.is_empty()

func _place_tunnel_feed(x: int, start_y: int, end_y: int, map_size: int) -> void:
	var tin := Vector2i(x, start_y)
	var tout := Vector2i(x, end_y)
	if (GameManager.can_place_building(_bids.tunnel_in, tin, map_size, 1) and
		GameManager.can_place_building(_bids.tunnel_out, tout, map_size, 1)):
		GameManager.place_building(_bids.tunnel_in, tin, 1)
		GameManager.place_building(_bids.tunnel_out, tout, 1)
		_link_tunnel_pair(tin, tout)
	else:
		# Fallback to straight conveyors
		for y in range(start_y, end_y + 1):
			_try_place(_bids.conveyor, Vector2i(x, y), map_size, 1)

func _place_junction_feed(x: int, start_y: int, end_y: int, map_size: int) -> void:
	var mid_y := start_y + (end_y - start_y) / 2
	for y in range(start_y, end_y + 1):
		if y == mid_y:
			if not _try_place(_bids.junction, Vector2i(x, y), map_size):
				_try_place(_bids.conveyor, Vector2i(x, y), map_size, 1)
		else:
			_try_place(_bids.conveyor, Vector2i(x, y), map_size, 1)

# ── Processing layouts ────────────────────────────────────────────────────────

## Splitter at (splitter_x, bus_y) → branch 1 RIGHT, branch 2 DOWN+RIGHT → 2 converters → 2 sinks.
func _place_dual_converter_lines(chain: Dictionary, splitter_x: int, bus_y: int, map_size: int) -> void:
	var conv_id: StringName = chain.converter_id
	var conv_x := splitter_x + CONV_GAP

	# ── Branch 1: RIGHT → conveyors → converter 1 → output relay → conveyors → sink ──
	for x in range(splitter_x + 1, conv_x):
		_try_place(_bids.conveyor, Vector2i(x, bus_y), map_size, 0)

	var conv1_pos := Vector2i(conv_x, bus_y)
	if GameManager.can_place_building(conv_id, conv1_pos, map_size, 0):
		GameManager.place_building(conv_id, conv1_pos, 0)
		var relay := _place_output_relay(conv_id, conv1_pos, 0, map_size)
		_place_output_chain(relay.x + 1, bus_y, map_size)
	else:
		_place_simple_sink(conv_x, bus_y, map_size)

	# ── Branch 2: DOWN from splitter → L-turn → conveyors → converter 2 → sink ──
	var branch2_y := bus_y + BRANCH_DROP
	if branch2_y >= map_size - 8:
		return

	# Vertical conveyors going DOWN
	for y in range(bus_y + 1, branch2_y):
		_try_place(_bids.conveyor, Vector2i(splitter_x, y), map_size, 1)
	# L-turn: RIGHT-facing conveyor at branch2_y (pulls from above)
	_try_place(_bids.conveyor, Vector2i(splitter_x, branch2_y), map_size, 0)

	# Horizontal conveyors to converter 2
	for x in range(splitter_x + 1, conv_x):
		_try_place(_bids.conveyor, Vector2i(x, branch2_y), map_size, 0)

	var conv2_pos := Vector2i(conv_x, branch2_y)
	if GameManager.can_place_building(conv_id, conv2_pos, map_size, 0):
		GameManager.place_building(conv_id, conv2_pos, 0)
		var relay := _place_output_relay(conv_id, conv2_pos, 0, map_size)
		_place_output_chain(relay.x + 1, branch2_y, map_size)
	else:
		_place_simple_sink(conv_x, branch2_y, map_size)

## Single converter line (no splitter fallback).
func _place_single_line(chain: Dictionary, start_x: int, bus_y: int, map_size: int) -> void:
	var conv_id: StringName = chain.converter_id
	var conv_x := start_x + 2
	for x in range(start_x, conv_x):
		_try_place(_bids.conveyor, Vector2i(x, bus_y), map_size, 0)
	var conv_pos := Vector2i(conv_x, bus_y)
	if GameManager.can_place_building(conv_id, conv_pos, map_size, 0):
		GameManager.place_building(conv_id, conv_pos, 0)
		var relay := _place_output_relay(conv_id, conv_pos, 0, map_size)
		_place_output_chain(relay.x + 1, bus_y, map_size)
	else:
		_place_simple_sink(conv_x, bus_y, map_size)

## Simple sink: a couple conveyors then sink.
func _place_simple_sink(x: int, y: int, map_size: int) -> void:
	for dx in range(2):
		_try_place(_bids.conveyor, Vector2i(x + dx, y), map_size, 0)
	if not _bids.sink.is_empty():
		_try_place(_bids.sink, Vector2i(x + 2, y), map_size)

## Output chain: conveyors going RIGHT then a sink.
func _place_output_chain(start_x: int, y: int, map_size: int) -> void:
	var sink_x := start_x + SINK_GAP
	for x in range(start_x, sink_x):
		_try_place(_bids.conveyor, Vector2i(x, y), map_size, 0)
	if not _bids.sink.is_empty():
		_try_place(_bids.sink, Vector2i(sink_x, y), map_size)

# ── Output relay ──────────────────────────────────────────────────────────────

## Place a conveyor at the converter's output cell to relay items out.
## Converter output cells are NOT shape cells, so a conveyor fits there.
## The relay conveyor pulls items from the converter and forwards them downstream.
func _place_output_relay(conv_id: StringName, conv_pos: Vector2i, rotation: int, map_size: int) -> Vector2i:
	var def: Resource = GameManager.building_defs.get(conv_id)
	if not def:
		return conv_pos + Vector2i(1, 0)
	var outputs: Array = def.get_rotated_outputs(rotation)
	if outputs.is_empty():
		return conv_pos + Vector2i(1, 0)
	var output_cell: Vector2i = Vector2i(outputs[0].cell)
	var output_pos: Vector2i = conv_pos + output_cell
	# Determine conveyor direction from output mask
	var conv_rot := 0
	var mask: Array = outputs[0].mask
	for d in range(4):
		if mask[d]:
			conv_rot = d
			break
	_try_place(_bids.conveyor, output_pos, map_size, conv_rot)
	return output_pos

# ── Placement helpers ─────────────────────────────────────────────────────────

func _try_place(building_id: StringName, pos: Vector2i, map_size: int, rotation: int = 0) -> bool:
	if building_id.is_empty():
		return false
	if GameManager.can_place_building(building_id, pos, map_size, rotation):
		GameManager.place_building(building_id, pos, rotation)
		return true
	return false

func _link_tunnel_pair(input_pos: Vector2i, output_pos: Vector2i) -> void:
	var in_building = GameManager.buildings.get(input_pos)
	var out_building = GameManager.buildings.get(output_pos)
	if not in_building or not out_building:
		return
	if not in_building.logic or not out_building.logic:
		return
	var dist := absi(output_pos.x - input_pos.x) + absi(output_pos.y - input_pos.y)
	in_building.logic.setup_pair(out_building.logic, dist)
	out_building.logic.setup_pair(in_building.logic, dist)
