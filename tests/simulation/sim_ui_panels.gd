extends "simulation_base.gd"

## Visual test for the new Recipe Browser and Research Panel UI windows.
## Opens each panel, clicks through items, captures screenshots, and verifies correctness.

func run_simulation() -> void:
	var hud = game_world.hud

	# ── Test 1: Recipe Browser ──
	sim_assert(hud.recipe_browser != null, "Recipe browser exists on HUD")
	sim_assert(not hud.recipe_browser.visible, "Recipe browser starts hidden")

	hud.recipe_browser.visible = true
	hud.recipe_browser.move_to_center()
	await sim_advance_ticks(5)
	sim_assert(hud.recipe_browser.visible, "Recipe browser is visible after opening")

	# Select iron_plate - shows smelting recipe + downstream uses
	hud.recipe_browser.select_item(&"iron_plate")
	await sim_advance_ticks(10)
	await sim_capture_screenshot("recipe_browser_iron_plate")
	var tree_children: int = hud.recipe_browser.tree_content.get_child_count()
	sim_assert(tree_children > 3, "Iron plate tree has content (%d children)" % tree_children)

	# Select copper_wire
	hud.recipe_browser.select_item(&"copper_wire")
	await sim_advance_ticks(10)
	tree_children = hud.recipe_browser.tree_content.get_child_count()
	sim_assert(tree_children > 3, "Copper wire tree has content (%d children)" % tree_children)

	# Search for "science"
	hud.recipe_browser.search_edit.text = "science"
	hud.recipe_browser._on_search_changed("science")
	await sim_advance_ticks(5)
	var list_children: int = hud.recipe_browser.item_list_box.get_child_count()
	sim_assert(list_children == 3, "Search 'science' shows 3 items (got %d)" % list_children)

	# Clear search
	hud.recipe_browser.search_edit.text = ""
	hud.recipe_browser._on_search_changed("")
	await sim_advance_ticks(5)
	list_children = hud.recipe_browser.item_list_box.get_child_count()
	sim_assert(list_children > 30, "Full item list has 30+ items (got %d)" % list_children)

	# Select processor - complex deep chain
	hud.recipe_browser.select_item(&"processor")
	await sim_advance_ticks(10)
	await sim_capture_screenshot("recipe_browser_processor")
	tree_children = hud.recipe_browser.tree_content.get_child_count()
	sim_assert(tree_children > 5, "Processor tree has deep chain (%d children)" % tree_children)

	# Select iron_ore - raw resource
	hud.recipe_browser.select_item(&"iron_ore")
	await sim_advance_ticks(10)
	tree_children = hud.recipe_browser.tree_content.get_child_count()
	sim_assert(tree_children > 2, "Iron ore tree shows source info (%d children)" % tree_children)

	hud.recipe_browser.visible = false
	await sim_advance_ticks(5)

	# ── Test 2: Research Panel ──
	sim_assert(hud.research_panel != null, "Research panel exists on HUD")
	sim_assert(not hud.research_panel.visible, "Research panel starts hidden")

	hud.research_panel.visible = true
	hud.research_panel.move_to_center()
	await sim_advance_ticks(5)
	sim_assert(hud.research_panel.visible, "Research panel is visible after opening")
	await sim_capture_screenshot("research_panel_initial")

	# Check that tech nodes are laid out
	var tech_count: int = hud.research_panel._tech_positions.size()
	sim_assert(tech_count == 11, "All 11 techs positioned (got %d)" % tech_count)

	# Check ring groupings
	var ring1_count: int = hud.research_panel._ring_techs.get(1, []).size()
	var ring2_count: int = hud.research_panel._ring_techs.get(2, []).size()
	var ring3_count: int = hud.research_panel._ring_techs.get(3, []).size()
	sim_assert(ring1_count == 6, "Ring 1 has 6 techs (got %d)" % ring1_count)
	sim_assert(ring2_count == 4, "Ring 2 has 4 techs (got %d)" % ring2_count)
	sim_assert(ring3_count == 1, "Ring 3 has 1 tech (got %d)" % ring3_count)

	# Select a tech and verify info panel updates
	hud.research_panel._selected_tech_id = &"tech_press"
	hud.research_panel._update_info_panel()
	await sim_advance_ticks(5)
	sim_assert(hud.research_panel.info_name.text == "Press", "Info panel shows Press name (got '%s')" % hud.research_panel.info_name.text)

	# Unlock ring 1 and start research
	ContractManager._current_ring = 1
	var can_research: bool = hud.research_panel._is_tech_available(&"tech_press")
	sim_assert(can_research, "Press tech is available after ring 1 unlock")

	var started: bool = ResearchManager.start_research(&"tech_press")
	sim_assert(started, "Research started for tech_press")
	sim_assert(ResearchManager.current_research != null, "Current research is set")
	sim_assert(ResearchManager.current_research.id == &"tech_press", "Current research is tech_press")

	hud.research_panel._update_info_panel()
	await sim_advance_ticks(5)
	await sim_capture_screenshot("research_panel_researching")

	# Deliver some science packs - should NOT cause stack overflow
	ResearchManager.deliver_science_pack(&"science_pack_1")
	ResearchManager.deliver_science_pack(&"science_pack_1")
	var progress := ResearchManager.get_progress_fraction()
	sim_assert(progress > 0.0, "Research progress > 0 after delivering packs (%.2f)" % progress)

	# Update panel - verify no crash
	hud.research_panel._update_info_panel()
	hud.research_panel._refresh_progress_display()
	await sim_advance_ticks(5)
	sim_assert(hud.research_panel.progress_bar.visible, "Progress bar is visible during research")

	hud.research_panel.visible = false
	await sim_advance_ticks(5)

	# ── Test 3: HUD button order ──
	var button_row_node = hud.get_node_or_null("BottomRight/ButtonRow")
	if button_row_node:
		var children_names: Array = []
		for child in button_row_node.get_children():
			children_names.append(child.name)
		print("[SIM] ButtonRow children: %s" % str(children_names))
		var research_idx: int = children_names.find("ResearchButton")
		var recipes_idx: int = children_names.find("RecipesButton")
		var inventory_idx: int = children_names.find("InventoryButton")
		var buildings_idx: int = children_names.find("BuildingsButton")
		sim_assert(research_idx >= 0 and recipes_idx >= 0, "Button row has Research and Recipes")
		sim_assert(research_idx < recipes_idx, "Research before Recipes")
		sim_assert(recipes_idx < inventory_idx, "Recipes before Inventory")
		sim_assert(inventory_idx < buildings_idx, "Inventory before Buildings")
	else:
		# Fallback: buttons may be directly under BottomRight
		var bottom_right = hud.get_node("BottomRight")
		var children_names: Array = []
		for child in bottom_right.get_children():
			children_names.append(child.name)
		print("[SIM] BottomRight children: %s" % str(children_names))
		var research_idx: int = children_names.find("ResearchButton")
		var recipes_idx: int = children_names.find("RecipesButton")
		var inventory_idx: int = children_names.find("InventoryButton")
		var buildings_idx: int = children_names.find("BuildingsButton")
		sim_assert(research_idx < recipes_idx, "Research before Recipes")
		sim_assert(recipes_idx < inventory_idx, "Recipes before Inventory")
		sim_assert(inventory_idx < buildings_idx, "Inventory before Buildings")

	# ── Test 4: open_recipe_browser_for_item ──
	hud.open_recipe_browser_for_item(&"motor")
	await sim_advance_ticks(10)
	await sim_capture_screenshot("recipe_browser_motor")
	sim_assert(hud.recipe_browser.visible, "Recipe browser opened via open_recipe_browser_for_item")
	sim_assert(hud.recipe_browser._selected_item_id == &"motor", "Motor is selected in recipe browser")

	hud.recipe_browser.visible = false

	# ── Test 5: ItemIcon tooltip blocked by window ──
	# Place an icon in game world, open a window over it, verify hover is blocked
	var test_icon := ItemIcon.new()
	test_icon._item_id = &"iron_ore"
	test_icon.texture = GameManager.get_item_icon(&"iron_ore")
	test_icon.custom_minimum_size = Vector2(32, 32)
	test_icon.global_position = Vector2(400, 300)
	hud.add_child(test_icon)
	await sim_advance_ticks(3)

	# Without window: icon should detect hover if mouse is on it
	# (we can't move the real mouse in headless, but we can test _is_covered_by_window)
	var icon_center := test_icon.global_position + Vector2(16, 16)
	# No window open -> not covered
	hud.recipe_browser.visible = false
	hud.research_panel.visible = false
	var covered_without_window: bool = test_icon._is_covered_by_window(icon_center)
	sim_assert(not covered_without_window, "Icon NOT covered when no window is open")

	# Open recipe browser centered over the icon
	hud.recipe_browser.visible = true
	hud.recipe_browser.global_position = Vector2(300, 200)
	hud.recipe_browser.size = Vector2(620, 440)
	await sim_advance_ticks(3)
	var covered_with_window: bool = test_icon._is_covered_by_window(icon_center)
	sim_assert(covered_with_window, "Icon IS covered when window is on top")

	# Verify icon inside the window is NOT considered covered by its own window
	# (e.g. an ItemIcon inside the recipe browser's tree_content)
	hud.recipe_browser.select_item(&"iron_plate")
	await sim_advance_ticks(5)
	var icons_in_browser: Array = []
	_find_item_icons(hud.recipe_browser, icons_in_browser)
	if icons_in_browser.size() > 0:
		var inner_icon: ItemIcon = icons_in_browser[0]
		var inner_pos := inner_icon.global_position + inner_icon.size * 0.5
		var inner_covered: bool = inner_icon._is_covered_by_window(inner_pos)
		sim_assert(not inner_covered, "Icon INSIDE window is not blocked by its own window (found %d icons)" % icons_in_browser.size())
	else:
		sim_assert(false, "Expected ItemIcon instances inside recipe browser")

	hud.recipe_browser.visible = false
	test_icon.queue_free()
	await sim_advance_ticks(3)

	# ── Test 6: Window mouse filter ──
	sim_assert(hud.recipe_browser.mouse_filter == Control.MOUSE_FILTER_STOP, "Recipe browser consumes mouse input")
	sim_assert(hud.research_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Research panel consumes mouse input")
	sim_assert(hud.buildings_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Buildings panel consumes mouse input")
	sim_assert(hud.inventory_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Inventory panel consumes mouse input")

	sim_finish()

func _find_item_icons(node: Node, result: Array) -> void:
	if node is ItemIcon:
		result.append(node)
	for child in node.get_children():
		_find_item_icons(child, result)
