extends SceneTree
## Economy balance analysis tool.
## Run: $GODOT --headless --path . --script res://tools/balance_check.gd

# ── Data containers ───────────────────────────────────────────────────────────

var items: Dictionary = {}       # id -> ItemDef
var recipes: Array = []          # Array[RecipeDef]
var buildings: Dictionary = {}   # id -> BuildingDef

# Hardcoded production parameters (must match extractor.gd / conveyor.gd)
const DRILL_INTERVAL := 2.0     # seconds per item (drill mk1)
const DRILL_MK2_INTERVAL := 1.0
const CONVEYOR_MK1_TIME := 1.0  # traverse time
const CONVEYOR_MK2_TIME := 0.5
const CONVEYOR_MK3_TIME := 0.333

func _init() -> void:
	_load_all_items()
	_load_all_recipes()
	# Note: building loading skipped — extract_from_scene() requires autoloads.
	# Building costs are printed from hardcoded lists below.

	print("=" .repeat(70))
	print("  ECONOMY BALANCE ANALYSIS")
	print("=" .repeat(70))
	print("")

	_print_extraction_rates()
	_print_conveyor_throughput()
	_print_recipe_rates()
	_print_production_chains()
	#_print_building_costs()  # requires building loading which needs autoloads
	_print_milestones()

	quit()

# ── Loaders ───────────────────────────────────────────────────────────────────

func _load_all_items() -> void:
	var dir := DirAccess.open("res://resources/items")
	if not dir:
		printerr("Cannot open res://resources/items")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = ResourceLoader.load("res://resources/items/" + fname)
			if res is ItemDef:
				items[res.id] = res
		fname = dir.get_next()
	dir.list_dir_end()

func _load_all_recipes() -> void:
	var dir := DirAccess.open("res://resources/recipes")
	if not dir:
		printerr("Cannot open res://resources/recipes")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = ResourceLoader.load("res://resources/recipes/" + fname)
			if res is RecipeDef:
				recipes.append(res)
		fname = dir.get_next()
	dir.list_dir_end()

func _load_all_buildings() -> void:
	var base_path := "res://buildings"
	var dir := DirAccess.open(base_path)
	if not dir:
		printerr("Cannot open res://buildings")
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "shared":
			var sub_dir := DirAccess.open(base_path + "/" + folder)
			if sub_dir:
				sub_dir.list_dir_begin()
				var sub_fname := sub_dir.get_next()
				while sub_fname != "":
					if sub_fname.ends_with(".tres"):
						var res = ResourceLoader.load(base_path + "/" + folder + "/" + sub_fname)
						if res is BuildingDef:
							buildings[res.id] = res
					sub_fname = sub_dir.get_next()
				sub_dir.list_dir_end()
		folder = dir.get_next()
	dir.list_dir_end()

# ── Analysis sections ─────────────────────────────────────────────────────────

func _print_extraction_rates() -> void:
	print("--- EXTRACTION RATES ---")
	var drill_per_min := 60.0 / DRILL_INTERVAL
	var drill2_per_min := 60.0 / DRILL_MK2_INTERVAL
	print("  Drill Mk1: %.0f items/min  (1 every %.1fs)" % [drill_per_min, DRILL_INTERVAL])
	print("  Drill Mk2: %.0f items/min  (1 every %.1fs)" % [drill2_per_min, DRILL_MK2_INTERVAL])
	print("")

func _print_conveyor_throughput() -> void:
	print("--- CONVEYOR THROUGHPUT ---")
	# Throughput = capacity / traverse_time * 60 (items per minute)
	# But effectively: 1 item exits per traverse_time (single lane)
	var mk1 := 60.0 / CONVEYOR_MK1_TIME
	var mk2 := 60.0 / CONVEYOR_MK2_TIME
	var mk3 := 60.0 / CONVEYOR_MK3_TIME
	print("  Conveyor Mk1: %.0f items/min  (%.1fs traverse)" % [mk1, CONVEYOR_MK1_TIME])
	print("  Conveyor Mk2: %.0f items/min  (%.1fs traverse)" % [mk2, CONVEYOR_MK2_TIME])
	print("  Conveyor Mk3: %.0f items/min  (%.1fs traverse)" % [mk3, CONVEYOR_MK3_TIME])
	print("  Drill Mk1 saturates: Mk1 belt (30 vs 60)")
	print("  Drill Mk2 saturates: Mk1 belt (60 vs 60)")
	print("")

