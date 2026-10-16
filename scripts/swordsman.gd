@tool
class_name SwordAbility
extends CombatAbility
## Orbiting non-solid blade; every successful hit reverses its angular direction.

signal sword_hit(victim: ArenaBall, damage: int)
var base_damage: int
var damage_gain: int
var max_damage: int
var starting_speed_ratio: float
var speed_gain: float
var max_speed: float
var spin_speed: float
var hit_cooldown: float = 1.0
var cooldown_remaining: float = 0.0
var post_hit_slow_duration: float = 3.0
var post_hit_speed_ratio: float = 1.0 / 3.0
var blade_length: float
var spin_direction: int = 1
var current_damage: int
var successful_hits: int = 0
var slow_remaining: float = 0.0
var _contact_victim: ArenaBall
var flash_remaining: float = 0.0
var _weapon_start_rotation: float = 0.0
var _weapon_end_rotation: float = 0.0
var _weapon_start_position: Vector2
var _weapon_last_position: Vector2
var _has_weapon_position: bool = false
var _clashed_this_step: bool = false
var _body_contact_this_step: bool = false
var _base_speed: float = 0.0
var berserk_chance: float = 0.0
var berserk_duration: float = 5.0
var berserk_spin_multiplier: float = 3.0
var berserk_hit_cooldown: float = 0.5
var berserk_remaining: float = 0.0
var _draw_diameter := -1.0
var _draw_length := -1.0
var _draw_status := -1
var _draw_flash := false


func _ready() -> void:
	super._ready()
	z_index = -1
	rotation = -PI*0.5
	configure(CharacterCatalog.ability(&"sword"))
	current_damage = base_damage


func is_enabled() -> bool:
	return enabled and is_instance_valid(fighter) and fighter.is_swordsman and not fighter.is_vampire


func on_match_seed() -> void:
	rotation = rng.randf_range(-PI,PI)
	spin_direction = 1 if rng.randi_range(0,1) == 0 else -1


func reset_runtime() -> void:
	reset_progression(fighter.movement_speed)


func reset_progression(base_speed: float = -1.0) -> void:
	current_damage = base_damage
	berserk_remaining = 0.0
	successful_hits = 0
	slow_remaining = 0.0
	cooldown_remaining = 0.0
	_contact_victim = null
	spin_direction = 1
	_has_weapon_position = false
	if base_speed > 0:
		_base_speed = base_speed
	elif _base_speed <= 0:
		_base_speed = fighter.movement_speed
	fighter.movement_speed = _base_speed*starting_speed_ratio
	fighter.start_motion()


func _process(_delta: float) -> void:
	visible = is_enabled()
	if visible:
		var status := 0 if fighter.current_health <= 0 else (1 if fighter.is_paralyzed() else 2)
		var diameter := fighter.visual_diameter()
		var flashing := flash_remaining > 0.0
		if diameter != _draw_diameter or blade_length != _draw_length or status != _draw_status or flashing or _draw_flash:
			_draw_diameter = diameter
			_draw_length = blade_length
			_draw_status = status
			_draw_flash = flashing
			queue_redraw()


func combat_step(delta: float) -> void:
	berserk_remaining = maxf(0.0, berserk_remaining - delta)
	_clashed_this_step = false
	_body_contact_this_step = false
	_weapon_start_rotation = rotation
	_weapon_end_rotation = rotation
	_weapon_start_position = _weapon_last_position if _has_weapon_position else fighter.global_position
	_weapon_last_position = fighter.global_position
	_has_weapon_position = true
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	flash_remaining = maxf(0.0,flash_remaining-delta)
	slow_remaining = maxf(0.0,slow_remaining-delta)
	if not fighter.can_attack():
		return
	var previous := rotation
	var angular_speed := effective_spin_speed()
	rotation += spin_direction*angular_speed*delta
	_weapon_end_rotation = rotation
	if not is_instance_valid(fighter.opponent):
		return
	var victims := hostile_targets()
	# A continuous overlap is one strike; rearm only once the blade leaves the target.
	if is_instance_valid(_contact_victim):
		if intersects_target(_contact_victim, previous):
			if not intersects_target(_contact_victim, rotation):
				_contact_victim = null
			return
		_contact_victim = null
	var nearby: Array[Dictionary] = []
	var center := fighter.global_position
	var radius := 0.0
	for segment in body_segments(rotation):
		for point in segment: radius = maxf(radius, point.distance_to(center))
	for victim in victims:
		var target_radius := victim.visual_diameter()*0.5 + weapon_radius() + 0.025
		var point := victim.global_position
		if center.distance_squared_to(point) <= pow(radius + target_radius, 2):
			nearby.append({"fighter":victim,"position":point,"radius":target_radius})
	if nearby.is_empty(): return
	var travel := absf(rotation-previous)*radius
	var fraction := 0.0
	for iteration in 96:
		var angle := lerpf(previous,rotation,fraction)
		var segments := body_segments(angle)
		var gap := INF
		for target in nearby:
			for segment in segments:
				var closest := Geometry2D.get_closest_point_to_segment(target["position"],segment[0],segment[1])
				var distance := closest.distance_to(target["position"]) - float(target["radius"])
				if distance <= 0.00001:
					queue_contact(_orbit_contact.bind(target["fighter"],angle,delta*(1.0-fraction)),fraction)
					return
				gap = minf(gap,distance)
		if travel < 0.00001 or fraction >= 1.0: return
		fraction += maxf(0.000001,gap/travel*0.95)
		if fraction > 1.0: return

