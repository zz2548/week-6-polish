## vfx_panel.gd
## AUTOLOAD SINGLETON — add to Project Settings → Autoload
##   Name : VFXPanel
##   Path : res://vfx_panel.gd
##
## Because this is an autoload Node it is never freed on reload_current_scene(),
## so every toggle survives player death / scene restart automatically.
##
## Usage anywhere:
##   if VFXPanel.shake_enabled:
##       apply_screen_shake(5.0)

extends Node

# ─── Toggle flags ─────────────────────────────────────────────────────────────
var trail_enabled           : bool = true
var jump_particles_enabled  : bool = true
var death_particles_enabled : bool = true
var shake_enabled           : bool = true
var squash_enabled          : bool = true
var neon_glow_enabled       : bool = true
var combo_enabled           : bool = true
var score_heat_enabled      : bool = true
var obstacle_popin_enabled  : bool = true
var rain_enabled            : bool = true
var parallax_bg_enabled     : bool = true
