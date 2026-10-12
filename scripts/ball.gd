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
@export_range(0.0, 0.15, 0.005) var bite_pulse_amount: float = 0.05
@export_range(0.1, 10.0, 0.1) var bite_pulse_frequency: float = 2.0

var current_health: int = 100
var paralysis_remaining: float = 0.0
var opponent: ArenaBall
var blood_effects: Node2D
var _last_direction: Vector2 = Vector2.RIGHT
var _visual_time: float = 0.0
var attack_recovery_remaining: float = 0.0
var _motion_holds: Dictionary = {}
var _protection_sources: Dictionary = {}
var bite_marks: PackedVector2Array = PackedVector2Array()
var bite_marks_remaining: float = 0.0
var wound_bleeding_remaining: float = 0.0
var _wound_drip_elapsed: float = 0.0
var is_feeding: bool = false
var bite_body_base: float = 70.0
var bite_pulse_elapsed: float = 0.0


func _ready() -> void:
	_update_shape()
	var art := Node2D.new()
	art.name = "ApprovedVampireArt"
	art.show_behind_parent = true
	art.set_script(preload("res://scripts/approved_vampire_art.gd"))
	add_child(art)
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
		if is_feeding:
			bite_pulse_elapsed += delta
		_sync_pulse_shape()
		_advance_bite_marks(delta)
		attack_recovery_remaining = maxf(0.0, attack_recovery_remaining - delta)
	if Engine.is_editor_hint() or paralysis_remaining <= 0.0:
		return
	paralysis_remaining = maxf(0.0, paralysis_remaining - delta)
	if paralysis_remaining <= 0.000001:
		paralysis_remaining = 0.0
		_refresh_motion()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint():
		return
	if current_health <= 0 or is_immobilized():
		state.linear_velocity = Vector2.ZERO
		return
	if not state.linear_velocity.is_zero_approx():
		_last_direction = state.linear_velocity.normalized()
	state.linear_velocity = _last_direction * movement_speed
	state.angular_velocity = 0.0


func is_paralyzed() -> bool:
	return paralysis_remaining > 0.0


func can_start_bite() -> bool:
	return is_vampire and current_health > 0 and not is_immobilized() \
		and attack_recovery_remaining <= 0.0


func prevent_attacks(duration: float) -> void:
	attack_recovery_remaining = maxf(attack_recovery_remaining, duration)


func paralyze(duration: float) -> void:
	if current_health <= 0:
		return
	if not linear_velocity.is_zero_approx():
		_last_direction = linear_velocity.normalized()
	paralysis_remaining = maxf(paralysis_remaining, duration)
	freeze = true
	linear_velocity = Vector2.ZERO


func take_damage(amount: int) -> int:
	if is_invulnerable():
		return 0
	var applied := mini(maxi(amount, 0), current_health)
	current_health -= applied
	if applied > 0:
		health_changed.emit(current_health, max_health)
	if current_health == 0:
		freeze = true
		linear_velocity = Vector2.ZERO
	return applied


# Shared status API: any future ability can hold motion or grant protection.
func is_immobilized() -> bool:
	return is_paralyzed() or not _motion_holds.is_empty()


func is_invulnerable() -> bool:
	return not _protection_sources.is_empty()


func hold_motion(source: Node) -> void:
	_motion_holds[source.get_instance_id()] = true
	freeze = true
	linear_velocity = Vector2.ZERO


func release_motion(source: Node, departure: Vector2) -> void:
	_motion_holds.erase(source.get_instance_id())
	if not departure.is_zero_approx():
		_last_direction = departure.normalized()
	_refresh_motion()


func set_invulnerable(source: Node, enabled: bool) -> void:
	if enabled:
		_protection_sources[source.get_instance_id()] = true
	else:
		_protection_sources.erase(source.get_instance_id())
	queue_redraw()


func _refresh_motion() -> void:
	freeze = current_health <= 0 or is_immobilized()
	if not freeze:
		linear_velocity = _last_direction * movement_speed
		reset_physics_interpolation()


func body_color() -> Color:
	if current_health <= 0 and not Engine.is_editor_hint():
		return ball_color.darkened(0.65)
	if is_paralyzed():
		return ball_color.darkened(0.55)
	return ball_color


