@tool
class_name BallArena
extends Node2D
## Playable space is [0, arena_size.x] x [0, arena_size.y], in world units.

@export var arena_size: Vector2 = Vector2(960.0, 600.0):
	set(value):
		arena_size = value
		queue_redraw()
@export_range(4.0, 256.0, 1.0) var ball_diameter: float = 70.0
@export_range(1.0, 2000.0, 1.0) var ball_speed: float = 320.0
@export_range(2.0, 64.0, 1.0) var wall_thickness: float = 12.0
@export var experimental_blood_runoff: bool = true
@export var floor_color: Color = Color(0.075, 0.095, 0.13)
@export var wall_color: Color = Color(0.32, 0.38, 0.48)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	assert(arena_size.x >= ball_diameter * 4.0
		and arena_size.y >= ball_diameter * 4.0,
		"Each arena dimension must be at least four ball diameters.")
	_create_walls()
	var blue := $Balls/BlueBall as ArenaBall
	var red := $Balls/RedBall as ArenaBall
	blue.position = arena_size * Vector2(0.28, 0.38)
	red.position = arena_size * Vector2(0.72, 0.62)
	blue.experimental_blood_runoff = experimental_blood_runoff
	red.experimental_blood_runoff = experimental_blood_runoff
	blue.configure(ball_diameter, ball_speed)
	red.configure(ball_diameter, ball_speed)
	blue.opponent = red
	red.opponent = blue
	blue.blood_effects = $BloodEffects
	red.blood_effects = $BloodEffects
	$BloodEffects.floor_y = arena_size.y


func _create_walls() -> void:
	var w := arena_size.x
	var h := arena_size.y
	var t := wall_thickness
	# Inner faces coincide exactly with the edges of the playable rectangle.
	_add_wall("Top", Vector2(w * 0.5, -t * 0.5), Vector2(w + t * 2.0, t))
	_add_wall("Bottom", Vector2(w * 0.5, h + t * 0.5), Vector2(w + t * 2.0, t))
	_add_wall("Left", Vector2(-t * 0.5, h * 0.5), Vector2(t, h))
	_add_wall("Right", Vector2(w + t * 0.5, h * 0.5), Vector2(t, h))


func _add_wall(wall_name: String, center: Vector2, wall_size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = center
	wall.add_to_group("walls")
	# The balls supply restitution; walls add no extra bounce or friction.
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	wall.physics_material_override = material
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	collision.shape = rectangle
	wall.add_child(collision)
	$Walls.add_child(wall)


func _draw() -> void:
	var border := Rect2(Vector2.ONE * -wall_thickness,
		arena_size + Vector2.ONE * wall_thickness * 2.0)
	draw_rect(border, wall_color)
	draw_rect(Rect2(Vector2.ZERO, arena_size), floor_color)
