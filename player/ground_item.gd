class_name GroundItem
extends Node3D
## A loose item stack on the ground. Can be picked up by the player.

const HOVER_RADIUS := 0.5        # world units for mouse hover detection
const MERGE_RANGE := 0.75        # world units for merging nearby stacks
const MERGE_INTERVAL := 2.0
const FEED_INTERVAL := 0.5

var item_id: StringName = &""
var quantity: int = 1
var despawn_timer: float = 120.0  # seconds until auto-despawn
var _pickup_immunity: float = 0.0  # seconds of pickup immunity (after death drop)
var _hovered: bool = false
var _merge_timer: float = 0.0
var _feed_timer: float = 0.0

func _ready() -> void:
	add_to_group("ground_items")
	_merge_timer = randf() * MERGE_INTERVAL  # stagger merge checks
	_feed_timer = randf() * FEED_INTERVAL
	_add_item_model()

func _process(delta: float) -> void:
	despawn_timer -= delta
	if despawn_timer <= 0:
		queue_free()
		return
	if _pickup_immunity > 0:
		_pickup_immunity -= delta

	# Hover detection: project to screen and check mouse distance
	_hovered = false
	var camera := get_viewport().get_camera_3d()
	if camera and not get_viewport().gui_get_hovered_control():
		var screen_pos := camera.unproject_position(global_position)
		var mouse_pos := get_viewport().get_mouse_position()
		if screen_pos.distance_to(mouse_pos) < 20.0:  # ~20px screen distance
			_hovered = true

	_merge_timer += delta
	if _merge_timer >= MERGE_INTERVAL:
		_merge_timer = 0.0
		_try_merge_nearby()
	_feed_timer += delta
	if _feed_timer >= FEED_INTERVAL:
		_feed_timer = 0.0
		_try_feed_building()

# -- Click to pick up ---------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _hovered:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	var dist_xz := Vector2(player.position.x - position.x, player.position.z - position.z).length()
	if dist_xz > Player.PICKUP_RANGE:
		return
	var remaining = player.add_item(item_id, quantity)
	if remaining < quantity:
		if remaining <= 0:
			queue_free()
		else:
			quantity = remaining
		get_viewport().set_input_as_handled()

# -- Merge --------------------------------------------------------------------

func _try_merge_nearby() -> void:
	for other in get_tree().get_nodes_in_group("ground_items"):
		if other == self or not is_instance_valid(other):
			continue
		if other.item_id == item_id:
			var dist_xz := Vector2(position.x - other.position.x, position.z - other.position.z).length()
			if dist_xz < MERGE_RANGE:
				# Lower instance absorbs higher to prevent double-merge
				if get_instance_id() < other.get_instance_id():
					quantity += other.quantity
					other.queue_free()
					return

# -- Building feed ------------------------------------------------------------

func _try_feed_building() -> void:
	var grid_pos := GridUtils.world_to_grid(position)
	var building = GameManager.get_building_at(grid_pos)
	if not building or not building.logic:
		return
	var leftover = building.logic.try_insert_item(item_id, quantity)
	if leftover < quantity:
		quantity = leftover
		if quantity <= 0:
			queue_free()

func _add_item_model() -> void:
	var model_path := "res://resources/items/models/%s_item.glb" % str(item_id)
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var model: Node3D = scene.instantiate()
			model.name = "Model"
			model.scale = Vector3(1.0, 1.0, 1.0)
			model.position.y = 0.15
			add_child(model)
			var anim: AnimationPlayer = model.get_node_or_null("AnimationPlayer")
			if anim and anim.has_animation(&"idle"):
				anim.play(&"idle")
			return
	# Fallback: small colored sphere
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Model"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh_inst.mesh = sphere
	mesh_inst.position.y = 0.15
	var mat := StandardMaterial3D.new()
	var item_def = GameManager.get_item_def(item_id)
	mat.albedo_color = item_def.color if item_def else Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func set_pickup_immunity(time: float) -> void:
	_pickup_immunity = time

func can_be_picked_up() -> bool:
	return _pickup_immunity <= 0

# -- Serialization ------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		item_id = str(item_id),
		quantity = quantity,
		x = position.x,
		y = position.z,  # grid Y = world Z (backward compat key name)
		despawn = despawn_timer,
	}

static func deserialize_from(data: Dictionary) -> Dictionary:
	return {
		item_id = StringName(data.get("item_id", "")),
		quantity = int(data.get("quantity", 1)),
		x = float(data.get("x", 0)),
		y = float(data.get("y", 0)),
		despawn = float(data.get("despawn", 120)),
	}
