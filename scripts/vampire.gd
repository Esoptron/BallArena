@tool
class_name VampireFangs
extends Node2D
## Visual fangs + a non-solid bite range. Damage and healing happen in unit ticks.

signal bite_started(victim: ArenaBall)
signal bite_tick(victim: ArenaBall, damage: int, healing: int)
signal bite_finished

@export_range(0.1, 30.0, 0.1) var bite_duration: float = 3.0
@export_range(1, 100, 1) var bite_units: int = 10
@export_range(0.0, 100.0, 1.0) var bite_reach: float = 30.0
@export_range(0.0, 30.0, 0.1) var recovery_time: float = 1.0
@export_range(0.05, 2.0, 0.01) var drip_interval: float = 0.24

var has_bitten: bool = false
var ticks_remaining: int = 0
var cooldown_remaining: float = 0.0
var bite_target: ArenaBall
var fighter: ArenaBall
var _tick_elapsed: float = 0.0
var _drip_elapsed: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	fighter = get_parent() as ArenaBall
	show_behind_parent = true


func _process(delta: float) -> void:
	if fighter == null:
		return
	_clock += delta
	visible = fighter.is_vampire
	if not visible:
		return
	aim_at_opponent()
	if not Engine.is_editor_hint() and has_bitten and fighter.current_health > 0:
		_drip_elapsed += delta
		while _drip_elapsed >= drip_interval:
			_drip_elapsed -= drip_interval
			_emit_drips()
	queue_redraw()


func aim_at_opponent() -> void:
	if is_instance_valid(fighter.opponent):
		var direction := fighter.opponent.global_position - fighter.global_position
		if not direction.is_zero_approx():
			rotation = direction.angle() + PI * 0.5


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or fighter == null or not fighter.is_vampire:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if ticks_remaining > 0:
		if not is_instance_valid(bite_target) or bite_target.current_health <= 0 \
				or fighter.current_health <= 0:
			_finish_bite()
		else:
			_tick_elapsed += delta
			var interval := bite_duration / bite_units
			while _tick_elapsed + 0.000001 >= interval and ticks_remaining > 0:
				_tick_elapsed -= interval
				var damage := bite_target.take_damage(1)
				var healing := fighter.heal(damage)
				ticks_remaining -= 1
				bite_tick.emit(bite_target, damage, healing)
				if bite_target.current_health <= 0 or fighter.current_health <= 0:
					_finish_bite()
					break
			if ticks_remaining == 0 and bite_target != null:
				_finish_bite()
	if ticks_remaining == 0 and cooldown_remaining <= 0.0 \
			and is_instance_valid(fighter.opponent):
		var size_ratio := fighter.visual_diameter() / fighter.diameter
		var reach := fighter.visual_diameter() * 0.5 + bite_reach * size_ratio \
				+ fighter.opponent.visual_diameter() * 0.5
		if fighter.global_position.distance_to(fighter.opponent.global_position) <= reach:
			try_bite(fighter.opponent)


func try_bite(victim: ArenaBall) -> bool:
	if not fighter.can_start_bite() or ticks_remaining > 0 or cooldown_remaining > 0.0:
		return false
	if not is_instance_valid(victim) or victim == fighter or victim.current_health <= 0:
		return false
	bite_target = victim
	ticks_remaining = bite_units
	_tick_elapsed = 0.0
	cooldown_remaining = bite_duration + recovery_time
	has_bitten = true
	_drip_elapsed = 0.0
	victim.paralyze(bite_duration)
	bite_started.emit(victim)
	queue_redraw()
	return true


func _finish_bite() -> void:
	ticks_remaining = 0
	bite_target = null
	_tick_elapsed = 0.0
	bite_finished.emit()


func _emit_drips() -> void:
	if not is_instance_valid(fighter.blood_effects):
		return
	for origin in blood_origins():
		fighter.blood_effects.call("spawn_drop", to_global(origin), 2.8)


func blood_origins() -> PackedVector2Array:
	var radius := fighter.visual_diameter() * 0.5
	return PackedVector2Array([
		Vector2(-radius * 0.66, -radius * 1.15),
		Vector2(radius * 0.66, -radius * 1.15),
	])


func _draw() -> void:
	if fighter == null or not fighter.is_vampire:
		return
	var radius := fighter.visual_diameter() * 0.5
	if not has_bitten:
		_draw_aura(radius)
	var offsets := [-0.66, -0.24, 0.24, 0.66]
	for index in 4:
		var x: float = offsets[index] * radius
		var half_width := radius * (0.22 if index == 0 or index == 3 else 0.16)
		var tip_y := -radius * (1.85 if index == 0 or index == 3 else 1.32)
		var tip := Vector2(x - signf(x) * radius * 0.07, tip_y)
		var tooth := PackedVector2Array([
			Vector2(x - half_width, -radius * 0.58),
			Vector2(x - half_width * 0.68, tip_y * 0.73),
			tip,
			Vector2(x + half_width * 0.68, tip_y * 0.73),
			Vector2(x + half_width, -radius * 0.58),
		])
		draw_colored_polygon(tooth, Color(0.97, 0.97, 1.0))
		var shadow := PackedVector2Array([
			tip, tooth[3], tooth[4], Vector2(x, -radius * 0.58),
		])
		draw_colored_polygon(shadow, Color(0.67, 0.72, 0.82))
		var outline := tooth.duplicate()
		outline.append(tooth[0])
		draw_polyline(outline, Color(0.015, 0.01, 0.045), 1.7, true)
	if has_bitten:
		for origin in blood_origins():
			_draw_bead(origin, radius)


func _draw_aura(radius: float) -> void:
	for side in [-1.0, 1.0]:
		var curve := PackedVector2Array()
		for index in 21:
			var t := float(index) / 20.0
			var sway := sin(t * TAU * 1.4 + _clock * 4.6 + side) * radius * 0.14
			curve.append(Vector2(side * (radius * (0.92 + 0.24 * t) + sway),
				-radius * (0.88 + t * 1.23)))
		draw_polyline(curve, Color(0.47, 0.06, 1.0, 0.08), radius * 0.62, true)
		draw_polyline(curve, Color(0.55, 0.05, 1.0, 0.17), radius * 0.40, true)
		draw_polyline(curve, Color(0.67, 0.12, 1.0, 0.65), radius * 0.17, true)
		draw_polyline(curve, Color(0.86, 0.40, 1.0, 0.90), radius * 0.045, true)


func _draw_bead(origin: Vector2, radius: float) -> void:
	var size := radius * 0.115
	var wave := 0.85 + 0.15 * sin(_clock * 6.0)
	var points := PackedVector2Array([
		origin + Vector2(0.0, -size * 1.75),
		origin + Vector2(-size * 0.8, 0.0),
		origin + Vector2(-size * 0.65, size * wave),
		origin + Vector2(0.0, size * 1.2 * wave),
		origin + Vector2(size * 0.65, size * wave),
		origin + Vector2(size * 0.8, 0.0),
	])
	draw_colored_polygon(points, Color(0.8, 0.015, 0.035))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.14, 0.0, 0.015), 1.3, true)
	draw_circle(origin + Vector2(-size * 0.25, 0.0), size * 0.2, Color.WHITE)
