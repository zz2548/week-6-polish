class_name Obstacle
extends Area2D

signal hit_player

@onready var _sprite    : Sprite2D         = $Sprite2D
@onready var _collision : CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(w: float, h: float, c: Color) -> void:
	_sprite.visible = false
	_build_spike_visual(w, h, c, false)
	_setup_collision(w, h)
	_pop_in()

func setup_overhead(w: float, h: float, c: Color) -> void:
	_sprite.visible = false
	_build_spike_visual(w, h, c, true)
	_setup_overhead_collision(w, h)
	_pop_in()

func _setup_collision(w: float, h: float) -> void:
	var shape        := RectangleShape2D.new()
	shape.size        = Vector2(w, h)
	_collision.shape  = shape
	_collision.position = Vector2.ZERO

func _setup_overhead_collision(w: float, spike_h: float) -> void:
	var coll_h := 1000.0
	var shape   := RectangleShape2D.new()
	shape.size  = Vector2(w, coll_h)
	_collision.shape    = shape
	_collision.position = Vector2(0, spike_h * 0.5 - coll_h * 0.5)

func _pop_in() -> void:
	# Respect the toggle — if off, just appear instantly at full scale
	if not VFXPanel.obstacle_popin_enabled:
		scale = Vector2.ONE
		return
	scale = Vector2.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28)

func _build_spike_visual(w: float, h: float, c: Color, spikes_down: bool) -> void:
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()
	var poly := _make_spike_polygon(w, h, c, spikes_down)
	add_child(poly)

func _make_spike_polygon(w: float, h: float, c: Color, spikes_down: bool) -> Polygon2D:
	var n_spikes: int = maxi(2, int(w / 30.0))
	var spike_w  := w / float(n_spikes)
	var base_h   := h * 0.40
	var pts := PackedVector2Array()

	if not spikes_down:
		pts.append(Vector2(-w * 0.5,  h * 0.5))
		pts.append(Vector2( w * 0.5,  h * 0.5))
		pts.append(Vector2( w * 0.5,  h * 0.5 - base_h))
		for i in range(n_spikes - 1, -1, -1):
			var left_x  := -w * 0.5 + i * spike_w
			var right_x := left_x + spike_w
			var tip_x   := left_x + spike_w * 0.5
			pts.append(Vector2(right_x,  h * 0.5 - base_h))
			pts.append(Vector2(tip_x,   -h * 0.5))
			pts.append(Vector2(left_x,   h * 0.5 - base_h))
		pts.append(Vector2(-w * 0.5,  h * 0.5 - base_h))
	else:
		var ceiling_reach := -2000.0
		pts.append(Vector2(-w * 0.5, ceiling_reach))
		pts.append(Vector2( w * 0.5, ceiling_reach))
		pts.append(Vector2( w * 0.5, -h * 0.5 + base_h))
		for i in range(n_spikes - 1, -1, -1):
			var left_x  := -w * 0.5 + i * spike_w
			var right_x := left_x + spike_w
			var tip_x   := left_x + spike_w * 0.5
			pts.append(Vector2(right_x, -h * 0.5 + base_h))
			pts.append(Vector2(tip_x,    h * 0.5))
			pts.append(Vector2(left_x,  -h * 0.5 + base_h))
		pts.append(Vector2(-w * 0.5, -h * 0.5 + base_h))

	var polygon := Polygon2D.new()
	polygon.polygon = pts
	polygon.color   = c

	# Only apply glow shader if toggle is on
	if VFXPanel.neon_glow_enabled:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/neon_glow.gdshader")
		mat.set_shader_parameter("glow_color",     c)
		mat.set_shader_parameter("glow_intensity", 3.0)
		mat.set_shader_parameter("glow_size",      3.0)
		polygon.material = mat

	return polygon

func _on_body_entered(body: Node) -> void:
	if body.name == "player":
		hit_player.emit()
