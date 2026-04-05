extends RefCounted

## Manages 3D item model instances for conveyor items and building buffers.
## Each item gets its own Node3D instance from the corresponding .glb model.
## Falls back to a small colored sphere if no model exists.

const ITEM_SCALE := 2.0
const ITEM_Y_OFFSET := 0.15

var _parent: Node
var _model_cache: Dictionary = {}  # item_id -> PackedScene (or null for no-model)

func attach_to(parent: Node) -> void:
	_parent = parent

## Create a 3D visual node for an item. Returns the Node3D instance.
func create_item_visual(item_id: StringName) -> Node3D:
	var scene: PackedScene = _get_model_scene(item_id)
	var node: Node3D
	if scene:
		node = scene.instantiate()
		node.scale = Vector3(ITEM_SCALE, ITEM_SCALE, ITEM_SCALE)
	else:
		# Fallback: colored sphere
		node = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		node.mesh = sphere
		var mat := StandardMaterial3D.new()
		var item_def = GameManager.get_item_def(item_id)
		mat.albedo_color = item_def.color if item_def else Color.WHITE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat
	node.name = "Item_%s" % str(item_id)
	node.position = Vector3(-9999, -9999, -9999)
	if _parent:
		_parent.add_child(node)
	# Play idle animation if available
	var anim: AnimationPlayer = node.get_node_or_null("AnimationPlayer")
	if anim and anim.has_animation(&"idle"):
		anim.play(&"idle")
	return node

func clear_all() -> void:
	if _parent:
		for child in _parent.get_children():
			if child.name.begins_with("Item_"):
				child.queue_free()

func _get_model_scene(item_id: StringName) -> PackedScene:
	if _model_cache.has(item_id):
		return _model_cache[item_id]
	var path := "res://resources/items/models/%s_item.glb" % str(item_id)
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		scene = load(path)
	_model_cache[item_id] = scene
	return scene
