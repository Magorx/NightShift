extends "simulation_base.gd"

## Quick simulation to capture high-res screenshots of each UI panel for review.

const HIRES_WIDTH := 1280
const HIRES_HEIGHT := 720

func run_simulation() -> void:
	var hud = game_world.hud

	# Recipe browser - Iron Plate (shows produced by + used in)
	hud.recipe_browser.visible = true
	hud.recipe_browser.move_to_center()
	hud.recipe_browser.select_item(&"iron_plate")
	await sim_advance_ticks(15)
	await _capture_hires("recipe_browser_iron_plate")

	# Recipe browser - Motor (complex item)
	hud.recipe_browser.select_item(&"motor")
	await sim_advance_ticks(10)
	await _capture_hires("recipe_browser_motor")

	# Recipe browser - Processor (deepest chain)
	hud.recipe_browser.select_item(&"processor")
	await sim_advance_ticks(10)
	await _capture_hires("recipe_browser_processor")

	hud.recipe_browser.visible = false
	await sim_advance_ticks(3)

	# Research panel - initial state
	hud.research_panel.visible = true
	hud.research_panel.move_to_center()
	await sim_advance_ticks(10)
	await _capture_hires("research_panel_tree")

	# Research panel - select a tech
	hud.research_panel._selected_tech_id = &"tech_assembler"
	hud.research_panel._update_info_panel()
	hud.research_panel.tree_display.queue_redraw()
	await sim_advance_ticks(10)
	await _capture_hires("research_panel_selected")

	# Research panel - start researching
	ContractManager._current_ring = 1
	ResearchManager.start_research(&"tech_press")
	hud.research_panel._selected_tech_id = &"tech_press"
	hud.research_panel._update_info_panel()
	hud.research_panel.tree_display.queue_redraw()
	await sim_advance_ticks(10)
	await _capture_hires("research_panel_researching")

	hud.research_panel.visible = false
	await sim_advance_ticks(3)

	# HUD buttons visible
	await _capture_hires("hud_buttons")

	sim_finish()

func _capture_hires(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(HIRES_WIDTH, HIRES_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var dir_path := ProjectSettings.globalize_path("res://tests/simulation/screenshots/sim_ui_screenshot")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path := dir_path.path_join("%s.png" % label)
	image.save_png(path)
	print("[SIM] Hi-res capture: %s.png" % label)
