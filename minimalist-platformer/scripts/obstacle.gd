class_name Obstacle
extends Area2D

signal hit_player

@export var speed: float = 420.0

@onready var sp: Sprite2D = $Sprite2D
@onready var cs: CollisionShape2D = $CollisionShape2D

func setup(w: float, h: float, c: Color) -> void:
	# Visual size
	sp.scale = Vector2(w, h)
	sp.modulate = c
	sp.position = Vector2.ZERO

	# Collision box
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	global_position.x -= speed * delta
	if global_position.x < -200.0:
		queue_free()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node) -> void:
	if body.name == "player":
		hit_player.emit()