func body_segments(angle: float) -> Array[PackedVector2Array]:
	return [blade_segment(angle)]



func _orbit_contact(victim: ArenaBall, angle: float, remaining_delta: float) -> void:
	if _clashed_this_step or _body_contact_this_step or not is_enabled() or not fighter.can_attack():
		return
	if not is_instance_valid(victim) or victim.current_health <= 0 or _contact_victim == victim or not intersects_target(victim,angle):
		return
	rotation = angle
	var damaged := try_hit(victim)
	if not damaged:
		# Physical contact reverses even when damage is on cooldown or blocked.
		spin_direction = -spin_direction
		_contact_victim = victim
	_body_contact_this_step = true
	var angular_speed := effective_spin_speed()
	rotation = angle + spin_direction * angular_speed * remaining_delta
	_weapon_end_rotation = rotation
	emit_event(&"weapon_body_contact",victim,{"damaged":damaged,"spin_direction":spin_direction})
	queue_redraw()


func blade_segment(angle: float) -> PackedVector2Array:
	var ratio := fighter.diameter/70.0
	var direction := Vector2.from_angle(angle+fighter.global_rotation)
	var start := fighter.visual_diameter()*0.5+13.0*ratio
	return PackedVector2Array([fighter.global_position+direction*start,
		fighter.global_position+direction*(start+blade_length*ratio)])


func hit_segment_for(_victim: ArenaBall) -> PackedVector2Array:
	return blade_segment(rotation)


func intersects_target(victim: ArenaBall, angle: float) -> bool:
	var segment := blade_segment(angle)
	var closest := Geometry2D.get_closest_point_to_segment(victim.global_position,segment[0],segment[1])
	return closest.distance_to(victim.global_position) <= victim.visual_diameter()*0.5+3.5*fighter.diameter/70.0+0.025


func try_hit(victim: ArenaBall) -> bool:
	if not is_enabled() or not fighter.can_attack() or _contact_victim == victim or cooldown_remaining > 0.0:
		return false
	if not is_instance_valid(victim) or victim == fighter or victim.current_health <= 0:
		return false
	if director != null and not director.are_enemies(fighter,victim): return false
	emit_event(&"cast_started",victim,{"tags":["weapon"]})
	var damage := resolve_hit_damage(victim)
	if damage <= 0:
		emit_event(&"cast_finished",victim,{"completed":true,"successful":false})
		return false
	var hit_segment := hit_segment_for(victim)
	var wound := Geometry2D.get_closest_point_to_segment(victim.global_position, hit_segment[0], hit_segment[1])
	emit_weapon_blood(victim, wound)
	var blade_direction := (hit_segment[1] - hit_segment[0]).normalized()
	var impact_direction := (blade_direction.orthogonal() * spin_direction + (victim.global_position - fighter.global_position).normalized() * 0.45).normalized()
	apply_weapon_impact(victim, impact_direction)
	successful_hits += 1
	current_damage = mini(max_damage,current_damage+damage_gain) if max_damage > 0 else current_damage+damage_gain
	on_successful_hit()
	fighter.movement_speed = minf(max_speed*fighter.movement_scale,fighter.movement_speed+speed_gain*fighter.movement_scale)
	if not fighter.linear_velocity.is_zero_approx():
		fighter.linear_velocity = fighter.linear_velocity.normalized()*fighter.effective_movement_speed()
	cooldown_remaining = effective_hit_cooldown()
	if is_instance_valid(fighter.combat_effects):
		var slash_direction := blade_direction.orthogonal() * spin_direction
		fighter.combat_effects.call("spawn_slash", wound, slash_direction, fighter.diameter / 70.0)
	slow_remaining = post_hit_slow_duration
	_contact_victim = victim
	flash_remaining = 0.22
	spin_direction = -spin_direction
	emit_event(&"hit",victim,{"amount":damage,"spin_direction":spin_direction})
	emit_event(&"cast_finished",victim,{"completed":true,"successful":true})
	sword_hit.emit(victim,damage)
	queue_redraw()
	return true


