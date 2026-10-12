@tool
class_name SwordAbility
extends Node2D
## Orbiting non-solid blade. Only applied damage advances the fighter's momentum.

signal sword_hit(victim: ArenaBall, damage: int)

@export_range(1, 100, 1) var base_damage: int = 86
@export_range(0, 20, 1) var damage_gain: int = 8
@export_range(0.1, 3.0, 0.01) var starting_speed_ratio: float = 1.0
@export_range(0.0, 100.0, 1.0) var speed_gain: float = 12.0
@export_range(0.1, 20.0, 0.1) var spin_speed: float = 3.2
@export_range(0.1, 5.0, 0.05) var hit_cooldown: float = 0.65
@export_range(10.0, 100.0, 1.0) var blade_length: float = 43.0

var fighter: ArenaBall
var current_damage: int = 86
var successful_hits: int = 0
var cooldown_remaining: float = 0.0
var flash_remaining: float = 0.0
var _base_speed: float = 0.0


func _ready() -> void:
	fighter = get_parent() as ArenaBall
	z_index = -1
	rotation = -PI * 0.5
	current_damage = base_damage


func reset_progression(base_speed: float = -1.0) -> void:
	current_damage = base_damage
	successful_hits = 0
	cooldown_remaining = 0.0
	if base_speed > 0.0:
		_base_speed = base_speed
	elif _base_speed <= 0.0:
		_base_speed = fighter.movement_speed
	fighter.movement_speed = _base_speed * starting_speed_ratio
	fighter.start_motion()


func _process(_delta: float) -> void:
	visible = fighter != null and fighter.is_swordsman and not fighter.is_vampire
	if visible:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or fighter == null or not fighter.is_swordsman or fighter.is_vampire:
		return
	flash_remaining = maxf(0.0, flash_remaining - delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if not fighter.can_attack():
		return
	var previous_angle := rotation
	rotation += spin_speed * delta
	if not is_instance_valid(fighter.opponent) or cooldown_remaining > 0.0:
		return
	# Sample the swept arc so a fast blade cannot tunnel between angular frames.
	var steps := maxi(1, ceili(absf(rotation - previous_angle) / 0.04))
	for step in range(steps + 1):
		var angle := lerpf(previous_angle, rotation, float(step) / steps)
		if intersects_target(fighter.opponent, angle) and try_hit(fighter.opponent):
			break


func blade_segment(angle: float) -> PackedVector2Array:
	var scale_ratio := fighter.diameter / 70.0
	var direction := Vector2.from_angle(angle + fighter.global_rotation)
	var start := fighter.visual_diameter() * 0.5 + 13.0 * scale_ratio
	return PackedVector2Array([fighter.global_position + direction * start,
		fighter.global_position + direction * (start + blade_length * scale_ratio)])


func intersects_target(victim: ArenaBall, angle: float) -> bool:
	var segment := blade_segment(angle)
	var closest := Geometry2D.get_closest_point_to_segment(victim.global_position, segment[0], segment[1])
	return closest.distance_to(victim.global_position) <= victim.visual_diameter() * 0.5 + 3.5 * fighter.diameter / 70.0


func try_hit(victim: ArenaBall) -> bool:
	if not fighter.is_swordsman or fighter.is_vampire or not fighter.can_attack() or cooldown_remaining > 0.0:
		return false
	if not is_instance_valid(victim) or victim == fighter or victim.current_health <= 0:
		return false
	var damage := victim.take_damage(current_damage)
	if damage <= 0:
		return false
	successful_hits += 1
	current_damage += damage_gain
	fighter.movement_speed += speed_gain
	if not fighter.linear_velocity.is_zero_approx():
		fighter.linear_velocity = fighter.linear_velocity.normalized() * fighter.movement_speed
	cooldown_remaining = hit_cooldown
	flash_remaining = 0.22
	sword_hit.emit(victim, damage)
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
