extends CharacterBody2D

# ─── Constants ───────────────────────────────────────────────────────────────
const JUMP_VELOCITY   := -500.0
const SPIN_SPEED_DEG  := 900.0

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var ground_path: NodePath
@export_group("Juice Settings")
@export var squash_scale  := Vector2(1.55, 0.55)
@export var stretch_scale := Vector2(0.60, 1.55)
@export var shake_decay   := 5.0

# ─── State ────────────────────────────────────────────────────────────────────
var jumps_left      : int   = 2
var spinning        : bool  = false
var controls_enabled: bool  = true
var _is_crouching   : bool  = false
var _shake_strength : float = 0.0
var _sprite_base_scale : Vector2
var _sq_tween          : Tween = null

# Combo tracking
var _jump_combo : int = 0
var _streak     : int = 0
var _combo_hue  : float = 0.0  # for rainbow cycling at high streaks

# ─── Node refs ────────────────────────────────────────────────────────────────
@onready var sfx_jump_01  : AudioStreamPlayer = $SfxJump01
@onready var sfx_jump_45  : AudioStreamPlayer = $SfxJump45
@onready var sfx_death    : AudioStreamPlayer = $SfxDeath
@onready var sfx_land     : AudioStreamPlayer = $SfxLand
@onready var sfx_duck     : AudioStreamPlayer = $SfxDuck
@onready var sfx_combo    : AudioStreamPlayer = $SfxCombo
@onready var _ground      : Node              = $"../Ground"
@onready var _camera      : Camera2D          = $Camera2D
@onready var _sprite      : Sprite2D          = $Sprite2D
@onready var _col_shape   : CollisionShape2D  = $CollisionShape2D
@onready var p_trail      : GPUParticles2D    = $TrailParticles
@onready var p_jump       : GPUParticles2D    = $JumpParticles
@onready var p_land       : GPUParticles2D    = $LandParticles
@onready var p_death      : GPUParticles2D    = $DeathParticles
@onready var _combo_label : Label             = $"../UI/ComboLabel"

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	_camera.ignore_rotation = true
	_sprite_base_scale = _sprite.scale

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/neon_glow.gdshader")
	mat.set_shader_parameter("glow_color",     Color(0.75, 0.0, 1.0, 1.0))
	mat.set_shader_parameter("glow_intensity", 3.5)
	mat.set_shader_parameter("glow_size",      3.0)
	_sprite.material = mat

	var light := get_node_or_null("PointLight2D")
	if light:
		var tex := GradientTexture2D.new()
		tex.fill   = GradientTexture2D.FILL_RADIAL
		tex.width  = 256
		tex.height = 256
		light.texture       = tex
		light.texture_scale = 2.5
		light.energy        = 1.0
		light.color         = Color(0.7, 0.0, 1.0, 1.0)

	_setup_trail_particles()
	_setup_jump_particles()
	_setup_land_particles()

# ─── Per-frame ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Screen shake
	var shake_offset := Vector2.ZERO
	if VFXPanel.shake_enabled and _shake_strength > 0.01:
		_shake_strength = lerpf(_shake_strength, 0.0, shake_decay * delta)
		shake_offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	else:
		_shake_strength = 0.0

	_camera.global_rotation   = 0.0
	_camera.global_position.x = global_position.x + 500.0
	_camera.global_position.y = -200.0
	_camera.offset            = shake_offset

	# Rainbow combo label cycling at high streaks
	if _streak >= 10 and _combo_label and _combo_label.modulate.a > 0.0:
		_combo_hue = fmod(_combo_hue + delta * 2.0, 1.0)
		_combo_label.modulate = Color.from_hsv(_combo_hue, 1.0, 1.0, _combo_label.modulate.a)

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return

	_apply_gravity(delta)
	var was_on_floor := is_on_floor()
	_handle_duck_input()
	_handle_jump_input()
	_apply_air_spin(delta)
	_drift_rotation_to_zero(delta)

	velocity.x = float(_ground.get("speed"))
	move_and_slide()
	_handle_landing(was_on_floor)

