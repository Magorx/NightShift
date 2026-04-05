@tool
class_name ShapeCell3D
extends MeshInstance3D
## Visible 3D grid cell block for building footprint editing.
## Shows a translucent unit cube in the editor; hidden at runtime.
## Position at cell center: (cell_x + 0.5, 0.5, cell_z + 0.5).
## BuildingDef extracts grid coords via floori(position.x), floori(position.z).

const CELL_COLOR := Color(0.3, 0.5, 0.8, 0.15)

func _ready() -> void:
	if not mesh:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		mesh = box
	if not material_override:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = CELL_COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		material_override = mat
	# Only show in editor
	if not Engine.is_editor_hint():
		visible = false
