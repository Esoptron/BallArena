@tool
class_name DaggerAbility
extends SwordAbility
## Two opposite daggers share one orbit, cooldown and damage progression.
var spin_gain: float = 4.0
var max_spin_speed: float = 32.0
var _initial_spin_speed: float = 8.0
var capture_counter_chance: float = 0.035
var capture_counter_hp_fraction: float = 0.20
var capture_counter_gap: float = 8.0

func _ready() -> void:
	fighter = get_parent() as ArenaBall
	z_index = -1
	rotation = -PI * 0.5
	configure(CharacterCatalog.ability(&"daggers"))
	current_damage = base_damage

func configure(settings: AbilityDefinition) -> void:
	super.configure(settings)
	_initial_spin_speed = spin_speed

func is_enabled() -> bool:
	return enabled and fighter != null and fighter.character_definition != null and fighter.character_definition.tags.has("knifeman")

func reset_progression(base_speed: float = -1.0) -> void:
	super.reset_progression(base_speed)
	spin_speed = _initial_spin_speed

func on_successful_hit() -> void:
	spin_speed = minf(max_spin_speed,spin_speed + spin_gain)

func _dagger_segment(angle: float) -> PackedVector2Array:
	var ratio := fighter.diameter / 70.0
	var direction := Vector2.from_angle(angle + fighter.global_rotation)
	var root := fighter.visual_diameter() * 0.5 + 8.0 * ratio
	return PackedVector2Array([fighter.global_position + direction * root,
		fighter.global_position + direction * (root + blade_length * ratio)])

func blade_segment(angle: float) -> PackedVector2Array:
	var first := _dagger_segment(angle)
	var second := _dagger_segment(angle + PI)
	if is_instance_valid(fighter.opponent):
		var victim := fighter.opponent.global_position
		var first_distance := Geometry2D.get_closest_point_to_segment(victim,first[0],first[1]).distance_squared_to(victim)
		var second_distance := Geometry2D.get_closest_point_to_segment(victim,second[0],second[1]).distance_squared_to(victim)
		return first if first_distance <= second_distance else second
	return first

func body_segments(angle: float) -> Array[PackedVector2Array]:
	return [_dagger_segment(angle),_dagger_segment(angle+PI)]

func intersects_target(victim: ArenaBall, angle: float) -> bool:
	for offset in [0.0,PI]:
		var segment := _dagger_segment(angle + offset)
		var closest := Geometry2D.get_closest_point_to_segment(victim.global_position,segment[0],segment[1])
		if closest.distance_to(victim.global_position) <= victim.visual_diameter() * 0.5 + weapon_radius() + 0.025:
			return true
	return false

func weapon_segments_at(fraction: float) -> Array[PackedVector2Array]:
	var angle := lerpf(_weapon_start_rotation,_weapon_end_rotation,fraction)
	var offset := _weapon_start_position.lerp(fighter.global_position,fraction) - fighter.global_position
	var segments: Array[PackedVector2Array] = []
	for phase in [0.0,PI]:
		var segment := _dagger_segment(angle + phase)
		segments.append(PackedVector2Array([segment[0] + offset,segment[1] + offset]))
	return segments

func current_weapon_segments() -> Array[PackedVector2Array]:
	return [_dagger_segment(rotation),_dagger_segment(rotation + PI)]

func weapon_radius() -> float:
	return 3.8 * fighter.diameter / 70.0

func _draw() -> void:
	if not is_enabled():
		return
	var ratio := fighter.diameter / 70.0
	var base := fighter.visual_diameter() * 0.5
	var brightness := 0.3 if fighter.current_health <= 0 else (0.48 if fighter.is_paralyzed() else 1.0)
	for phase in [0.0,PI]:
		draw_set_transform(Vector2.ZERO,phase)
		var outline := Color(0.035,0.015,0.025)
		var root := base + 8.0 * ratio
		var tip := root + blade_length * ratio
		var blade := PackedVector2Array([Vector2(root,-4.5*ratio),Vector2(tip-12*ratio,-3.6*ratio),
			Vector2(tip,0),Vector2(tip-12*ratio,3.6*ratio),Vector2(root,4.5*ratio)])
		var edge := blade.duplicate()
		edge.append(edge[0])
		draw_line(Vector2(base+1*ratio,0),Vector2(root,0),outline,8*ratio,true)
		draw_line(Vector2(base+1*ratio,0),Vector2(root,0),Color(0.24,0.18,0.14)*brightness,4.5*ratio,true)
		for index in 3:
			var x := base + (2.0+index*1.8)*ratio
			draw_line(Vector2(x,-1.8*ratio),Vector2(x+ratio,1.8*ratio),Color(0.63,0.47,0.29)*brightness,0.65*ratio,true)
		draw_polyline(edge,outline,2.8*ratio,true)
		draw_colored_polygon(blade,Color(0.54,0.62,0.72)*brightness)
		draw_colored_polygon(PackedVector2Array([blade[0],blade[1],blade[2],Vector2(root,0)]),Color(0.96,0.98,1.0)*brightness)
		draw_line(Vector2(root,-7*ratio),Vector2(root,7*ratio),outline,4.0*ratio,true)
		draw_line(Vector2(root,-6*ratio),Vector2(root,6*ratio),Color(0.78,0.64,0.37)*brightness,2.0*ratio,true)
		if flash_remaining > 0.0:
			draw_arc(Vector2.ZERO,tip,-0.25,0.04,12,Color(0.93,0.96,1.0,flash_remaining/0.22*0.4),1.2*ratio,true)
	draw_set_transform(Vector2.ZERO)


