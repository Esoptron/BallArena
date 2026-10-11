@tool
class_name ArenaBall
extends RigidBody2D
## A moving circle with health. The collider follows its pulsating body; fangs are non-solid.

signal health_changed(value: int, maximum: int)

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
@export var is_vampire: bool = true
@export_range(1, 10000, 1) var max_health: int = 100
@export_range(1, 10000, 1) var starting_health: int = 100
@export_range(0.0, 1.0, 0.01) var low_health_threshold: float = 0.30
@export_range(0.0, 20.0, 0.1) var pulse_frequency: float = 4.0
@export_range(0.1, 1.0, 0.01) var pulse_minimum_ratio: float = 50.0 / 70.0

var current_health: int = 100
var paralysis_remaining: float = 0.0
var opponent: ArenaBall
var blood_effects: Node2D
var _last_direction: Vector2 = Vector2.RIGHT
var _visual_time: float = 0.0
var _paralyzed_at_frame: int = -1


func _ready() -> void:
	_update_shape()
	current_health = clampi(starting_health, 1, max_health)
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


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_visual_time += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_visual_time += delta
		_sync_pulse_shape()
	if Engine.is_editor_hint() or paralysis_remaining <= 0.0:
		return
	paralysis_remaining = maxf(0.0, paralysis_remaining - delta)
	if paralysis_remaining <= 0.000001:
		paralysis_remaining = 0.0
		if current_health > 0:
			freeze = false
			linear_velocity = _last_direction * movement_speed
			reset_physics_interpolation()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint():
		return
	if current_health <= 0 or is_paralyzed():
		state.linear_velocity = Vector2.ZERO
		return
	if not state.linear_velocity.is_zero_approx():
		_last_direction = state.linear_velocity.normalized()
	state.linear_velocity = _last_direction * movement_speed
	state.angular_velocity = 0.0


func is_paralyzed() -> bool:
	return paralysis_remaining > 0.0


func can_start_bite() -> bool:
	# Both vampires may land a simultaneous opening bite on the same physics tick.
	return is_vampire and current_health > 0 and (
		not is_paralyzed() or _paralyzed_at_frame == Engine.get_physics_frames())


func paralyze(duration: float) -> void:
	if current_health <= 0:
		return
	if not linear_velocity.is_zero_approx():
		_last_direction = linear_velocity.normalized()
	paralysis_remaining = maxf(paralysis_remaining, duration)
	_paralyzed_at_frame = Engine.get_physics_frames()
	freeze = true
	linear_velocity = Vector2.ZERO


func take_damage(amount: int) -> int:
	var applied := mini(maxi(amount, 0), current_health)
	current_health -= applied
	if applied > 0:
		health_changed.emit(current_health, max_health)
	if current_health == 0:
		freeze = true
		linear_velocity = Vector2.ZERO
	return applied


func heal(amount: int) -> int:
	if current_health <= 0:
		return 0
	var applied := mini(maxi(amount, 0), max_health - current_health)
	current_health += applied
	if applied > 0:
		health_changed.emit(current_health, max_health)
	return applied


func has_low_health() -> bool:
	var health := starting_health if Engine.is_editor_hint() else current_health
	return health > 0 and float(health) / max_health < low_health_threshold


func visual_diameter() -> float:
	if not has_low_health():
		return diameter
	var wave := (1.0 - cos(_visual_time * TAU * pulse_frequency)) * 0.5
	return diameter * lerpf(1.0, pulse_minimum_ratio, wave)


func _sync_pulse_shape() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var circle := collision.shape as CircleShape2D
		var desired_radius := visual_diameter() * 0.5
		if circle != null and not is_equal_approx(circle.radius, desired_radius):
			circle.radius = desired_radius


func _update_shape() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var circle := CircleShape2D.new()
		circle.radius = diameter * 0.5
		collision.shape = circle
	queue_redraw()


func _draw() -> void:
	var radius := visual_diameter() * 0.5
	var color := ball_color
	if current_health <= 0 and not Engine.is_editor_hint():
		color = color.darkened(0.65)
	draw_circle(Vector2.ZERO, radius + 1.5, Color(0.015, 0.02, 0.045))
	draw_circle(Vector2.ZERO, radius, color.darkened(0.20))
	draw_circle(Vector2(-radius * 0.14, -radius * 0.17), radius * 0.82, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, color.lightened(0.15), 1.0, true)
	draw_circle(Vector2(-radius * 0.46, -radius * 0.53), radius * 0.095,
		Color(0.75, 0.95, 1.0, 0.8))
