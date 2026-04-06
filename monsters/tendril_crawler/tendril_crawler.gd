class_name TendrilCrawler
extends MonsterBase

## Tendril Crawler: first monster type.
## Follows A* path toward nearest building, attacks in melee range.
## Line destruction pattern: attacks 1 building per strike.

const MODEL_PATH := "res://monsters/tendril_crawler/models/tendril_crawler.glb"

func _ready() -> void:
	# Stats
	max_hp = 50.0
	move_speed = 2.0
	attack_damage = 15.0
	attack_cooldown = 1.5
	attack_range = 1.3

	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_check_player_proximity(delta)

func _setup_visual() -> void:
	var model_scene := load(MODEL_PATH) as PackedScene
	if model_scene:
		var model := model_scene.instantiate()
		model.name = "Model"
		model.scale = Vector3(0.5, 0.5, 0.5)
		add_child(model)
	else:
		# Fallback placeholder if model missing
		super._setup_visual()