# ─── Physics helpers ──────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_landing(was_on_floor: bool) -> void:
	if not is_on_floor():
		return

	var just_landed := not was_on_floor

	if just_landed and jumps_left < 2:
		if VFXPanel.squash_enabled:
			_tween_squash_stretch(squash_scale)
		if VFXPanel.shake_enabled:
			apply_screen_shake(5.0)
		if p_jump and VFXPanel.jump_particles_enabled:
			_set_jump_particle_color(Color(0.6, 1.0, 1.0))
			p_jump.restart()
		# Land particles burst
		if p_land and VFXPanel.jump_particles_enabled:
			p_land.restart()
		# Landing SFX
		if sfx_land:
			sfx_land.pitch_scale = randf_range(0.92, 1.08)
			sfx_land.play()
		if VFXPanel.combo_enabled:
			_trigger_combo()
		rotation = 0.0

	jumps_left = 2
	spinning   = false

func _handle_jump_input() -> void:
	if _is_crouching:
		return
	if not Input.is_action_just_pressed("jump") or jumps_left <= 0:
		return

	var is_double_jump := jumps_left == 1

	velocity.y   = JUMP_VELOCITY
	jumps_left  -= 1
	_jump_combo += 1

	if VFXPanel.squash_enabled:
		_tween_squash_stretch(stretch_scale)
	if p_jump and VFXPanel.jump_particles_enabled:
		_set_jump_particle_color(Color(0.1, 0.6, 1.0) if is_double_jump else Color(0.8, 0.4, 1.0))
		p_jump.restart()

	if jumps_left == 1:
		_start_single_jump()
	else:
		_start_double_jump()

func _start_single_jump() -> void:
	spinning = false
	sfx_jump_01.pitch_scale = randf_range(0.9, 1.1)
	sfx_jump_01.play()

func _start_double_jump() -> void:
	spinning = true
	sfx_jump_45.pitch_scale = randf_range(0.9, 1.1)
	sfx_jump_45.play()

func _apply_air_spin(delta: float) -> void:
	if spinning and not is_on_floor():
		rotation += deg_to_rad(SPIN_SPEED_DEG) * delta

func _drift_rotation_to_zero(delta: float) -> void:
	if not spinning and not is_on_floor() and abs(rotation) > 0.01:
		rotation = lerpf(rotation, 0.0, 3.0 * delta)

# ─── Duck mechanic ────────────────────────────────────────────────────────────
func _handle_duck_input() -> void:
	var want_duck := Input.is_action_pressed("duck")
	if want_duck != _is_crouching:
		_set_crouching(want_duck)

func _set_crouching(crouching: bool) -> void:
	_is_crouching = crouching

	# Cache two shapes instead of creating new ones every toggle
	var shape := RectangleShape2D.new()
	if _sq_tween: _sq_tween.kill()
	_sq_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_parallel(true)
	if crouching:
		shape.size = Vector2(80, 40)
		_col_shape.position.y = 20
		_sq_tween.tween_property(_sprite, "scale",
			Vector2(_sprite_base_scale.x * 1.4, _sprite_base_scale.y * 0.45), 0.08)
		_sq_tween.tween_property(_sprite, "position", Vector2(0, 20), 0.08)
		if p_trail: p_trail.position = Vector2(-20, 40)
		if sfx_duck:
			sfx_duck.pitch_scale = randf_range(0.95, 1.05)
			sfx_duck.play()
	else:
		shape.size = Vector2(80, 80)
		_col_shape.position.y = 0
		_sq_tween.tween_property(_sprite, "scale", _sprite_base_scale, 0.15)
		_sq_tween.tween_property(_sprite, "position", Vector2(0, 0), 0.15)
		if p_trail: p_trail.position = Vector2(-20, 0)
	_col_shape.shape = shape

# ─── Combo system ─────────────────────────────────────────────────────────────
func _trigger_combo() -> void:
	if _jump_combo >= 2:
		_streak += 1
		if _combo_label:
			# Escalate label size and color by streak level
			var label_scale : Vector2
			var label_color : Color
			if _streak >= 10:
				label_scale = Vector2(3.0, 3.0)
				label_color = Color(1.0, 1.0, 0.0)   # starts yellow, _process rainbows it
				apply_screen_shake(8.0)
			elif _streak >= 5:
				label_scale = Vector2(2.5, 2.5)
				label_color = Color(1.0, 0.5, 0.0)   # orange
			else:
				label_scale = Vector2(2.0, 2.0)
				label_color = Color(0.9, 0.5, 1.0)   # purple-white

			_combo_label.text       = "x%d STREAK!" % _streak
			_combo_label.modulate   = Color(label_color.r, label_color.g, label_color.b, 1.0)
			_combo_label.scale      = label_scale
			var tw := create_tween()
			tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.2)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.55)
			tw.tween_property(_combo_label, "modulate:a", 0.0, 0.25)\
				.set_ease(Tween.EASE_IN)

		# Combo SFX — pitch rises with streak
		if sfx_combo:
			sfx_combo.pitch_scale = clampf(1.0 + (_streak * 0.06), 1.0, 1.8)
			sfx_combo.play()
	else:
		# Missed the double-jump — break the streak
		_streak = 0
		_combo_hue = 0.0

	_jump_combo = 0