func _print_recipe_rates() -> void:
	print("--- RECIPE RATES (per building) ---")
	# Group by converter_type
	var by_type: Dictionary = {}
	for recipe in recipes:
		var ct: String = recipe.converter_type
		if not by_type.has(ct):
			by_type[ct] = []
		by_type[ct].append(recipe)

	var type_order := ["smelter", "press", "wire_drawer", "coke_oven", "hand_assembler",
					   "assembler", "assembler_mk2", "coal_burner", "fuel_generator", "research_lab"]
	for ct in type_order:
		if not by_type.has(ct):
			continue
		print("  [%s]" % ct)
		for recipe: RecipeDef in by_type[ct]:
			var crafts_per_min: float = 60.0 / recipe.craft_time
			var input_str := ""
			for inp in recipe.inputs:
				if input_str != "":
					input_str += " + "
				input_str += "%d %s" % [inp.quantity, str(inp.item.id)]
			var output_str := ""
			for outp in recipe.outputs:
				if output_str != "":
					output_str += " + "
				output_str += "%d %s" % [outp.quantity, str(outp.item.id)]
			var energy_str := ""
			if recipe.energy_cost > 0:
				energy_str = "  [cost: %.0f energy]" % recipe.energy_cost
			if recipe.energy_output > 0:
				energy_str = "  [generates: %.0f energy over %.1fs = %.1f/s]" % [
					recipe.energy_output, recipe.craft_time, recipe.energy_output / recipe.craft_time]
			# Calculate output items/min
			var out_per_min := ""
			for outp in recipe.outputs:
				var ipm: float = outp.quantity * crafts_per_min
				out_per_min += " (%.0f/min)" % ipm
			print("    %s -> %s  [%.1fs, %.1f crafts/min]%s%s" % [
				input_str, output_str, recipe.craft_time, crafts_per_min, out_per_min, energy_str])
		print("")

func _print_production_chains() -> void:
	print("--- PRODUCTION CHAINS (1 building each, items/min) ---")
	print("")

	# Helper: find recipe that produces a given item
	var recipe_for: Dictionary = {}  # item_id -> RecipeDef
	for recipe in recipes:
		for outp in recipe.outputs:
			if not recipe_for.has(outp.item.id):
				recipe_for[outp.item.id] = recipe

	# Chain analysis: how many drills/buildings needed for sustained output
	_analyze_chain("Iron Plate", &"iron_plate", recipe_for)
	_analyze_chain("Copper Plate", &"copper_plate", recipe_for)
	_analyze_chain("Copper Wire", &"copper_wire", recipe_for)
	_analyze_chain("Gear", &"gear", recipe_for)
	_analyze_chain("Tube", &"tube", recipe_for)
	_analyze_chain("Steel", &"steel", recipe_for)
	_analyze_chain("Brick", &"brick", recipe_for)
	_analyze_chain("Coke", &"coke", recipe_for)
	_analyze_chain("Circuit Board", &"circuit_board", recipe_for)
	_analyze_chain("Motor", &"motor", recipe_for)
	_analyze_chain("Science Pack 1 (Red)", &"science_pack_1", recipe_for)
	_analyze_chain("Science Pack 2 (Green)", &"science_pack_2", recipe_for)
	_analyze_chain("Science Pack 3 (Blue)", &"science_pack_3", recipe_for)
	print("")

func _analyze_chain(label: String, item_id: StringName, recipe_for: Dictionary, depth: int = 0) -> Dictionary:
	# Returns {rate: items_per_min_from_one_building, drills_needed: int, buildings: [{type, count}]}
	var indent := "  ".repeat(depth + 1)

	# Raw resource (no recipe) - comes from drill
	if not recipe_for.has(item_id):
		var rate := 60.0 / DRILL_INTERVAL
		if depth == 0:
			print("  %s: 1 drill = %.0f/min (raw)" % [label, rate])
		return {rate = rate, source = "drill"}

	var recipe: RecipeDef = recipe_for[item_id]
	var crafts_per_min := 60.0 / recipe.craft_time

	# Find output quantity for this item
	var out_qty := 1
	for outp in recipe.outputs:
		if outp.item.id == item_id:
			out_qty = outp.quantity

	var output_rate := crafts_per_min * out_qty

	if depth == 0:
		print("  %s: 1 %s = %.1f/min (%.1fs craft, %dx output)" % [
			label, recipe.converter_type, output_rate, recipe.craft_time, out_qty])

		# Calculate input requirements
		for inp in recipe.inputs:
			var needed_per_min := inp.quantity * crafts_per_min
			var sub := _analyze_chain("", inp.item.id, recipe_for, depth + 1)
			var buildings_needed: float = needed_per_min / sub.rate
			print("    needs %.1f %s/min -> %.1f %s(s)" % [
				needed_per_min, str(inp.item.id), buildings_needed, sub.source])

		if recipe.energy_cost > 0:
			var energy_per_min := recipe.energy_cost * crafts_per_min
			print("    energy: %.0f/craft, %.0f/min total" % [recipe.energy_cost, energy_per_min])
		print("")

	return {rate = output_rate, source = recipe.converter_type}