func apply_bite_marks(attacker_position: Vector2, fang_spacing: float) -> void:
	var facing := (attacker_position - global_position).normalized()
	if facing.is_zero_approx():
		facing = Vector2.LEFT
	var tangent := facing.orthogonal()
	var half_spacing := fang_spacing * 0.5
	var radius := visual_diameter() * 0.5 - 4.0
	var depth := sqrt(maxf(0.0, radius * radius - half_spacing * half_spacing))
	bite_marks = PackedVector2Array([
		to_local(global_position + facing * depth + tangent * half_spacing),
		to_local(global_position + facing * depth - tangent * half_spacing),
	])
	bite_marks_remaining = 3.0
	wound_bleeding_remaining = 2.0
	_wound_drip_elapsed = 0.0
	queue_redraw()


func _advance_bite_marks(delta: float) -> void:
	bite_marks_remaining = maxf(0.0, bite_marks_remaining - delta)
	var bleeding_step := minf(delta, wound_bleeding_remaining)
	wound_bleeding_remaining = maxf(0.0, wound_bleeding_remaining - delta)
	_wound_drip_elapsed += bleeding_step
	while _wound_drip_elapsed + 0.000001 >= 0.4:
		_wound_drip_elapsed -= 0.4
		if is_instance_valid(blood_effects):
			for point in bite_marks:
				blood_effects.call("spawn_drop", to_global(point), 4.2)
	if bite_marks_remaining <= 0.0:
		bite_marks.clear()


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


func begin_feeding(base_diameter: float) -> void:
	bite_body_base = base_diameter
	bite_pulse_elapsed = 0.0
	is_feeding = true


func end_feeding() -> void:
	is_feeding = false


func visual_diameter() -> float:
	if is_feeding:
		var breath := (1.0 - cos(bite_pulse_elapsed * TAU * bite_pulse_frequency)) * 0.5
		return bite_body_base * (1.0 - bite_pulse_amount * breath)
	if not is_vampire or not has_low_health():
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
	var color := body_color()
	if not is_vampire:
		# Shared cartoon body: a broad soft highlight and a deep lower-right crescent.
		draw_circle(Vector2.ZERO, radius + 1.25, Color(0.035, 0.015, 0.025))
		draw_circle(Vector2.ZERO, radius, color.darkened(0.26))
		var highlight_center := Vector2(-0.10, -0.13) * radius
		for layer in 18:
			var t := float(layer) / 17.0
			draw_circle(highlight_center, radius * lerpf(0.83, 0.66, t),
				color.lightened(t * 0.035))
		draw_arc(Vector2.ZERO, radius - 0.35, -PI + 0.16, -0.06, 64,
			color.lightened(0.17), 0.85, true)
		draw_arc(Vector2.ZERO, radius - 0.35, 0.08, PI - 0.12, 64,
			color.darkened(0.05), 0.65, true)

	for point in bite_marks:
		draw_circle(point, 3.5, Color(0.10, 0.005, 0.02))
		draw_circle(point, 2.3, Color(0.34, 0.01, 0.045))
	if is_invulnerable():
		_draw_protection(radius)


func _draw_protection(radius: float) -> void:
	# A breathing luminous seal, with three orbiting segments: shared by all characters.
	var pulse := 0.5 + 0.5 * sin(_visual_time * TAU * 2.5)
	var shield_radius := radius + 6.0 + 2.0 * pulse
	draw_arc(Vector2.ZERO, shield_radius, 0.0, TAU, 96,
		Color(0.32, 0.94, 1.0, 0.10 + 0.10 * pulse), 9.0, true)
	draw_arc(Vector2.ZERO, shield_radius, 0.0, TAU, 96,
		Color(0.65, 1.0, 1.0, 0.6 + 0.3 * pulse), 1.7, true)
	for index in 3:
		var angle := _visual_time * 2.4 + float(index) * TAU / 3.0
		draw_arc(Vector2.ZERO, shield_radius + 3.0, angle, angle + TAU * 0.19,
			24, Color(0.56, 0.98, 1.0, 0.9), 3.3, true)
		var tip := Vector2.from_angle(angle + TAU * 0.19) * (shield_radius + 3.0)
		draw_circle(tip, 2.4, Color(0.90, 1.0, 1.0))
