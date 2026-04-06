class_name HealthBar3D
extends Node3D

## Floating health bar that billboards toward the camera.
## Attach via setup() after creating the HealthComponent.

var always_visible: bool = false

var _health: HealthComponent
var _fill: MeshInstance3D
var _bg: MeshInstance3D

const BAR_WIDTH := 0.8
const BAR_HEIGHT := 0.1
const FILL_INSET := 0.015

func setup(p_health: HealthComponent, p_always_visible: bool = false) -> void:
	_health = p_health
	always_visible = p_always_visible
	_health.damaged.connect(_on_health_changed)
	_health.healed.connect(_on_health_changed)

func _ready() -> void:
	_bg = _create_quad(BAR_WIDTH, BAR_HEIGHT, Color(0.1, 0.1, 0.1, 0.7))
	add_child(_bg)

	var fw := BAR_WIDTH - FILL_INSET * 2
	var fh := BAR_HEIGHT - FILL_INSET * 2
	_fill = _create_quad(fw, fh, Color(0.2, 0.8, 0.2, 0.9))
	_fill.position.z = -0.001
	add_child(_fill)

	_update_bar()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP)

func _create_quad(width: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	mi.material_override = mat
	return mi

func _on_health_changed(_amount: float, _current: float) -> void:
	_update_bar()

func _update_bar() -> void:
	if not _health or not _fill:
		return
	var frac := _health.get_hp_fraction()

	# Scale fill and left-align
	var fw := BAR_WIDTH - FILL_INSET * 2
	_fill.scale.x = maxf(frac, 0.001)
	_fill.position.x = fw * (frac - 1.0) / 2.0

	# Color: green → yellow → red
	var c: Color
	if frac > 0.5:
		c = Color(0.2, 0.8, 0.2, 0.9).lerp(Color(0.9, 0.9, 0.1, 0.9), (1.0 - frac) * 2.0)
	else:
		c = Color(0.9, 0.9, 0.1, 0.9).lerp(Color(0.9, 0.1, 0.1, 0.9), (0.5 - frac) * 2.0)
	(_fill.material_override as StandardMaterial3D).albedo_color = c

	# Visibility
	var should_show := always_visible or frac < 1.0
	if should_show != visible:
		visible = should_show
		set_process(should_show)
