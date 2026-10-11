@tool
class_name ArenaBall
extends RigidBody2D
## A frictionless circle. Godot resolves contacts; we maintain its target speed.

@export_range(4.0, 256.0, 1.0) var diameter: float = 70.0:
	set(value):
		diameter = value
		_update_shape()
@export_range(1.0, 2000.0, 1.0) var movement_speed: float = 320.0
@export var ball_color: Color = Color(0.16, 0.48, 1.0):
	set(value):
		ball_color = value
		queue_redraw()
@export var initial_direction: Vector2 = Vector2(1.0, 0.29)

var _last_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_update_shape()
	if not Engine.is_editor_hint():
		start_motion()


func configure(new_diameter: float, new_speed: float) -> void:
	diameter = new_diameter
	movement_speed = new_speed
	if not Engine.is_editor_hint():
		start_motion()


func start_motion() -> void:
	_last_direction = initial_direction.normalized()
	if _last_direction.is_zero_approx():
		_last_direction = Vector2.RIGHT
	linear_velocity = _last_direction * movement_speed
	reset_physics_interpolation()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint():
		return
	# Keep the direction produced by the collision solver, correcting only speed.
	if not state.linear_velocity.is_zero_approx():
		_last_direction = state.linear_velocity.normalized()
	state.linear_velocity = _last_direction * movement_speed
	state.angular_velocity = 0.0


func _update_shape() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var circle := CircleShape2D.new()
		circle.radius = diameter * 0.5
		collision.shape = circle
	queue_redraw()


func _draw() -> void:
	var radius := diameter * 0.5
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_arc(Vector2.ZERO, radius - 0.75, 0.0, TAU, 96,
		ball_color.lightened(0.35), 1.5, true)
