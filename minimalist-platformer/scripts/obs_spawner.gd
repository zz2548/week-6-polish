extends Node

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var obstacle_scene     : PackedScene
@export var player_path        : NodePath
@export var ground_path        : NodePath
@export var obstacle_root_path : NodePath
@export var spawn_offset       : float = 200.0
@export var ground_y           : float = 500.0
@export var min_t              : float = 2.0
@export var max_t              : float = 3.5

# ─── Internal State ──────────────────────────────────────────────────────────
var _running        : bool    = true
var _spawn_timer    : float
var _score_base_pos : Vector2

# Y position (world space) of the bottom of an overhead obstacle's hitbox.
# Standing player top is ~-110; crouching top is ~-70.
# -88 sits between those so standing player hits it, crouching player clears it.
const OVERHEAD_BOTTOM_Y := -88.0

# ─── Node References ─────────────────────────────────────────────────────────
@onready var _player        : CharacterBody2D = $"../../player"
@onready var _ground        : Node            = $"../../Ground"
@onready var _obstacle_root : Node2D          = $".."
@onready var _msg_label : Label = $"../../UI/msgLabel"
@onready var _score     : Label = $"../../UI/Score"

# ─── Obstacle Kind Definitions ───────────────────────────────────────────────
const OBSTACLE_KINDS := [
	{ "color": Color(1.0, 0.1, 0.7),  "h_range": [0.00, 0.55], "w_range": [1.20, 0.80] },  # hot pink
	{ "color": Color(0.55, 0.0, 1.0), "h_range": [0.60, 1.00], "w_range": [1.00, 0.35] },  # neon violet
	{ "color": Color(0.9, 0.0, 0.5),  "h_range": [0.00, 0.80], "w_range": [1.00, 0.55] },  # neon magenta
	{ "color": Color(0.45, 0.1, 1.0), "h_range": [0.00, 0.45], "w_range": [1.00, 0.30] },  # electric purple
]

func _ready() -> void:
	randomize()
	_spawn_timer = randf_range(min_t, max_t)
	if _score:
		_score.text     = "Score: 0"
		_score_base_pos = _score.position
	if _msg_label: _msg_label.text = ""

func _process(delta: float) -> void:
	if not _running:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	_update_score(delta)
	_tick_spawner(delta)
	_despawn_passed_obstacles()

func _tick_spawner(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(min_t, max_t)
		# Reduce timer slightly as we go faster for difficulty scaling (gentler ramp)
		var speed_factor := clampf(_get_ground_speed() / 1200.0, 0.0, 0.30)
		_spawn_timer -= (_spawn_timer * speed_factor)

		# 25% chance of an overhead obstacle instead of a floor obstacle
		if randf() < 0.25:
			_spawn_overhead()
		else:
			_spawn_one()

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

	var viewport_width := get_viewport().get_visible_rect().size.x
	ob.global_position = Vector2(_player.global_position.x + viewport_width * 0.5 + spawn_offset, ground_y - h * 0.5)
	ob.call("setup", w, h, c)
	ob.connect("hit_player", _on_game_over)

func _spawn_overhead() -> void:
	var current_speed := _get_ground_speed()
	var limits        := _calc_size_limits(current_speed)
	var min_w : float  = limits[0]
	var max_w : float  = limits[1]

	var kind : Dictionary = OBSTACLE_KINDS[randi() % OBSTACLE_KINDS.size()]
	# Overhead obstacles are wide and not too tall — just enough to force a duck
	var h := 55.0
	var w := maxf(randf_range(min_w * 0.8, max_w * 0.6), min_w)
	var c : Color = kind["color"]

	var ob := obstacle_scene.instantiate() as Node2D
	_obstacle_root.add_child(ob)

	var viewport_width := get_viewport().get_visible_rect().size.x
	# Position so the bottom of the hitbox is at OVERHEAD_BOTTOM_Y
	ob.global_position = Vector2(
		_player.global_position.x + viewport_width * 0.5 + spawn_offset,
		OVERHEAD_BOTTOM_Y - h * 0.5
	)
	ob.call("setup_overhead", w, h, c)
	ob.connect("hit_player", _on_game_over)

func _calc_size_limits(current_speed: float) -> Array[float]:
	var v         : float = _player.call("get_jump_speed")
	var g         : float = _player.call("get_gravity_y")
	var jump_time : float = (2.0 * v) / g
	# Cap max_w so wide obstacles never straddle the despawn threshold while visible
	var max_w     : float = minf((current_speed * jump_time) * 0.75, 350.0)
	var max_h     : float = ((v * v) / (2.0 * g)) * 0.9
	var min_w     : float = maxf(20.0, max_w * 0.20)
	var min_h     : float = maxf(20.0, max_h * 0.35)
	return [min_w, max_w, min_h, max_h]

func _get_ground_speed() -> float:
	return float(_ground.get("speed"))

func _update_score(delta: float) -> void:
	if _score:
		var raw_score := int(_get_ground_speed() - 420)
		_score.text = "%d" % raw_score

		var heat := clampf(raw_score / 2000.0, 0.0, 1.0)
		_score.scale    = Vector2.ONE * (1.0 + heat * 0.5)
		_score.modulate = Color.WHITE.lerp(Color(1, 0.2, 0.2), heat)
		_score.position = _score_base_pos + Vector2(randf_range(-heat, heat), randf_range(-heat, heat)) * 2.0

func _despawn_passed_obstacles() -> void:
	for child in _obstacle_root.get_children():
		var ob := child as Node2D
		# 1200 px buffer: 300 (camera left edge) + 900 (safe margin for widest obstacles)
		if ob and ob.global_position.x < _player.global_position.x - 1200.0:
			ob.queue_free()

func _on_game_over() -> void:
	if not _running: return
	_running           = false

	# Stop the world
	_ground.speed      = 0
	_ground.ground_acc = 0

	# Trigger Player Death FX
	if _player.has_method("die_effect"):
		_player.die_effect()

	_msg_label.text = "GAME OVER\nPress R"
