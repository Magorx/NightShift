class_name ConveyorSprite
extends AnimatedSprite2D

## Selects the correct animation variant based on neighboring building outputs
## and orients the sprite to match conveyor direction.
## Animations (straight, turn, side_input, dual_side_input) are defined
## in the SpriteFrames resource on the AnimatedSprite2D node in the scene.

var _flip: bool = false

func _ready() -> void:
	centered = true
	position = Vector2(GridUtils.HALF_W, GridUtils.HALF_H)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play()
	_sync_to_global_clock()

## Update the sprite variant based on current neighbor state.
func update_variant(conv: Node, _conveyor_system: Node) -> void:
	var dir_vec := Vector2i(conv.get_direction_vector())
	var back := -dir_vec
	var right_side := Vector2i(-dir_vec.y, dir_vec.x)
	var left_side := Vector2i(dir_vec.y, -dir_vec.x)

	var has_back := _is_feeding_neighbor(conv.grid_pos, back)
	var has_right := _is_feeding_neighbor(conv.grid_pos, right_side)
	var has_left := _is_feeding_neighbor(conv.grid_pos, left_side)

	var variant: StringName
	_flip = false

	if has_right and has_left and has_back:
		variant = &"crossroad"
	elif has_right and has_left:
		variant = &"dual_side_input"
	elif has_back and has_right:
		variant = &"side_input"
		_flip = false
	elif has_back and has_left:
		variant = &"side_input"
		_flip = true
	elif has_right and not has_back:
		variant = &"turn"
		_flip = false
	elif has_left and not has_back:
		variant = &"turn"
		_flip = true
	elif has_back:
		variant = &"straight"
	elif not has_back:
		variant = &"start"

	if animation != variant:
		animation = variant
		play()
		_sync_to_global_clock()
	rotation = conv.direction * PI / 2.0
	flip_v = _flip

## Snap the current frame to a global clock so all conveyors stay in phase.
func _sync_to_global_clock() -> void:
	var fps := sprite_frames.get_animation_speed(animation)
	var count := sprite_frames.get_frame_count(animation)
	if count <= 0 or fps <= 0.0:
		return
	var cycle_time := count / fps
	var global_time := Time.get_ticks_msec() / 1000.0
	frame = int(fmod(global_time, cycle_time) * fps) % count

## Check if any building has an output that feeds into grid_pos from dir_offset.
func _is_feeding_neighbor(grid_pos: Vector2i, dir_offset: Vector2i) -> bool:
	# Convert dir_offset to a direction index for has_output_at
	var dir_idx: int = -1
	if dir_offset == Vector2i.RIGHT:
		dir_idx = 0
	elif dir_offset == Vector2i.DOWN:
		dir_idx = 1
	elif dir_offset == Vector2i.LEFT:
		dir_idx = 2
	elif dir_offset == Vector2i.UP:
		dir_idx = 3
	else:
		return false
	return GameManager.has_output_at(grid_pos, dir_idx)
