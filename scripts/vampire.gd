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
@export_range(0.0, 0.6, 0.01) var tooth_immersion: float = 1.0 / 3.0

var has_bitten: bool = false
var ticks_remaining: int = 0
var cooldown_remaining: float = 0.0
var bite_target: ArenaBall
var fighter: ArenaBall
var _tick_elapsed: float = 0.0
var _mist: Polygon2D
var _mist_material: ShaderMaterial
var _clock: float = 0.0
var _fur: Node2D


func _ready() -> void:
	fighter = get_parent() as ArenaBall
	show_behind_parent = true
	# Teeth are behind both bodies, regardless of their order in the arena.
	z_index = -1
	_mist = Polygon2D.new()
	_mist.name = "FangMist"
	_mist.show_behind_parent = true
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://scripts/fang_mist.gdshader")
	_mist.material = _mist_material
	add_child(_mist)
	_fur = Node2D.new()
	_fur.name = "FangRoots"
	_fur.z_index = 2
	_fur.set_script(preload("res://scripts/vampire_fur.gd"))
	add_child(_fur)


func _process(delta: float) -> void:
	if fighter == null:
		return
	_clock += delta
	visible = fighter.is_vampire
	if not visible:
		return
	aim_at_opponent()
	_update_mist()
	_fur.queue_redraw()
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
	if not is_instance_valid(victim) or victim == fighter or victim.current_health <= 0 or victim.is_invulnerable():
		return false
	bite_target = victim
	ticks_remaining = bite_units
	_tick_elapsed = 0.0
	cooldown_remaining = bite_duration + recovery_time
	has_bitten = true
	aim_at_opponent()
	fighter.hold_motion(self)
	fighter.set_invulnerable(self, true)
	victim.hold_motion(self)
	victim.paralyze(bite_duration)
	_place_for_bite(victim)
	bite_started.emit(victim)
	queue_redraw()
	return true


func _finish_bite() -> void:
	if bite_target == null:
		return
	var victim := bite_target
	var completed := ticks_remaining == 0
	ticks_remaining = 0
	bite_target = null
	_tick_elapsed = 0.0
	var away := Vector2.UP.rotated(global_rotation)
	if is_instance_valid(victim):
		away = (victim.global_position - fighter.global_position).normalized()
		if away.is_zero_approx():
			away = Vector2.RIGHT
		if completed and victim.current_health > 0:
			victim.apply_bite_marks(fighter.global_position, fang_spacing())
		victim.prevent_attacks(recovery_time)
		victim.release_motion(self, away)
	fighter.set_invulnerable(self, false)
	fighter.release_motion(self, -away)
	bite_finished.emit()


func _exit_tree() -> void:
	if is_instance_valid(fighter) and bite_target != null:
		_finish_bite()


func fang_spacing() -> float:
	# The separation of the two long tooth tips, including their inward tilt.
	return fighter.visual_diameter() * 0.59


func _place_for_bite(victim: ArenaBall) -> void:
	var toward := (victim.global_position - fighter.global_position).normalized()
	if toward.is_zero_approx():
		toward = Vector2.UP.rotated(global_rotation)
	var radius := fighter.visual_diameter() * 0.5
	var victim_radius := victim.visual_diameter() * 0.5
	var half_spacing := fang_spacing() * 0.5
	var exposed_length := radius * 1.85 - sqrt(radius * radius - half_spacing * half_spacing)
	var victim_surface := sqrt(maxf(0.0, victim_radius * victim_radius - half_spacing * half_spacing))
	var separation := radius * 1.85 + victim_surface - exposed_length * tooth_immersion
	# Keep the circular bodies separate even if a low-health pulse later grows.
	separation = maxf(separation, (fighter.diameter + victim.diameter) * 0.5 + 0.5)
	fighter.global_position = victim.global_position - toward * separation
	# At a wall, translate the pair together instead of pushing a body through it.
	var arena := fighter.get_parent().get_parent() as BallArena
	if arena != null:
		var fighter_radius := fighter.diameter * 0.5
		var target_radius := victim.diameter * 0.5
		var footprint := Rect2(arena.to_local(fighter.global_position) - Vector2.ONE * fighter_radius,
			Vector2.ONE * fighter.diameter).merge(Rect2(
			arena.to_local(victim.global_position) - Vector2.ONE * target_radius,
			Vector2.ONE * victim.diameter))
		var shift := Vector2(
			clampf(0.0, 0.5 - footprint.position.x, arena.arena_size.x - 0.5 - footprint.end.x),
			clampf(0.0, 0.5 - footprint.position.y, arena.arena_size.y - 0.5 - footprint.end.y))
		var world_shift := arena.to_global(shift) - arena.to_global(Vector2.ZERO)
		fighter.global_position += world_shift
		victim.global_position += world_shift
	rotation = toward.angle() + PI * 0.5
	fighter.reset_physics_interpolation()
	victim.reset_physics_interpolation()


