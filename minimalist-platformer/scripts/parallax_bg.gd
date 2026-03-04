extends CanvasLayer

# ─── Screen / geometry constants ─────────────────────────────────────────────
const SCREEN_W := 1600.0
const SCREEN_H := 900.0
const GROUND_Y := 615.0   # screen-space Y — aligns with where world y=-30 appears on screen
const STRIP_W  := 1800.0  # slightly wider than screen so seams never show
const N_STRIPS := 3       # enough copies to always fill the screen while wrapping

# ─── Layer config (back → front) ─────────────────────────────────────────────
# factor  : fraction of ground speed this layer scrolls (lower = farther away)
# color   : fill color of the polygon silhouettes
# h_min/max : mountain peak height range (pixels above GROUND_Y)
const LAYER_CONFIGS := [
	{"factor": 0.07, "color": Color(0.05, 0.01, 0.12), "h_min": 350.0, "h_max": 600.0, "peaks": 4},
	{"factor": 0.18, "color": Color(0.09, 0.02, 0.20), "h_min": 200.0, "h_max": 380.0, "peaks": 7},
	{"factor": 0.36, "color": Color(0.14, 0.04, 0.30), "h_min":  90.0, "h_max": 200.0, "peaks": 11},
]

# ─── Runtime state ────────────────────────────────────────────────────────────
var _ground     : Node
var _layer_data := []  # Array of { node: Node2D, strips: Array[Polygon2D], factor: float }

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("parallax_bg")
	layer = -1  # render behind the main canvas (game objects)
	_ground = get_parent().get_node("Ground")

	# Gradient background fill — sits behind mountains
	var bg := ColorRect.new()
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://assets/background.gdshader")
	bg.material = bg_mat
	add_child(bg)

	# Build mountain layers
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for cfg in LAYER_CONFIGS:
		var node := Node2D.new()
		add_child(node)

		var strips : Array[Polygon2D] = []
		for i in N_STRIPS:
			var poly := _make_strip(cfg, rng)
			# Spread strips so one is left, one on-screen, one right
			poly.position.x = (i - 1) * STRIP_W
			node.add_child(poly)
			strips.append(poly)

		_layer_data.append({"node": node, "strips": strips, "factor": cfg["factor"]})

	_add_rain()

func _process(delta: float) -> void:
	var speed := float(_ground.get("speed"))

	for ld in _layer_data:
		# Scroll this layer left at its parallax fraction of ground speed
		ld["node"].position.x -= speed * ld["factor"] * delta

		# Wrap any strip that has fully exited the left edge
		for strip: Polygon2D in ld["strips"]:
			var screen_x : float = ld["node"].position.x + strip.position.x
			if screen_x + STRIP_W < 0.0:
				strip.position.x += N_STRIPS * STRIP_W

# ─── Mountain generation ──────────────────────────────────────────────────────
func _make_strip(cfg: Dictionary, rng: RandomNumberGenerator) -> Polygon2D:
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, GROUND_Y))

	var x := 0.0
	while x < STRIP_W + 80.0:
		# Valley floor (slight random dip so it doesn't look totally flat)
		var valley_depth := rng.randf_range(0.0, cfg["h_min"] * 0.15)
		pts.append(Vector2(x, GROUND_Y - valley_depth))

		# Left shoulder of the next peak
		var peak_base_w := rng.randf_range(cfg["h_min"] * 0.6, cfg["h_max"] * 1.2)
		var left_w  := peak_base_w * rng.randf_range(0.35, 0.55)
		var right_w := peak_base_w - left_w
		var peak_h  := rng.randf_range(cfg["h_min"], cfg["h_max"])

		x += left_w
		pts.append(Vector2(x, GROUND_Y - peak_h))   # sharp peak tip
		x += right_w

		# Gap between this peak and the next
		x += rng.randf_range(10.0, peak_base_w * 0.4)

	# Close polygon along the bottom of the screen
	pts.append(Vector2(STRIP_W + 80.0, GROUND_Y))
	pts.append(Vector2(STRIP_W + 80.0, SCREEN_H + 10.0))
	pts.append(Vector2(-10.0, SCREEN_H + 10.0))

	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = cfg["color"]
	return poly

# ─── Rain ─────────────────────────────────────────────────────────────────────
func _add_rain() -> void:
	var rain := GPUParticles2D.new()
	rain.amount = 300
	rain.lifetime = 1.5
	rain.emitting = true
	rain.position = Vector2(SCREEN_W * 0.5, -20.0)

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.direction = Vector3(0.2, 1.0, 0.0)
	mat.spread = 2.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 600.0
	mat.initial_velocity_max = 950.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(SCREEN_W * 0.6, 5.0, 0.0)
	mat.color = Color(0.55, 0.25, 0.85, 0.22)
	rain.process_material = mat

	# GPUParticles2D uses texture, not draw_pass_1 (that's 3D only)
	var img := Image.create(2, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	rain.texture = ImageTexture.create_from_image(img)

	add_child(rain)
