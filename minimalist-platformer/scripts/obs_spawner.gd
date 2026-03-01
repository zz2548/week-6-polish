extends Node

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var obstacle_scene     : PackedScene
@export var player_path        : NodePath
@export var ground_path        : NodePath
@export var obstacle_root_path : NodePath
@export var spawn_offset       : float = 200.0  # Distance ahead of player to spawn
@export var ground_y           : float = 500.0
@export var min_t              : float = 0.8
@export var max_t              : float = 1.6

# ─── Internal State ──────────────────────────────────────────────────────────
var _running     : bool  = true
var _spawn_timer : float

# ─── Node References ─────────────────────────────────────────────────────────
@onready var _player        : CharacterBody2D = $"../../player"
@onready var _ground        : Node            = $"../../Ground"
@onready var _obstacle_root : Node2D          = $".."
@onready var _msg_label : Label = $"../../UI/msgLabel"
@onready var _score     : Label = $"../../UI/Score"


# ─── Obstacle Kind Definitions ───────────────────────────────────────────────
const OBSTACLE_KINDS := [
	{ "color": Color(0.9, 0.9, 0.9), "h_range": [0.00, 0.55], "w_range": [1.20, 0.80] },
	{ "color": Color(0.2, 0.9, 0.2), "h_range": [0.60, 1.00], "w_range": [1.00, 0.35] },
	{ "color": Color(0.3, 0.7, 1.0), "h_range": [0.00, 0.80], "w_range": [1.00, 0.55] },
	{ "color": Color(1.0, 0.6, 0.2), "h_range": [0.00, 0.45], "w_range": [1.00, 0.30] },
]


# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	
	randomize()
	_spawn_timer = randf_range(min_t, max_t)

	print("obstacle_root node: ", $"..")
	print("obstacle_root class: ", $"..".get_class())
	print("player node: ", $"../../player")
	print("ground node: ", $"../../Ground")
	if _score:     _score.text     = "Score: 0"
	if _msg_label: _msg_label.text = ""


# ─── Main Loop ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _running:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	_update_score()
	_tick_spawner(delta)
	_despawn_passed_obstacles()

func _tick_spawner(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(min_t, max_t)
		_spawn_one()


# ─── Spawning ────────────────────────────────────────────────────────────────
func _spawn_one() -> void:
	var current_speed := _get_ground_speed()
	var limits        := _calc_size_limits(current_speed)
	var min_w : float  = limits[0]
	var max_w : float  = limits[1]
	var min_h : float  = limits[2]
	var max_h : float  = limits[3]
	
	var kind : Dictionary = OBSTACLE_KINDS[randi() % OBSTACLE_KINDS.size()]
	var h    := maxf(randf_range(max_h * kind["h_range"][0], max_h * kind["h_range"][1]), min_h)
	var w    := maxf(randf_range(min_w * kind["w_range"][0], max_w * kind["w_range"][1]), min_w)
	var c    : Color = kind["color"]

	var ob := obstacle_scene.instantiate() as Node2D
	_obstacle_root.add_child(ob)

	# Spawn ahead of the player in world space; obstacle is stationary
	var viewport_width := get_viewport().get_visible_rect().size.x
	ob.global_position = Vector2(_player.global_position.x + viewport_width * 0.5 + spawn_offset, ground_y - h * 0.5)
	ob.call("setup", w, h, c)
	ob.connect("hit_player", _on_game_over)

	print("Spawned obstacle at: ", ob.global_position, " size=", Vector2(w, h))

func _calc_size_limits(current_speed: float) -> Array[float]:
	var v         : float = _player.call("get_jump_speed")
	var g         : float = _player.call("get_gravity_y")
	var jump_time : float = (2.0 * v) / g
	var max_w     : float = (current_speed * jump_time) * 0.75
	var max_h     : float = ((v * v) / (2.0 * g)) * 0.9
	var min_w     : float = maxf(20.0, max_w * 0.20)
	var min_h     : float = maxf(20.0, max_h * 0.35)
	return [min_w, max_w, min_h, max_h]


# ─── Helpers ─────────────────────────────────────────────────────────────────
func _get_ground_speed() -> float:
	return float(_ground.get("speed"))

func _update_score() -> void:
	if _score:
		_score.text = "Score: %d" % int(_get_ground_speed() - 420)

# Despawn obstacles the player has already passed
func _despawn_passed_obstacles() -> void:
	for child in _obstacle_root.get_children():
		var ob := child as Node2D
		if ob == null:
			continue
		if ob.global_position.x < _player.global_position.x - 300.0:
			ob.queue_free()


# ─── Game Over ───────────────────────────────────────────────────────────────
func _on_game_over() -> void:
	_running           = false
	_ground.speed      = 0
	_ground.ground_acc = 0
	_player.set_controls_enabled(false)
	_msg_label.text = "GAME OVER\nPress R to restart"