func _print_building_costs() -> void:
	print("--- BUILDING COSTS ---")

	var ring_0 := [&"conveyor", &"junction", &"splitter", &"tunnel_input", &"drill",
				   &"smelter", &"hand_assembler", &"coal_burner", &"energy_pole", &"battery", &"sink"]
	var ring_1 := [&"press", &"wire_drawer", &"coke_oven", &"solar_panel", &"conveyor_mk2", &"research_lab"]
	var ring_2 := [&"assembler", &"fuel_generator", &"drill_mk2", &"conveyor_mk3"]
	var ring_3 := [&"assembler_mk2"]

	print("  Ring 0 (Starting):")
	_print_ring_costs(ring_0)
	print("  Ring 1 (Red Science):")
	_print_ring_costs(ring_1)
	print("  Ring 2 (Red + Green Science):")
	_print_ring_costs(ring_2)
	print("  Ring 3 (All Sciences):")
	_print_ring_costs(ring_3)
	print("")

func _print_ring_costs(ids: Array) -> void:
	for id in ids:
		if not buildings.has(id):
			print("    %s: NOT FOUND" % str(id))
			continue
		var bdef: BuildingDef = buildings[id]
		if bdef.build_cost.is_empty():
			print("    %s: FREE" % bdef.display_name)
			continue
		var cost_str := ""
		for stack in bdef.build_cost:
			if cost_str != "":
				cost_str += " + "
			cost_str += "%d %s" % [stack.quantity, str(stack.item.id)]
		print("    %s: %s" % [bdef.display_name, cost_str])

func _print_milestones() -> void:
	print("--- MILESTONE ESTIMATES ---")
	print("  (Assumes optimal play, no idle time)")
	print("")

	# Time calculations based on production rates
	var drill_rate := 60.0 / DRILL_INTERVAL  # 30/min
	var smelt_time := 3.0  # iron/copper plate

	# First iron plate: mine 1 ore (2s) + smelt (3s)
	print("  First iron plate: ~5s (mine + smelt)")

	# Build first conveyor line (need 1 iron_plate per conveyor)
	# Need: drill(2 plates) + smelter(4 plates) + conveyor x5 (5 plates) = 11 plates
	# At 1 plate per 5s (mine+smelt), that's 55s for manual bootstrapping
	print("  Bootstrap (drill+smelter+5 conveyors): ~55s manual (11 iron plates)")

	# Automated iron: 1 drill -> 30 ore/min, 1 smelter -> 20 plates/min (3s each)
	print("  Automated iron plates: 20/min per smelter (1 drill feeds 1.5 smelters)")

	# First copper wire (needs press + wire drawer unlocked, red science)
	# Science pack 1: 1 iron_gear + 1 copper_wire (6s craft)
	# But need press first for gears, wire drawer for wire
	# Red science: 10 packs per tech
	# 1 hand assembler: 10/min science packs
	# Need: iron_gear (2 iron_plate, 2s press) + copper_wire (1 copper_plate, 2s drawer)
	var science1_time := 6.0
	var science1_per_min := 60.0 / science1_time
	print("  Science Pack 1 rate: %.0f/min per hand assembler" % science1_per_min)
	print("  Time to 10 red packs (1 assembler): ~%.0fs = ~%.0f min" % [
		10 * science1_time, 10.0 * science1_time / 60.0])

	# Ring 1 unlock: 7 techs x 10 packs = 70 red packs
	# Actually 6 techs at 10 + 1 at 15 = 75 red packs
	var total_ring1_packs := 10 * 5 + 15 + 5  # press,wire,solar,coke,conveyor_mk2=10ea, conveyor_mk2=15, lab=5
	print("  Ring 1 total red packs needed: %d" % total_ring1_packs)
	print("  Time for all Ring 1 research (1 assembler): ~%.0f min" % (total_ring1_packs * science1_time / 60.0))

	# Gate contract: 20 iron_plate + 10 copper_wire
	print("  Gate 1 contract: 20 iron_plate + 10 copper_wire")
	print("    With 1 smelter + 1 wire drawer: ~%ds for copper wire" % (int(10.0 / (60.0 / 2.0) * 60)))

	print("")
	print("--- BOTTLENECK SUMMARY ---")
	print("  Early game bottleneck: smelter speed (20 plates/min vs 30 ore/min)")
	print("  Mid game bottleneck: energy for steel (80 per smelt)")
	print("  Late game bottleneck: multi-ingredient assembly (motor: 3 inputs)")
	print("")
	print("--- ENERGY BALANCE ---")
	var coal_burn_rate := 100.0 / 4.0  # energy/s from coal burner
	var coke_burn_rate := 200.0 / 6.0
	print("  Coal Burner: %.1f energy/s (consumes 1 coal/4s = 15 coal/min)" % coal_burn_rate)
	print("  Fuel Generator: %.1f energy/s (consumes 1 coke/6s = 10 coke/min)" % coke_burn_rate)
	print("  Solar Panel: 8.0 energy/s (free, passive)")
	print("")
	print("  Steel smelting needs: 80 energy/craft, at 12 crafts/min = %.0f energy/min = %.1f/s" % [
		80 * 12, 80.0 * 12.0 / 60.0])
	print("  1 coal burner (%.1f/s) supports: %.1f steel smelts/min" % [
		coal_burn_rate, coal_burn_rate / (80.0 / 5.0)])
	print("  Assembler Mk1 demand: 5/s base + recipe costs")
	print("")
