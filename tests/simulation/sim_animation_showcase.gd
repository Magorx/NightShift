extends "simulation_base.gd"

## Showcase simulation: places all 6 newly-animated buildings in a row,
## each fed by sources so their procedural animations are all visible.
## Best viewed with: --visual flag (interactive, windowed, x2 speed).

func run_simulation() -> void:
	# Layout: 6 buildings spaced horizontally, each fed by a source chain.
	# Row y=15, buildings at x = 10, 20, 30, 40, 50, 60
	# Each gets: source -> conveyors -> building -> conveyors -> sink

	# ── 1. SMELTER (2x3, anchor at input cell) ─────────────────────────
	# Source produces iron_ore
	_place_source(Vector2i(6, 15), &"iron_ore")
	sim_place_building(&"conveyor", Vector2i(7, 15), 0)
	sim_place_building(&"conveyor", Vector2i(8, 15), 0)
	sim_place_building(&"conveyor", Vector2i(9, 15), 0)
	sim_place_building(&"smelter", Vector2i(10, 15), 0)
	# Smelter output gap at (11,15)
	sim_place_building(&"conveyor", Vector2i(11, 15), 0)
	sim_place_building(&"sink", Vector2i(12, 15), 0)

	# ── 2. COAL BURNER (2x1) ──────────────────────────────────────────
	# Needs coal deposit for the drill, or a source
	sim_add_deposit(Vector2i(18, 20), &"coal")
	GameManager.deposit_stocks[Vector2i(18, 20)] = -1
	sim_place_building(&"drill", Vector2i(18, 20), 0)
	sim_place_building(&"conveyor", Vector2i(19, 20), 0)
	sim_place_building(&"coal_burner", Vector2i(20, 20), 0)
	# Coal burner has no item output, just energy

	# ── 3. PRESS (2x1) ───────────────────────────────────────────────
	_place_source(Vector2i(6, 25), &"iron_plate")
	sim_place_building(&"conveyor", Vector2i(7, 25), 0)
	sim_place_building(&"conveyor", Vector2i(8, 25), 0)
	sim_place_building(&"conveyor", Vector2i(9, 25), 0)
	sim_place_building(&"press", Vector2i(10, 25), 0)
	# Press output at right side
	sim_place_building(&"conveyor", Vector2i(12, 25), 0)
	sim_place_building(&"sink", Vector2i(13, 25), 0)

	# ── 4. RESEARCH LAB (2x2) ────────────────────────────────────────
	# Needs science packs — use source producing science_pack_1
	_place_source(Vector2i(6, 30), &"science_pack_1")
	sim_place_building(&"conveyor", Vector2i(7, 30), 0)
	sim_place_building(&"conveyor", Vector2i(8, 30), 0)
	sim_place_building(&"conveyor", Vector2i(9, 30), 0)
	# Research lab anchor — needs energy
	sim_place_building(&"research_lab", Vector2i(10, 30), 0)
	# Power it with a solar panel nearby
	sim_place_building(&"solar_panel", Vector2i(10, 28), 0)
	sim_place_building(&"energy_pole", Vector2i(10, 29), 0)
	# Start a research so the lab actually works
	var available := ResearchManager.get_available_techs()
	for tech in available:
		if tech.type == &"normal":
			ResearchManager.start_research(tech.id)
			break

	# ── 5. CHEMICAL PLANT (2x2) ──────────────────────────────────────
	# Needs biomass + acid -> bio compound
	_place_source(Vector2i(6, 35), &"biomass")
	sim_place_building(&"conveyor", Vector2i(7, 35), 0)
	sim_place_building(&"conveyor", Vector2i(8, 35), 0)
	sim_place_building(&"conveyor", Vector2i(9, 35), 0)
	_place_source(Vector2i(6, 36), &"acid")
	sim_place_building(&"conveyor", Vector2i(7, 36), 0)
	sim_place_building(&"conveyor", Vector2i(8, 36), 0)
	sim_place_building(&"conveyor", Vector2i(9, 36), 0)
	sim_place_building(&"chemical_plant", Vector2i(10, 35), 0)
	# Chemical plant needs energy
	sim_place_building(&"solar_panel", Vector2i(10, 33), 0)
	sim_place_building(&"energy_pole", Vector2i(10, 34), 0)
	# Output
	sim_place_building(&"conveyor", Vector2i(12, 35), 0)
	sim_place_building(&"sink", Vector2i(13, 35), 0)

	# ── 6. SINK (1x1) ────────────────────────────────────────────────
	# Simple: source -> conveyors -> sink
	_place_source(Vector2i(18, 25), &"iron_ore")
	sim_place_building(&"conveyor", Vector2i(19, 25), 0)
	sim_place_building(&"conveyor", Vector2i(20, 25), 0)
	sim_place_building(&"conveyor", Vector2i(21, 25), 0)
	sim_place_building(&"sink", Vector2i(22, 25), 0)

	# ── Camera: position player near the center of the showcase ──────
	if GameManager.player:
		GameManager.player.position = Vector2(12, 27) * 32

	# In visual mode, just let it run indefinitely
	if sim_mode == "visual":
		return

	# In fast mode, run briefly and verify at least some buildings are active
	await sim_advance_seconds(15)

	# Check smelter produced
	var sink1 = GameManager.get_building_at(Vector2i(12, 15))
	if sink1 and sink1.logic:
		var consumed: int = sink1.logic.get("items_consumed") if sink1.logic.get("items_consumed") != null else 0
		sim_assert(consumed > 0, "Smelter chain produced items (got %d)" % consumed)

	# Check standalone sink consumed
	var sink6 = GameManager.get_building_at(Vector2i(22, 25))
	if sink6 and sink6.logic:
		var consumed6: int = sink6.logic.get("items_consumed") if sink6.logic.get("items_consumed") != null else 0
		sim_assert(consumed6 > 0, "Standalone sink consumed items (got %d)" % consumed6)

	sim_finish()

func _place_source(pos: Vector2i, p_item_id: StringName) -> void:
	var building = sim_place_building(&"source", pos, 0)
	if building and building.logic:
		building.logic.item_id = p_item_id
		building.logic.enabled_items = [p_item_id]
