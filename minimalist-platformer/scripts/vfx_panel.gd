## vfx_panel.gd
## Standalone class — no node, no scene attachment needed.
## Place this file anywhere in res:// (e.g. res://vfx_panel.gd).
##
## Any script can read/write these flags directly:
##   if VFXPanel.shake_enabled:
##       apply_screen_shake(5.0)

class_name VFXPanel

static var trail_enabled           : bool = true
static var jump_particles_enabled  : bool = true
static var death_particles_enabled : bool = true
static var shake_enabled           : bool = true
static var squash_enabled          : bool = true
static var neon_glow_enabled       : bool = true
static var combo_enabled           : bool = true
static var score_heat_enabled      : bool = true
static var obstacle_popin_enabled  : bool = true
static var rain_enabled            : bool = true
