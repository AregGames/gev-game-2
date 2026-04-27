extends Node2D

var origin = Vector2.ZERO
var max_radius = 50
var current_radius = 0
var expansion_speed = 500
var lifetime = 0.0
var max_lifetime = 1.0
var color = Color.WHITE

func init(pos: Vector2, radius: float, col: Color, duration: float):
	origin = pos
	max_radius = radius
	color = col
	max_lifetime = duration

func _physics_process(delta):
	lifetime += delta
	current_radius = (lifetime / max_lifetime) * max_radius
	queue_redraw()
	
	if lifetime >= max_lifetime:
		queue_free()

func _draw():
	if current_radius > 0:
		draw_circle(origin, current_radius, Color(color.r, color.g, color.b, 0.3))
		draw_circle(origin, current_radius, color, false, 2.0)
