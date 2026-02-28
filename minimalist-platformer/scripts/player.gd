extends CharacterBody2D

@onready var sfx_jump_01: AudioStreamPlayer = $SfxJump01
@onready var sfx_jump_45: AudioStreamPlayer = $SfxJump45

const JUMP_VELOCITY = -500.0

var double_jump: bool = true
var jumps_left: int = 2

const FIRST_TILT_DEG: float = -30.0          # backward tilt on first jump
const SPIN_SPEED_DEG: float = 900.0          # clockwise spin speed after double jump
const LAND_TARGET_DEG: float = 0.0           # final orientation on landing (set to 90 if you want)

var spinning: bool = false
var landing_fixing: bool = false

const ROTATE_SPEED_DEG: float = 720.0 

var do_single_return: bool = false     # Landing correction after single jump
var do_snap_quarter: bool = false      # Landing correction after double jump

var spin_angle_deg: float = 0.0
var controls_enabled: bool = true


func _physics_process(delta: float) -> void:
	if !controls_enabled:
		return
	
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Update spin tracking angle from current rotation (keep consistent)
	spin_angle_deg = fposmod(rad_to_deg(rotation), 360.0)

	# Landing logic
	if is_on_floor():
		jumps_left = 2

		# If spinning in air, start quarter-turn snap mode
		if spinning:
			spinning = false
			do_snap_quarter = true
			do_single_return = false

		# If single jump tilt
		if do_single_return:
			_rotate_clockwise_to_angle(delta, LAND_TARGET_DEG)
		elif do_snap_quarter:
			_rotate_clockwise_to_next_quarter(delta)

	# Jump input
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		
		
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
	
		# First jump
		if jumps_left == 1:
			spinning = false
			do_snap_quarter = false
			do_single_return = false

			# Tilt backward slightly
			_rotate_to_angle(delta, FIRST_TILT_DEG)
			do_single_return = true
			sfx_jump_01.play()
		# Second jump (in air)
		else:
			spinning = true
			do_single_return = false
			do_snap_quarter = false
			sfx_jump_45.play()

	# Air spin after double jump
	if spinning and not is_on_floor():
		rotation += deg_to_rad(ROTATE_SPEED_DEG) * delta
		
	velocity.x = 0.0
	move_and_slide()

# helper functions

# Correction after single jump
func _rotate_clockwise_to_angle(delta: float, target_deg: float) -> void:
	var cur: float = fposmod(rad_to_deg(rotation), 360.0)
	var target: float = fposmod(target_deg, 360.0)

	# Clockwise distance in degrees [0, 360)
	var dist: float = fposmod(target - cur, 360.0)

	# If already close enough, snap and stop
	if dist < 1.0:
		rotation = deg_to_rad(target)
		do_single_return = false
		return

	var step: float = ROTATE_SPEED_DEG * delta
	if step >= dist:
		rotation = deg_to_rad(target)
		do_single_return = false
	else:
		rotation += deg_to_rad(step)

# Correction after double jump
func _rotate_clockwise_to_next_quarter(delta: float) -> void:
	var cur: float = fposmod(rad_to_deg(rotation), 360.0)

	# Find the next quarter angle ahead of current angle (clockwise)
	var next_quarter: float = (floor(cur / 90.0) + 1.0) * 90.0
	next_quarter = fposmod(next_quarter, 360.0)

	var dist: float = fposmod(next_quarter - cur, 360.0)

	# Snap if close
	if dist < 1.0:
		rotation = deg_to_rad(next_quarter)
		do_snap_quarter = false
		return

	var step: float = ROTATE_SPEED_DEG * delta
	if step >= dist:
		rotation = deg_to_rad(next_quarter)
		do_snap_quarter = false
	else:
		rotation += deg_to_rad(step)

# Tilting agter jump
func _rotate_to_angle(delta: float, target_deg: float) -> void:
	var cur: float = fposmod(rad_to_deg(rotation), 360.0)
	var target: float = fposmod(target_deg, 360.0)

	var diff: float = target - cur
	diff = fposmod(diff + 180.0, 360.0) - 180.0  # normalize to [-180, 180]

	var step: float = ROTATE_SPEED_DEG * delta
	if abs(diff) <= step:
		rotation = deg_to_rad(target)
	else:
		rotation += deg_to_rad(sign(diff) * step)

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled

func get_jump_speed() -> float:
	return abs(JUMP_VELOCITY)
	
func get_gravity_y() -> float:
	return abs(get_gravity().y)
