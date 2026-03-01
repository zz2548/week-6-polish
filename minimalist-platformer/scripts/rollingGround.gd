extends Node2D

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var speed        := 420.0
@export var ground_acc   := 15.0
@export var ground_width := 1200.0

# ─── Node References ─────────────────────────────────────────────────────────
@onready var _tiles : Array[Node2D] = [$Ground1, $Ground2, $Ground3]
@onready var _player : CharacterBody2D = $"../player"



# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	assert(_player != null, "RollingGround: player_path is not set or is invalid!")
	for i in _tiles.size():
		_tiles[i].global_position.x = ground_width * i


# ─── Main Loop ───────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	speed += ground_acc * delta
	_wrap_tiles()


# ─── Helpers ─────────────────────────────────────────────────────────────────

# Recycle any tile that has been passed by the player
func _wrap_tiles() -> void:
	for tile in _tiles:
		if tile.global_position.x + ground_width < _player.global_position.x:
			tile.global_position.x = _rightmost_x() + ground_width

func _rightmost_x() -> float:
	var max_x := -INF
	for tile in _tiles:
		max_x = maxf(max_x, tile.global_position.x)
	return max_x