func _update_mist() -> void:
	if not is_instance_valid(_mist):
		return
	_mist.visible = not has_bitten and fighter.is_vampire
	var radius := fighter.visual_diameter() * 0.5
	_mist.polygon = PackedVector2Array([
		Vector2(-1.45, -2.35) * radius, Vector2(1.45, -2.35) * radius,
		Vector2(1.45, -0.35) * radius, Vector2(-1.45, -0.35) * radius,
	])
	var outline_points := PackedVector2Array()
	for index in 4:
		outline_points.append_array(_tooth_shape(index, 1.0, 0.0, 6))
	_mist_material.set_shader_parameter("tooth_vertices", outline_points)
	_mist_material.set_shader_parameter("fang_radius", radius)
	_mist_material.set_shader_parameter("mist_clock", _clock)


func tooth_polygon(index: int, radius: float) -> PackedVector2Array:
	return _tooth_shape(index, radius)


func _cubic(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


func _tooth_shape(index: int, radius: float, inset: float = 0.0, steps: int = 12) -> PackedVector2Array:
	var side := -1.0 if index < 2 else 1.0
	var long_tooth := index == 0 or index == 3
	var outer_root := Vector2(0.94, -0.68) if long_tooth else Vector2(0.40, -0.74)
	var outer_a := Vector2(1.04, -1.18) if long_tooth else Vector2(0.43, -1.09)
	var outer_b := Vector2(0.90, -1.63) if long_tooth else Vector2(0.29, -1.36)
	var tip := Vector2(0.59, -1.85) if long_tooth else Vector2(0.17, -1.52)
	var inner_root := Vector2(0.45, -0.65) if long_tooth else Vector2(0.08, -0.72)
	var inner_a := Vector2(0.43, -1.07) if long_tooth else Vector2(0.07, -1.02)
	var inner_b := Vector2(0.55, -1.50) if long_tooth else Vector2(0.15, -1.29)
	var result := PackedVector2Array()
	for index_step in steps + 1:
		var t := float(index_step) / steps
		var outer := _cubic(outer_root, outer_a, outer_b, tip, t)
		var inner := _cubic(inner_root, inner_a, inner_b, tip, t)
		var point := outer.lerp(inner, inset)
		result.append(Vector2(point.x * side, point.y) * radius)
	for index_step in range(steps, -1, -1):
		var t := float(index_step) / steps
		var outer := _cubic(outer_root, outer_a, outer_b, tip, t)
		var inner := _cubic(inner_root, inner_a, inner_b, tip, t)
		var point := inner.lerp(outer, inset)
		result.append(Vector2(point.x * side, point.y) * radius)
	return result


func _tip_stain(polygon: PackedVector2Array, cut_y: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var previous := polygon[polygon.size() - 1]
	for point in polygon:
		if (point.y <= cut_y) != (previous.y <= cut_y):
			result.append(previous.lerp(point, (cut_y - previous.y) / (point.y - previous.y)))
		if point.y <= cut_y:
			result.append(point)
		previous = point
	return result


func _draw() -> void:
	if fighter == null or not fighter.is_vampire:
		return
	var radius := fighter.visual_diameter() * 0.5
	for index in 4:
		var tooth := tooth_polygon(index, radius)
		draw_colored_polygon(tooth, Color(0.77, 0.64, 0.48))
		var enamel := _tooth_shape(index, radius, 0.12)
		draw_colored_polygon(enamel, Color(0.96, 0.87, 0.72))
		var shine := _tooth_shape(index, radius, 0.29)
		draw_colored_polygon(shine, Color(1.0, 0.95, 0.84))
		if has_bitten:
			# The new reference has uneven blood stains toward the tips, without beads.
			var depth := 1.85 if index == 0 or index == 3 else 1.52
			var tip_x := 0.59 if index == 0 or index == 3 else 0.17
			var side := -1.0 if index < 2 else 1.0
			var cut_y := -radius * (depth - 0.33)
			draw_colored_polygon(_tip_stain(tooth, cut_y), Color(0.33, 0.007, 0.025))
			draw_colored_polygon(_tip_stain(enamel, cut_y), Color(0.68, 0.015, 0.055))
			for stripe in 3:
				var shift := float(stripe - 1) * 0.055
				var streak := PackedVector2Array([
					Vector2(side * (tip_x + 0.10 + shift) * radius, cut_y + radius * (0.13 + stripe * 0.035)),
					Vector2(side * (tip_x + 0.16 + shift) * radius, cut_y - radius * 0.10),
					Vector2(side * tip_x * radius, -radius * depth),
				])
				for clipped in Geometry2D.intersect_polygons(tooth, streak):
					draw_colored_polygon(clipped, Color(0.65, 0.013, 0.045))
		var outline := tooth.duplicate()
		outline.append(tooth[0])
		draw_polyline(outline, Color(0.10, 0.015, 0.02), 1.2, true)