# ─── Visual effects ───────────────────────────────────────────────────────────
func _tween_squash_stretch(target_scale: Vector2) -> void:
	if _sq_tween:
		_sq_tween.kill()
	_sq_tween = create_tween()
	_sq_tween.tween_property(_sprite, "scale", target_scale * _sprite_base_scale, 0.07)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sq_tween.tween_property(_sprite, "scale", _sprite_base_scale, 0.40)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func apply_screen_shake(amount: float) -> void:
	_shake_strength = amount

func die_effect() -> void:
	controls_enabled = false
	velocity         = Vector2.ZERO
	_jump_combo      = 0
	_streak          = 0     # ← was missing before
	_combo_hue       = 0.0

	if p_trail: p_trail.emitting = false

	if _sq_tween: _sq_tween.kill()
	_sq_tween = create_tween()
	_sq_tween.tween_property(_sprite, "scale", _sprite_base_scale * 2.0, 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sq_tween.tween_property(_sprite, "scale", Vector2.ZERO, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	apply_screen_shake(30.0)

	await _sq_tween.finished
	_sprite.visible = false
	if p_death and VFXPanel.death_particles_enabled:
		p_death.emitting = true
	if sfx_death:
		sfx_death.play()

# ─── Particle setup ──────────────────────────────────────────────────────────
func _setup_trail_particles() -> void:
	if not p_trail: return
	p_trail.amount   = 20
	p_trail.lifetime = 0.55

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.spread               = 30.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 70.0
	mat.gravity              = Vector3(0, 120, 0)
	mat.scale_min            = 2.5
	mat.scale_max            = 5.5

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors  = PackedColorArray([
		Color(1.0, 0.1, 1.0, 1.0),
		Color(0.3, 0.0, 1.0, 0.9),
		Color(1.0, 0.4, 0.0, 0.7),
		Color(0.0, 0.9, 1.0, 0.4),
		Color(0.5, 0.0, 1.0, 0.0),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p_trail.process_material = mat
	p_trail.position = Vector2(-20, 0)
	p_trail.z_index  = -1

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p_trail.texture  = ImageTexture.create_from_image(img)
	p_trail.emitting = VFXPanel.trail_enabled

func _setup_jump_particles() -> void:
	if not p_jump: return
	p_jump.amount   = 30
	p_jump.lifetime = 0.45
	p_jump.one_shot = true

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.spread               = 65.0
	mat.initial_velocity_min = 100.0
	mat.initial_velocity_max = 260.0
	mat.gravity              = Vector3(0, 500, 0)
	mat.scale_min            = 2.5
	mat.scale_max            = 5.5
	mat.color                = Color(0.8, 0.4, 1.0)

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors  = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.5),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp   = grad_tex
	p_jump.process_material = mat
	p_jump.position  = Vector2(0, 40)
	p_jump.z_index   = -1

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p_jump.texture = ImageTexture.create_from_image(img)

func _setup_land_particles() -> void:
	if not p_land: return
	p_land.amount   = 20
	p_land.lifetime = 0.35
	p_land.one_shot = true

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.spread               = 70.0
	mat.direction            = Vector3(0, -1, 0)
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 120.0
	mat.gravity              = Vector3(0, 400, 0)
	mat.scale_min            = 3.0
	mat.scale_max            = 6.0
	mat.color                = Color(0.7, 0.6, 0.5, 0.6)
	p_land.process_material  = mat
	p_land.position          = Vector2(0, 40)   # at feet
	p_land.z_index           = -1

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p_land.texture = ImageTexture.create_from_image(img)

func _set_jump_particle_color(c: Color) -> void:
	if p_jump and p_jump.process_material is ParticleProcessMaterial:
		(p_jump.process_material as ParticleProcessMaterial).color = c

# ─── Public API ───────────────────────────────────────────────────────────────
func set_controls_enabled(enabled: bool) -> void: controls_enabled = enabled
func get_jump_speed() -> float: return abs(JUMP_VELOCITY)
func get_gravity_y()  -> float: return abs(get_gravity().y)
