extends Node

@export var obstacle_scene: PackedScene

@export var player_path: NodePath
@export var ground_path: NodePath
@export var obstacle_root_path: NodePath

@export var spawn_offset: float = 200.0  # Distance beyond right edge of screen
@export var ground_y: float = 500.0
@export var min_t: float = 0.8
@export var max_t: float = 1.6

var running = true
var player: CharacterBody2D
var ground: Node
var obstacle_root: Node2D
var spawn_x: float  # Calculated dynamically

@onready var msg_label: Label = $"../../UI/msgLabel"
@onready var score: Label = $"../../UI/Score"

var t: float = 0.0

func _ready() -> void:
	if score:
		score.text = "Score: 0"
	if msg_label:
		msg_label.text = ""
	randomize()
	t = randf_range(min_t, max_t)
	
	player = get_node(player_path) as CharacterBody2D
	ground = get_node(ground_path)
	obstacle_root = get_node(obstacle_root_path) as Node2D
	
	# Calculate spawn_x based on viewport width
	var viewport_width = get_viewport().get_visible_rect().size.x
	spawn_x = viewport_width + spawn_offset
	print("Viewport width: ", viewport_width, " | Spawn X: ", spawn_x)
	
func _process(delta: float) -> void:
	if !running:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return
	var speed_value: float = float(ground.get("speed"))
	for child in obstacle_root.get_children():
		child.set("speed", speed_value)
	t -= delta
	if t <= 0.0:
		t = randf_range(min_t, max_t)
		spawn_one()
	if score:
		score.text = "Score: %d" % int(speed_value - 420)
	

func spawn_one() -> void:
	# Read ground speed
	var speed_value: float = float(ground.get("speed"))

	# Read jump parameters from Player script
	var v: float = float(player.call("get_jump_speed"))
	var g: float = float(player.call("get_gravity_y"))

	var jump_time: float = (2.0 * v) / g
	var max_w: float = (speed_value * jump_time) * 0.75
	var max_h: float = ((v * v) / (2.0 * g)) * 0.9

	var min_w: float = maxf(20.0, max_w * 0.20)
	var min_h: float = maxf(20.0, max_h * 0.35)

	var kind: int = int(randi() % 4)

	var w: float = 0.0
	var h: float = 0.0
	var c: Color = Color.WHITE

	if kind == 0:
		h = randf_range(min_h, max_h * 0.55)
		w = randf_range(min_w * 1.20, max_w * 0.80)
		c = Color(0.9, 0.9, 0.9)
	elif kind == 1:
		h = randf_range(max_h * 0.60, max_h)
		w = randf_range(min_w, max_w * 0.35)
		c = Color(0.2, 0.9, 0.2)
	elif kind == 2:
		h = randf_range(min_h, max_h * 0.80)
		w = randf_range(min_w, max_w * 0.55)
		c = Color(0.3, 0.7, 1.0)
	else:
		h = randf_range(min_h, max_h * 0.45)
		w = randf_range(min_w, max_w * 0.30)
		c = Color(1.0, 0.6, 0.2)

	var ob: Node2D = obstacle_scene.instantiate() as Node2D
	obstacle_root.add_child(ob)

	ob.set("speed", speed_value)
	ob.call("setup", w, h, c)

	ob.global_position = Vector2(spawn_x, ground_y - h * 0.5)
	
	ob.connect("hit_player", Callable(self, "_on_game_over"))
	
	print("spawned obstacle at: ", ob.global_position, " size=", Vector2(w, h))

func _on_game_over():
	running = false

	ground.speed = 0
	ground.ground_acc = 0
	for child in get_children():
		if child.has_method("set"):
			child.set("speed", 0)

	player.set_controls_enabled(false)

	msg_label.text = "GAME OVER\nPress R to restart"
