class_name Obstacle
extends Area2D

# ─── Signals ─────────────────────────────────────────────────────────────────
signal hit_player

# ─── Nodes ───────────────────────────────────────────────────────────────────
@onready var _sprite    : Sprite2D         = $Sprite2D
@onready var _collision : CollisionShape2D = $CollisionShape2D


# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("obstacles")
	body_entered.connect(_on_body_entered)


# ─── Public API ──────────────────────────────────────────────────────────────

# Floor obstacle: spikes point upward
func setup(w: float, h: float, c: Color) -> void:
	_sprite.visible = false
	_build_spike_visual(w, h, c, false)
	_setup_collision(w, h)
	_pop_in()

# Ceiling obstacle: spikes point downward, positioned above the player's head
func setup_overhead(w: float, h: float, c: Color) -> void:
	_sprite.visible = false
	_build_spike_visual(w, h, c, true)
	_setup_overhead_collision(w, h)
	_pop_in()


# ─── Internals ───────────────────────────────────────────────────────────────
func _setup_collision(w: float, h: float) -> void:
	var shape        := RectangleShape2D.new()
	shape.size        = Vector2(w, h)
	_collision.shape  = shape
	_collision.position = Vector2.ZERO

func _setup_overhead_collision(w: float, spike_h: float) -> void:
	# Extend the hitbox far above so even a double-jump can't fly over it.
	# The box bottom stays at the spike tips (local y = +spike_h/2).
	var coll_h := 1000.0
	var shape   := RectangleShape2D.new()
	shape.size  = Vector2(w, coll_h)
	_collision.shape    = shape
	# Offset so the bottom of the box aligns with the spike tip level
	_collision.position = Vector2(0, spike_h * 0.5 - coll_h * 0.5)

func _pop_in() -> void:
	if not VFXPanel.obstacle_popin_enabled:
		scale = Vector2.ONE
		return
	scale = Vector2.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28)

func _build_spike_visual(w: float, h: float, c: Color, spikes_down: bool) -> void:
	# Remove any previously generated polygon
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()

	var poly := _make_spike_polygon(w, h, c, spikes_down)
	add_child(poly)

func _make_spike_polygon(w: float, h: float, c: Color, spikes_down: bool) -> Polygon2D:
	# Number of spikes scales with width, minimum 2
	var n_spikes: int = maxi(2, int(w / 30.0))
	var spike_w  := w / float(n_spikes)
	# Base takes up ~40% of total height, teeth take remaining 60%
	var base_h   := h * 0.40

	var pts := PackedVector2Array()

	if not spikes_down:
		# Spikes pointing UP — base at bottom (positive y), tips at top (negative y)
		# Bottom-left corner
		pts.append(Vector2(-w * 0.5,  h * 0.5))
		# Bottom-right corner
		pts.append(Vector2( w * 0.5,  h * 0.5))
		# Right side going up to base-top
		pts.append(Vector2( w * 0.5,  h * 0.5 - base_h))
		# Teeth (right to left so polygon winds correctly)
		for i in range(n_spikes - 1, -1, -1):
			var left_x  := -w * 0.5 + i * spike_w
			var right_x := left_x + spike_w
			var tip_x   := left_x + spike_w * 0.5
			pts.append(Vector2(right_x,  h * 0.5 - base_h))
			pts.append(Vector2(tip_x,   -h * 0.5))          # tip
			pts.append(Vector2(left_x,   h * 0.5 - base_h))
		# Left side back to bottom
		pts.append(Vector2(-w * 0.5,  h * 0.5 - base_h))
	else:
		# Spikes pointing DOWN — body extends up off-screen so it looks attached to the ceiling
		var ceiling_reach := -2000.0
		pts.append(Vector2(-w * 0.5, ceiling_reach))
		pts.append(Vector2( w * 0.5, ceiling_reach))
		# Right side going down to base-bottom
		pts.append(Vector2( w * 0.5, -h * 0.5 + base_h))
		# Teeth (right to left)
		for i in range(n_spikes - 1, -1, -1):
			var left_x  := -w * 0.5 + i * spike_w
			var right_x := left_x + spike_w
			var tip_x   := left_x + spike_w * 0.5
			pts.append(Vector2(right_x, -h * 0.5 + base_h))
			pts.append(Vector2(tip_x,    h * 0.5))           # tip (downward)
			pts.append(Vector2(left_x,  -h * 0.5 + base_h))
		# Left side back to top
		pts.append(Vector2(-w * 0.5, -h * 0.5 + base_h))

	var polygon := Polygon2D.new()
	polygon.polygon = pts
	polygon.color   = c

	if VFXPanel.neon_glow_enabled:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/neon_glow.gdshader")
		mat.set_shader_parameter("glow_color",     c)
		mat.set_shader_parameter("glow_intensity", 3.0)
		mat.set_shader_parameter("glow_size",      3.0)
		polygon.material = mat

	return polygon


func set_neon_glow(enabled: bool) -> void:
	for child in get_children():
		if child is Polygon2D:
			if enabled:
				var c    := (child as Polygon2D).color
				var mat  := ShaderMaterial.new()
				mat.shader = load("res://assets/neon_glow.gdshader")
				mat.set_shader_parameter("glow_color",     c)
				mat.set_shader_parameter("glow_intensity", 3.0)
				mat.set_shader_parameter("glow_size",      3.0)
				child.material = mat
			else:
				child.material = null

# ─── Collision ───────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.name == "player":
		hit_player.emit()