func _draw() -> void:
	if fighter == null or not fighter.is_swordsman or fighter.is_vampire:
		return
	var s := fighter.diameter / 70.0
	var base := fighter.visual_diameter() * 0.5
	# Local +X points outward: pommel, wrapped grip, guard, then faceted blade.
	var outline := Color(0.035, 0.015, 0.025)
	var brightness := 0.3 if fighter.current_health <= 0 else (0.48 if fighter.is_paralyzed() else 1.0)
	var blade := PackedVector2Array([Vector2(base + 13*s, -4*s),
		Vector2(base + (13 + blade_length - 11)*s, -4*s),
		Vector2(base + (13 + blade_length)*s, 0),
		Vector2(base + (13 + blade_length - 11)*s, 4*s), Vector2(base + 13*s, 4*s)])
	var edge := blade.duplicate()
	edge.append(edge[0])
	draw_line(Vector2(base+3*s, 0), Vector2(base+13*s, 0), outline, 8*s, true)
	draw_line(Vector2(base+3*s, 0), Vector2(base+13*s, 0), Color(0.18,0.23,0.34)*brightness, 5*s, true)
	for i in 3:
		draw_line(Vector2(base+(5+i*2.5)*s,-2*s), Vector2(base+(6+i*2.5)*s,2*s),
			Color(0.38,0.44,0.56)*brightness, 0.7*s, true)
	draw_circle(Vector2(base+2*s,0), 3.4*s, outline)
	draw_circle(Vector2(base+2*s,0), 2.2*s, Color(0.5,0.57,0.7)*brightness)
	draw_polyline(edge, outline, 3*s, true)
	draw_colored_polygon(blade, Color(0.72,0.76,0.85)*brightness)
	draw_colored_polygon(PackedVector2Array([blade[0],blade[1],blade[2],
		Vector2(base+13*s,0)]), Color(0.95,0.96,1.0)*brightness)
	draw_line(Vector2(base+13*s,-10*s), Vector2(base+13*s,10*s), outline, 6*s, true)
	draw_line(Vector2(base+13*s,-9*s), Vector2(base+13*s,9*s), Color(0.51,0.59,0.72)*brightness, 3.5*s, true)
	draw_line(Vector2(base+12*s,-8*s), Vector2(base+12*s,8*s), Color(0.82,0.86,0.93)*brightness, 0.8*s, true)
	if flash_remaining > 0.0:
		var alpha := flash_remaining / 0.22
		draw_arc(Vector2.ZERO, base+(13+blade_length)*s, -0.35, 0.04, 16,
			Color(0.75,0.90,1.0,alpha*0.4), 2.0*s, true)


func weapon_sweep_motion() -> Dictionary:
	return {"start_position": _weapon_start_position, "angle": absf(_weapon_end_rotation - _weapon_start_rotation)}


func weapon_segments_at(fraction: float) -> Array[PackedVector2Array]:
	var segment := blade_segment(lerpf(_weapon_start_rotation, _weapon_end_rotation, fraction))
	var offset := _weapon_start_position.lerp(fighter.global_position, fraction) - fighter.global_position
	return [PackedVector2Array([segment[0] + offset, segment[1] + offset])]

func weapon_point_velocity(position: Vector2) -> Vector2:
	var lever := position-fighter.global_position
	return fighter.linear_velocity+Vector2(-lever.y,lever.x)*spin_direction*effective_spin_speed()

func weapon_radius() -> float:
	return 3.5 * fighter.diameter / 70.0

func deflect_weapon(fraction: float) -> void:
	var impact_angle := lerpf(_weapon_start_rotation, _weapon_end_rotation, fraction)
	spin_direction = -spin_direction
	rotation = impact_angle - (_weapon_end_rotation - _weapon_start_rotation) * (1.0 - fraction)
	_weapon_end_rotation = rotation
	_clashed_this_step = true
	queue_redraw()


func can_resolve_clash() -> bool:
	# A previously queued clash on the old path is invalid after a body reflection.
	return can_clash() and not _body_contact_this_step and not _clashed_this_step


func effective_spin_speed() -> float:
	if berserk_remaining > 0.0:
		return spin_speed * berserk_spin_multiplier
	return spin_speed * (post_hit_speed_ratio if slow_remaining > 0.0 else 1.0)

func cooldown_time_left() -> float:
	return cooldown_remaining

func cooldown_full_duration() -> float:
	return effective_hit_cooldown()

func effective_hit_cooldown() -> float:
	return berserk_hit_cooldown if berserk_remaining > 0.0 else hit_cooldown

func activate_berserk() -> void:
	berserk_remaining = berserk_duration
	emit_event(&"berserk_started", fighter, {"duration":berserk_duration})
	if is_instance_valid(fighter.combat_effects):
		fighter.combat_effects.call("spawn_berserk", fighter.global_position)

func on_successful_hit() -> void:
	if berserk_chance > 0.0 and rng.randf() < berserk_chance:
		activate_berserk()

func on_relocated() -> void:
	_weapon_start_position = fighter.global_position
	_weapon_last_position = fighter.global_position
	_weapon_start_rotation = rotation
	_weapon_end_rotation = rotation
	_has_weapon_position = true
	_contact_victim = null
	# Discard queued contacts on the path from before the relocation.
	_clashed_this_step = true


func current_weapon_segments() -> Array[PackedVector2Array]:
	return [blade_segment(rotation)]


func resolve_hit_damage(victim: ArenaBall) -> int:
	return victim.take_damage(current_damage,fighter,ability_id)


func progression_stats() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	if damage_gain > 0:
		stats.append({"label":"Урон", "value":current_damage, "base":base_damage, "format":"number"})
	if speed_gain > 0:
		stats.append({"label":"Скорость", "value":fighter.movement_speed,
			"base":_base_speed * starting_speed_ratio, "format":"speed"})
	return stats
