class_name Obstacle
extends Area2D

# ─── Signals ─────────────────────────────────────────────────────────────────
signal hit_player

# ─── Nodes ───────────────────────────────────────────────────────────────────
@onready var _sprite    : Sprite2D         = $Sprite2D
@onready var _collision : CollisionShape2D = $CollisionShape2D


# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)

# No _physics_process needed — obstacles are stationary in world space.
# Despawning is handled by obs_spawner._despawn_passed_obstacles()


# ─── Public API ──────────────────────────────────────────────────────────────
func setup(w: float, h: float, c: Color) -> void:
	_sprite.scale    = Vector2(w, h)
	_sprite.modulate = c
	_sprite.position = Vector2.ZERO

	# Apply neon glow shader
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/neon_glow.gdshader")
	mat.set_shader_parameter("glow_color", c)
	mat.set_shader_parameter("glow_intensity", 3.0)
	mat.set_shader_parameter("glow_size", 3.0)
	_sprite.material = mat

	var shape           := RectangleShape2D.new()
	shape.size          = Vector2(w, h)
	_collision.shape    = shape
	_collision.position = Vector2.ZERO

# ─── Collision ───────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.name == "player":
		hit_player.emit()
