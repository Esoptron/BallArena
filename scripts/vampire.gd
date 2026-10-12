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
var _bite_elapsed: float = 0.0
var _fixed_fang_diameter: float = 70.0
var _carry_velocity: Vector2 = Vector2.ZERO
var _victim_freeze_mode: int = RigidBody2D.FREEZE_MODE_STATIC


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



func _process(delta: float) -> void:
	if fighter == null:
		return
	_clock += delta
	visible = fighter.is_vampire
	if not visible:
		return
	aim_at_opponent()
	_update_mist()
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
			_bite_elapsed += delta
			_advance_carried_motion(delta)
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
	var opening_direction := fighter.linear_velocity.normalized()
	if opening_direction.is_zero_approx():
		opening_direction = fighter.get("_last_direction") as Vector2
	_carry_velocity = opening_direction * (fighter.movement_speed / 3.0)
	_victim_freeze_mode = victim.freeze_mode
	_fixed_fang_diameter = fighter.visual_diameter()
	fighter.begin_feeding(_fixed_fang_diameter)
	bite_target = victim
	ticks_remaining = bite_units
	_bite_elapsed = 0.0
	_tick_elapsed = 0.0
	cooldown_remaining = bite_duration + recovery_time
	has_bitten = true
	aim_at_opponent()
	fighter.hold_motion(self)
	fighter.set_invulnerable(self, true)
	victim.hold_motion(self)
	victim.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
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
	var mark_spacing := fang_spacing()
	ticks_remaining = 0
	bite_target = null
	_tick_elapsed = 0.0
	var away := Vector2.UP.rotated(global_rotation)
	if is_instance_valid(victim):
		away = (victim.global_position - fighter.global_position).normalized()
		if away.is_zero_approx():
			away = Vector2.RIGHT
		if completed and victim.current_health > 0:
			victim.apply_bite_marks(fighter.global_position, mark_spacing)
		victim.freeze_mode = _victim_freeze_mode
		victim.prevent_attacks(recovery_time)
		victim.release_motion(self, away)
	fighter.end_feeding()
	fighter.set_invulnerable(self, false)
	fighter.release_motion(self, -away)
	bite_finished.emit()


func _exit_tree() -> void:
	if is_instance_valid(fighter) and bite_target != null:
		_finish_bite()


func fang_diameter() -> float:
	return _fixed_fang_diameter if bite_target != null else fighter.visual_diameter()


func _advance_carried_motion(delta: float) -> void:
	var motion := _carry_velocity * delta
	for impact in 4:
		var collision := bite_target.move_and_collide(motion, false, 0.001)
		if collision == null:
			break
		var normal := collision.get_normal()
		_carry_velocity = _carry_velocity.bounce(normal)
		motion = collision.get_remainder().bounce(normal)
		if motion.is_zero_approx():
			break
	bite_target.linear_velocity = _carry_velocity


func fang_spacing() -> float:
	# The separation of the two long tooth tips, including their inward tilt.
	return fang_diameter() * (274.0 / 566.0)


func fang_tip_depth() -> float:
	return fang_diameter() * 0.5 * 1.45


func _place_for_bite(victim: ArenaBall) -> void:
	var toward := (victim.global_position - fighter.global_position).normalized()
	if toward.is_zero_approx():
		toward = Vector2.UP.rotated(global_rotation)
	var radius := fang_diameter() * 0.5
	var victim_radius := victim.visual_diameter() * 0.5
	var half_spacing := fang_spacing() * 0.5
	var exposed_length := fang_tip_depth() - sqrt(radius * radius - half_spacing * half_spacing)
	var victim_surface := sqrt(maxf(0.0, victim_radius * victim_radius - half_spacing * half_spacing))
	var separation := fang_tip_depth() + victim_surface - exposed_length * tooth_immersion
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


# Contours sampled from the approved source, used only for the animated mist.
# The character itself is rendered from its original pixels.
func _tooth_shape(index: int, _radius: float, _inset: float = 0.0, _steps: int = 6) -> PackedVector2Array:
	var outlines := [
		[Vector2(389, 696), Vector2(382, 735), Vector2(384, 775), Vector2(392, 812), Vector2(408, 851), Vector2(428, 883), Vector2(447, 903), Vector2(442, 875), Vector2(449, 829), Vector2(458, 781), Vector2(467, 735), Vector2(454, 715), Vector2(422, 701), Vector2(402, 693)],
		[Vector2(522, 750), Vector2(525, 782), Vector2(532, 812), Vector2(543, 838), Vector2(552, 850), Vector2(557, 833), Vector2(559, 804), Vector2(559, 779), Vector2(558, 760), Vector2(550, 750), Vector2(543, 749), Vector2(536, 749), Vector2(529, 750), Vector2(524, 751)],
		[Vector2(641, 756), Vector2(637, 780), Vector2(637, 807), Vector2(635, 831), Vector2(628, 857), Vector2(640, 845), Vector2(651, 825), Vector2(660, 799), Vector2(664, 774), Vector2(659, 760), Vector2(653, 755), Vector2(647, 755), Vector2(642, 756), Vector2(640, 757)],
		[Vector2(749, 751), Vector2(746, 786), Vector2(738, 826), Vector2(730, 865), Vector2(712, 923), Vector2(738, 898), Vector2(766, 866), Vector2(789, 829), Vector2(804, 789), Vector2(811, 751), Vector2(809, 726), Vector2(800, 716), Vector2(777, 732), Vector2(760, 746)],
	]
	var result := PackedVector2Array()
	for point: Vector2 in outlines[index]:
		result.append(-(point - Vector2(626, 513)) / 283.0)
	return result