func progression_stats() -> Array[Dictionary]:
	var stats := super.progression_stats()
	if spin_gain > 0:
		stats.append({"label":"Вращение", "value":spin_speed, "base":_initial_spin_speed, "format":"rotation"})
	return stats


func on_capture_damage(source: CombatAbility, damage: int) -> bool:
	if damage <= 0 or fighter.current_health <= 0 or not source is VampireFangs or capture_counter_chance <= 0.0:
		return false
	var bite := source as VampireFangs
	if bite.bite_target != fighter or bite.fighter.current_health <= 0:
		return false
	if rng.randf() >= capture_counter_chance:
		return false
	var vampire := bite.fighter
	var origin := fighter.global_position
	var front := (origin-vampire.global_position).normalized()
	if front.is_zero_approx():
		front = Vector2.UP.rotated(bite.global_rotation)
	var health_before := vampire.current_health
	# Relocate while both bodies are held, before release wakes physics.
	_place_behind(vampire,front)
	if not bite.interrupt_bite(fighter):
		return false
	fighter._last_direction = -front
	vampire._last_direction = front
	fighter.linear_velocity = -front*fighter.effective_movement_speed()
	vampire.linear_velocity = front*vampire.effective_movement_speed()
	fighter.protect_relocation()
	vampire.protect_relocation()
	var amount := maxi(1,ceili(health_before*capture_counter_hp_fraction))
	emit_event(&"cast_started",vampire,{"tags":["weapon","counter"]})
	var applied := vampire.take_damage(amount,fighter,ability_id)
	if applied > 0:
		successful_hits += 1
		current_damage = mini(max_damage,current_damage+damage_gain) if max_damage > 0 else current_damage+damage_gain
		on_successful_hit()
		cooldown_remaining = hit_cooldown
		spin_direction = -spin_direction
		_contact_victim = null
		flash_remaining = 0.22
		emit_event(&"hit",vampire,{"amount":applied,"counter":true})
	emit_event(&"cast_finished",vampire,{"completed":true,"successful":applied > 0,"counter":true})
	emit_event(&"capture_counter",vampire,{"amount":applied,"target_health_before":health_before})
	if is_instance_valid(fighter.combat_effects):
		fighter.combat_effects.call("spawn_counter_slash",vampire.global_position,front,
			maxf(180.0,origin.distance_to(fighter.global_position)+90.0))
	if is_instance_valid(fighter.blood_effects):
		fighter.blood_effects.call("spawn_hit_blood",vampire.global_position)
	queue_redraw()
	return true

func _place_behind(vampire: ArenaBall, front: Vector2) -> void:
	var separation := (fighter.diameter+vampire.diameter)*0.5+capture_counter_gap
	fighter.global_position = vampire.global_position-front*separation
	var arena := fighter.get_parent().get_parent() as BallArena
	if arena == null:
		return
	var radius := fighter.diameter*0.5
	var other_radius := vampire.diameter*0.5
	var bounds := Rect2(arena.to_local(fighter.global_position)-Vector2.ONE*radius,Vector2.ONE*fighter.diameter)
	bounds = bounds.merge(Rect2(arena.to_local(vampire.global_position)-Vector2.ONE*other_radius,Vector2.ONE*vampire.diameter))
	# Leave room for the first physics steps to register the new wall contacts.
	var margin := maxf(2.0,maxf(fighter.effective_movement_speed(),vampire.effective_movement_speed())*2.0/Engine.physics_ticks_per_second)
	var shift := Vector2(clampf(0.0,margin-bounds.position.x,arena.arena_size.x-margin-bounds.end.x),
		clampf(0.0,margin-bounds.position.y,arena.arena_size.y-margin-bounds.end.y))
	var world_shift := arena.to_global(shift)-arena.to_global(Vector2.ZERO)
	fighter.global_position += world_shift
	vampire.global_position += world_shift


func hit_segment_for(victim: ArenaBall) -> PackedVector2Array:
	var first := _dagger_segment(rotation)
	var second := _dagger_segment(rotation+PI)
	return first if Geometry2D.get_closest_point_to_segment(victim.global_position,first[0],first[1]).distance_squared_to(victim.global_position) <= Geometry2D.get_closest_point_to_segment(victim.global_position,second[0],second[1]).distance_squared_to(victim.global_position) else second
