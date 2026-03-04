extends Node

@export var obstacle_scene     : PackedScene
@export var player_path        : NodePath
@export var ground_path        : NodePath
@export var obstacle_root_path : NodePath
@export var spawn_offset       : float = 200.0
@export var ground_y           : float = 500.0
@export var min_t              : float = 2.0
@export var max_t              : float = 3.5

var _running     : bool  = true
var _spawn_timer : float

# Tracks which obstacles have already fired avoided so we never double-count.
var _avoided_set : Dictionary = {}

const OVERHEAD_BOTTOM_Y := -88.0

@onready var _player        : CharacterBody2D = $"../../player"
@onready var _ground        : Node            = $"../../Ground"
@onready var _obstacle_root : Node2D          = $".."
@onready var _msg_label : Label = $"../../UI/msgLabel"
@onready var _score     : Label = $"../../UI/Score"

const OBSTACLE_KINDS := [
	{ "color": Color(1.0, 0.1, 0.7),  "h_range": [0.00, 0.55], "w_range": [1.20, 0.80] },
	{ "color": Color(0.55, 0.0, 1.0), "h_range": [0.60, 1.00], "w_range": [1.00, 0.35] },
	{ "color": Color(0.9, 0.0, 0.5),  "h_range": [0.00, 0.80], "w_range": [1.00, 0.55] },
	{ "color": Color(0.45, 0.1, 1.0), "h_range": [0.00, 0.45], "w_range": [1.00, 0.30] },
]

func _ready() -> void:
	randomize()
	_spawn_timer = randf_range(min_t, max_t)
	if _score:     _score.text = "0"
	if _msg_label: _msg_label.text = ""

func _process(delta: float) -> void:
	if not _running:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return
	_update_score(delta)
	_tick_spawner(delta)
	_check_avoided_and_despawn()

func _tick_spawner(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(min_t, max_t)
		var speed_factor := clampf(_get_ground_speed() / 1200.0, 0.0, 0.30)
		_spawn_timer -= (_spawn_timer * speed_factor)
		if randf() < 0.25:
			_spawn_overhead()
		else:
			_spawn_one()

func _spawn_one() -> void:
	var ob := _instantiate_obstacle()
	var limits := _calc_size_limits(_get_ground_speed())
	var kind : Dictionary = OBSTACLE_KINDS[randi() % OBSTACLE_KINDS.size()]
	var h := maxf(randf_range(limits[2] * kind["h_range"][0], limits[3] * kind["h_range"][1]), limits[2])
	var w := maxf(randf_range(limits[0] * kind["w_range"][0], limits[1] * kind["w_range"][1]), limits[0])
	var viewport_width := get_viewport().get_visible_rect().size.x
	ob.global_position = Vector2(_player.global_position.x + viewport_width * 0.5 + spawn_offset, ground_y - h * 0.5)
	ob.call("setup", w, h, kind["color"])

func _spawn_overhead() -> void:
	var ob := _instantiate_obstacle()
	var limits := _calc_size_limits(_get_ground_speed())
	var kind : Dictionary = OBSTACLE_KINDS[randi() % OBSTACLE_KINDS.size()]
	var h := 55.0
	var w := maxf(randf_range(limits[0] * 0.8, limits[1] * 0.6), limits[0])
	var viewport_width := get_viewport().get_visible_rect().size.x
	ob.global_position = Vector2(
		_player.global_position.x + viewport_width * 0.5 + spawn_offset,
		OVERHEAD_BOTTOM_Y - h * 0.5
	)
	ob.call("setup_overhead", w, h, kind["color"])

func _instantiate_obstacle() -> Node2D:
	var ob := obstacle_scene.instantiate() as Node2D
	_obstacle_root.add_child(ob)
	ob.connect("hit_player", _on_game_over)
	# avoided is emitted by us below, not by the obstacle itself
	return ob

func _check_avoided_and_despawn() -> void:
	# Player's left edge — used as the "cleared" threshold.
	# The collision box is 80px wide and centred, so left edge is x - 40.
	var player_left : float = _player.global_position.x - 40.0

	for child in _obstacle_root.get_children():
		var ob := child as Node2D
		if not ob:
			continue

		# Each obstacle stores its width via the collision shape.
		# Right edge = ob.global_position.x + half_width.
		# We approximate half_width from the CollisionShape2D if available,
		# otherwise fall back to 0 (still works, just fires at ob centre).
		var half_w : float = 0.0
		var col := ob.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			half_w = (col.shape as RectangleShape2D).size.x * 0.5

		var ob_right : float = ob.global_position.x + half_w

		# Fire avoided the first frame the obstacle's right edge clears the player.
		if ob_right < player_left and not _avoided_set.has(ob):
			_avoided_set[ob] = true
			ob.avoided.emit()
			_on_obstacle_avoided()

		# Despawn well off the left edge as before.
		if ob.global_position.x < _player.global_position.x - 1200.0:
			_avoided_set.erase(ob)
			ob.queue_free()

func _on_obstacle_avoided() -> void:
	if _player.has_method("on_obstacle_avoided"):
		_player.on_obstacle_avoided()

func _calc_size_limits(current_speed: float) -> Array[float]:
	var v         : float = _player.call("get_jump_speed")
	var g         : float = _player.call("get_gravity_y")
	var jump_time : float = (2.0 * v) / g
	var max_w     : float = minf((current_speed * jump_time) * 0.75, 350.0)
	var max_h     : float = ((v * v) / (2.0 * g)) * 0.9
	var min_w     : float = maxf(20.0, max_w * 0.20)
	var min_h     : float = maxf(20.0, max_h * 0.35)
	return [min_w, max_w, min_h, max_h]

func _get_ground_speed() -> float:
	return float(_ground.get("speed"))

func _update_score(delta: float) -> void:
	if _score:
		var raw_score := maxi(0, int(_get_ground_speed() - 420))
		_score.text = "%d" % raw_score

		if VFXPanel.score_heat_enabled:
			var heat := clampf(raw_score / 2000.0, 0.0, 1.0)
			_score.scale    = Vector2.ONE * (1.0 + heat * 0.5)
			_score.modulate = Color.WHITE.lerp(Color(1, 0.2, 0.2), heat)
			_score.position += Vector2(randf_range(-heat, heat), randf_range(-heat, heat)) * 2.0
		else:
			_score.scale    = Vector2.ONE
			_score.modulate = Color.WHITE

	var music := get_node_or_null("/root/main/Music")
	if music:
		music.pitch_scale = clampf(1.0 + (_get_ground_speed() - 420.0) / 4000.0, 1.0, 1.25)

func _on_game_over() -> void:
	if not _running: return
	_running           = false
	_ground.speed      = 0
	_ground.ground_acc = 0
	if _player.has_method("die_effect"):
		_player.die_effect()
	_msg_label.text = "GAME OVER\nPress R"
