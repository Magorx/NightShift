class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.GRAY
@export var category: String # "extractor", "conveyor", "converter", "sink"
@export var scene: PackedScene
@export var unlock_tech: StringName

## Anchor cell offset, read from BuildAnchor node position at load time.
## The cursor/grid_pos aligns to this cell when placing.
var anchor_cell: Vector2i = Vector2i(0, 0)

## Populated at load time from the scene's ShapeCell children.
## Array of Vector2i cell offsets relative to the anchor.
var shape: Array = []

## IO points extracted from Inputs/Outputs sub-nodes at load time.
## Each entry: {cell: Vector2i, mask: [right, down, left, up]}
## Defined in default orientation (facing right); rotate at placement time.
var inputs: Array = []
var outputs: Array = []
