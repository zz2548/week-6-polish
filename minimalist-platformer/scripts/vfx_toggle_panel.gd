## vfx_toggle_panel.gd
## Attach to a CanvasLayer node (layer = 10).
## Press TAB in-game to show/hide the panel.
## Requires VFXPanel to be registered as an Autoload (see vfx_panel.gd).

class_name VFXTogglePanel
extends CanvasLayer

# ─── Toggle definitions ───────────────────────────────────────────────────────
const TOGGLE_LABELS := [
	"Trail Particles",   # 0
	"Jump Particles",    # 1
	"Death Particles",   # 2
	"Screen Shake",      # 3
	"Squash & Stretch",  # 4
	"Neon Glow",         # 5
	"Combo Label",       # 6
	"Score Heat",        # 7
	"Obstacle Pop-in",   # 8
	"Rain",              # 9
	"Parallax BG",       # 10
]

# ─── UI state ─────────────────────────────────────────────────────────────────
var _panel   : PanelContainer
var _visible := false
var _buttons : Array[Button] = []
var _rain    : GPUParticles2D = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 10
	_build_ui()
	_panel.visible = false
	# Store rain reference — parallax_bg registers itself to "parallax_bg" group
	var bg := get_tree().get_first_node_in_group("parallax_bg")
	if not bg:
		bg = get_node_or_null("/root/main/ParallaxBg")
	if bg:
		for child in bg.get_children():
			if child is GPUParticles2D:
				_rain = child
				break

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		_visible       = not _visible
		_panel.visible = _visible
		# Sync button states each time the panel opens so they reflect
		# whatever VFXPanel currently holds (survives scene reload).
		if _visible:
			_sync_buttons()

# ─── Sync buttons to current flag state ───────────────────────────────────────
func _sync_buttons() -> void:
	for i in _buttons.size():
		var on  := _get_flag(i)
		var btn := _buttons[i]
		btn.set_block_signals(true)
		btn.button_pressed = on
		btn.text = _btn_label(TOGGLE_LABELS[i], on)
		_apply_btn_style(btn, on)
		btn.set_block_signals(false)

# ─── Read / write VFXPanel flags by index ────────────────────────────────────
func _get_flag(idx: int) -> bool:
	match idx:
		0:  return VFXPanel.trail_enabled
		1:  return VFXPanel.jump_particles_enabled
		2:  return VFXPanel.death_particles_enabled
		3:  return VFXPanel.shake_enabled
		4:  return VFXPanel.squash_enabled
		5:  return VFXPanel.neon_glow_enabled
		6:  return VFXPanel.combo_enabled
		7:  return VFXPanel.score_heat_enabled
		8:  return VFXPanel.obstacle_popin_enabled
		9:  return VFXPanel.rain_enabled
		10: return VFXPanel.parallax_bg_enabled
	return true

func _set_flag(idx: int, value: bool) -> void:
	match idx:
		0:  VFXPanel.trail_enabled           = value
		1:  VFXPanel.jump_particles_enabled  = value
		2:  VFXPanel.death_particles_enabled = value
		3:  VFXPanel.shake_enabled           = value
		4:  VFXPanel.squash_enabled          = value
		5:  VFXPanel.neon_glow_enabled       = value
		6:  VFXPanel.combo_enabled           = value
		7:  VFXPanel.score_heat_enabled      = value
		8:  VFXPanel.obstacle_popin_enabled  = value
		9:  VFXPanel.rain_enabled            = value
		10: VFXPanel.parallax_bg_enabled     = value

# ─── UI builder ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left   = -285
	_panel.offset_top    = 20
	_panel.offset_right  = -20
	_panel.offset_bottom = 20 + 48 + TOGGLE_LABELS.size() * 46

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.04, 0.0, 0.10, 0.90)
	style.border_color = Color(0.55, 0.0, 1.0, 0.75)
	style.set_border_width_all(2)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		style.set("corner_radius_" + corner, 8)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "VFX TOGGLES  [TAB]"
	title.add_theme_color_override("font_color", Color(0.75, 0.2, 1.0))
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for i in TOGGLE_LABELS.size():
		var on  := _get_flag(i)
		var btn := Button.new()
		btn.text           = _btn_label(TOGGLE_LABELS[i], on)
		btn.toggle_mode    = true
		btn.button_pressed = on
		btn.focus_mode     = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		_apply_btn_style(btn, on)
		btn.toggled.connect(_on_toggled.bind(i, btn))
		vbox.add_child(btn)
		_buttons.append(btn)

	add_child(_panel)

func _btn_label(display: String, on: bool) -> String:
	return ("[ON]  " if on else "[OFF] ") + display

func _apply_btn_style(btn: Button, on: bool) -> void:
	btn.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.75) if on else Color(1.0, 0.3, 0.4))

# ─── Toggle handler ───────────────────────────────────────────────────────────
func _on_toggled(pressed: bool, idx: int, btn: Button) -> void:
	_set_flag(idx, pressed)
	btn.text = _btn_label(TOGGLE_LABELS[idx], pressed)
	_apply_btn_style(btn, pressed)
	_apply_side_effect(idx, pressed)

func _apply_side_effect(idx: int, on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/main/player")

	match idx:
		0:  # Trail Particles
			if player:
				var trail = player.get_node_or_null("TrailParticles")
				if trail:
					trail.emitting = on
					trail.visible  = on

		5:  # Neon Glow — player sprite, PointLight2D, WorldEnvironment, obstacles
			if player:
				var sprite = player.get_node_or_null("Sprite2D")
				if sprite:
					if on:
						var mat := ShaderMaterial.new()
						mat.shader = load("res://assets/neon_glow.gdshader")
						mat.set_shader_parameter("glow_color",     Color(0.75, 0.0, 1.0, 1.0))
						mat.set_shader_parameter("glow_intensity", 3.5)
						mat.set_shader_parameter("glow_size",      3.0)
						sprite.material = mat
					else:
						sprite.material = null
				var light = player.get_node_or_null("PointLight2D")
				if light:
					light.visible = on
			var world_env = get_tree().get_root().find_child("WorldEnvironment", true, false)
			if world_env and world_env.environment:
				world_env.environment.glow_enabled = on
			for ob in get_tree().get_nodes_in_group("obstacles"):
				if ob.has_method("set_neon_glow"):
					ob.set_neon_glow(on)

		6:  # Combo Label
			if player:
				var combo = player.get_node_or_null("../UI/ComboLabel")
				if combo:
					combo.visible = on

		7:  # Score Heat — reset to neutral when turned off
			var score_label := get_node_or_null("/root/main/UI/Score")
			if score_label and not on:
				score_label.scale    = Vector2.ONE
				score_label.modulate = Color.WHITE

		8:  # Obstacle Pop-in — affects future spawns only
			pass

		9:  # Rain
			if _rain:
				_rain.emitting = on
				_rain.visible  = on

		10: # Parallax BG
			var bg = get_tree().get_first_node_in_group("parallax_bg")
			if bg:
				bg.visible = on
