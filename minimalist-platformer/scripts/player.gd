extends CharacterBody2D

# ─── Constants ───────────────────────────────────────────────────────────────
const JUMP_VELOCITY        := -500.0
const FIRST_TILT_DEG       := -30.0
const SPIN_SPEED_DEG       := 900.0
const LAND_TARGET_DEG      :=  0.0
const ROTATE_SPEED_DEG     := 720.0

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var ground_path: NodePath

# ─── State ────────────────────────────────────────────────────────────────────
var jumps_left        : int   = 2
var spinning          : bool  = false
var do_single_return  : bool  = false
var do_snap_quarter   : bool  = false
var spin_angle_deg    : float = 0.0
var controls_enabled  : bool  = true

# ─── Node References ─────────────────────────────────────────────────────────
@onready var sfx_jump_01 : AudioStreamPlayer = $SfxJump01
@onready var sfx_jump_45 : AudioStreamPlayer = $SfxJump45
@onready var _ground : Node = $"../Ground"



# ─── Main Loop ───────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return

	_apply_gravity(delta)
	_update_spin_tracking()
	_handle_landing(delta)
	_handle_jump_input(delta)
	_apply_air_spin(delta)

	# Player moves right at ground speed instead of ground scrolling left
	velocity.x = float(_ground.get("speed"))
	move_and_slide()


# ─── Physics Helpers ─────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _update_spin_tracking() -> void:
	spin_angle_deg = fposmod(rad_to_deg(rotation), 360.0)

func _handle_landing(delta: float) -> void:
	if not is_on_floor():
		return
	jumps_left = 2
	if spinning:
		spinning         = false
		do_snap_quarter  = true
		do_single_return = false
	if do_single_return:
		_rotate_clockwise_to_angle(delta, LAND_TARGET_DEG)
	elif do_snap_quarter:
		_rotate_clockwise_to_next_quarter(delta)

func _handle_jump_input(delta: float) -> void:
	if not Input.is_action_just_pressed("jump") or jumps_left <= 0:
		return
	velocity.y  = JUMP_VELOCITY
	jumps_left -= 1
	if jumps_left == 1:
		_start_single_jump(delta)
	else:
		_start_double_jump()

func _start_single_jump(delta: float) -> void:
	spinning         = false
	do_snap_quarter  = false
	do_single_return = false
	_rotate_to_angle(delta, FIRST_TILT_DEG)
	do_single_return = true
	sfx_jump_01.play()

func _start_double_jump() -> void:
	spinning         = true
	do_single_return = false
	do_snap_quarter  = false
	sfx_jump_45.play()

func _apply_air_spin(delta: float) -> void:
	if spinning and not is_on_floor():
		rotation += deg_to_rad(ROTATE_SPEED_DEG) * delta


# ─── Rotation Helpers ────────────────────────────────────────────────────────
func _rotate_clockwise_to_angle(delta: float, target_deg: float) -> void:
	var cur    := fposmod(rad_to_deg(rotation), 360.0)
	var target := fposmod(target_deg, 360.0)
	var dist   := fposmod(target - cur, 360.0)
	if dist < 1.0:
		rotation = deg_to_rad(target)
		do_single_return = false
		return
	var step := ROTATE_SPEED_DEG * delta
	if step >= dist:
		rotation = deg_to_rad(target)
		do_single_return = false
	else:
		rotation += deg_to_rad(step)

func _rotate_clockwise_to_next_quarter(delta: float) -> void:
	var cur          := fposmod(rad_to_deg(rotation), 360.0)
	var next_quarter := fposmod((floor(cur / 90.0) + 1.0) * 90.0, 360.0)
	var dist         := fposmod(next_quarter - cur, 360.0)
	if dist < 1.0:
		rotation = deg_to_rad(next_quarter)
		do_snap_quarter = false
		return
	var step := ROTATE_SPEED_DEG * delta
	if step >= dist:
		rotation = deg_to_rad(next_quarter)
		do_snap_quarter = false
	else:
		rotation += deg_to_rad(step)

func _rotate_to_angle(delta: float, target_deg: float) -> void:
	var cur    := fposmod(rad_to_deg(rotation), 360.0)
	var target := fposmod(target_deg, 360.0)
	var diff   := fposmod((target - cur) + 180.0, 360.0) - 180.0
	var step   := ROTATE_SPEED_DEG * delta
	if abs(diff) <= step:
		rotation = deg_to_rad(target)
	else:
		rotation += deg_to_rad(sign(diff) * step)


# ─── Public API ──────────────────────────────────────────────────────────────
func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled

func get_jump_speed() -> float:
	return abs(JUMP_VELOCITY)

func get_gravity_y() -> float:
	return abs(get_gravity().y)
