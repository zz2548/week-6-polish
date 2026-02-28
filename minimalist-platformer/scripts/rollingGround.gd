extends Node2D
@export var speed := 420.0
@export var ground_width := 1200.0
@export var ground_acc := 15.0

@onready var g1 := $Ground1
@onready var g2 := $Ground2
@onready var g3 := $Ground3  

func _ready() -> void:
	g1.position.x = 0.0
	g2.position.x = ground_width
	g3.position.x = ground_width * 2.0

func _physics_process(delta: float) -> void:
	speed = speed + ground_acc * delta
	var dx = speed * delta
	
	g1.position.x -= dx
	g2.position.x -= dx
	g3.position.x -= dx
	
	# Wrap each tile individually
	if g1.position.x <= -ground_width:
		g1.position.x = max(g2.position.x, max(g3.position.x, g1.position.x)) + ground_width
	if g2.position.x <= -ground_width:
		g2.position.x = max(g1.position.x, max(g3.position.x, g2.position.x)) + ground_width
	if g3.position.x <= -ground_width:
		g3.position.x = max(g1.position.x, max(g2.position.x, g3.position.x)) + ground_width
