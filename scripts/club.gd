@tool
class_name ClubAbility
extends SwordAbility
const WEIGHTS := preload("res://scripts/combat/weight_classes.gd")
## Heavy momentum weapon. Uses the same sweep, cooldown and clash pipeline as blades.
var shield_chance: float = 0.05
var shield_duration: float = 5.0
var shield_remaining: float = 0.0
var impact_restitution: float = 0.65
var impact_recovery: float = 0.8
var launch_strength: float = 700.0
var launch_recovery: float = 0.45
var weapon_scale: float = 1.0:
	set(value):
		weapon_scale = maxf(.1,value)
		queue_redraw()

func _ready() -> void:
	fighter = get_parent() as ArenaBall
	z_index = -1
	rotation = -PI*0.5
	configure(CharacterCatalog.ability(&"club"))
	current_damage = base_damage

func is_enabled() -> bool:
	return enabled and fighter != null and fighter.character_definition != null and fighter.character_definition.tags.has("club")

func deactivate() -> void:
	shield_remaining = 0.0
	fighter.set_invulnerable(self,false)
	super.deactivate()

func reset_runtime() -> void:
	shield_remaining = 0.0
	fighter.set_invulnerable(self,false)
	super.reset_runtime()

func combat_step(delta: float) -> void:
	if shield_remaining > 0.0:
		shield_remaining = maxf(0.0,shield_remaining-delta)
		if shield_remaining == 0.0:
			fighter.set_invulnerable(self,false)
			emit_event(&"shield_finished",fighter)
	super.combat_step(delta)

func on_hit_received(_source: ArenaBall, _ability: StringName, _damage: int) -> void:
	if fighter.current_health <= 0 or shield_remaining > 0.0 or shield_chance <= 0.0:
		return
	if rng.randf() < shield_chance:
		shield_remaining = shield_duration
		fighter.set_invulnerable(self,true)
		emit_event(&"shield_started",fighter,{"duration":shield_duration})
		if is_instance_valid(fighter.combat_effects):
			fighter.combat_effects.call("spawn_notice",fighter.global_position,"ЩИТ",Color(0.55,0.94,1.0))

func _orbit_contact(victim: ArenaBall, angle: float, remaining_delta: float) -> void:
	var was_contact := _body_contact_this_step
	var hits_before := successful_hits
	super._orbit_contact(victim,angle,remaining_delta)
	# The club still has mass when its damage is recharging. Only one impulse per contact.
	if not was_contact and _body_contact_this_step and successful_hits == hits_before and is_instance_valid(victim):
		_apply_momentum(victim,angle,-spin_direction)

func apply_weapon_impact(victim: ArenaBall, _direction: Vector2) -> void:
	_apply_momentum(victim,rotation,spin_direction)

func on_weapon_clash(other: CombatAbility, position: Vector2, relative_velocity: Vector2 = Vector2.ZERO) -> void:
	# Weapon contact transmits a kick even if the enemy body itself is receding.
	var normal := (other.fighter.global_position-fighter.global_position).normalized()
	if normal.is_zero_approx(): normal = (position-fighter.global_position).normalized()
	if normal.is_zero_approx(): normal = Vector2.RIGHT
	var relative := relative_velocity
	var incidence := absf(relative.normalized().dot(normal)) if not relative.is_zero_approx() else 0.0
	var strength := definition.impact_strength*lerpf(.35,1.0,incidence)
	var fast_launch := other.fighter.weight_class <= WEIGHTS.Category.MEDIUM
	var ratio := _launch_speed_ratio(other.fighter)
	if fast_launch: strength = maxf(strength,launch_strength*maxf(1.0,other.fighter.adjusted_movement_speed()/320.0))
	_show_impact_wave(position,normal)
	var impulse := other.fighter.receive_weapon_clash_impact(normal,definition.weapon_weight_class,strength,
		launch_recovery if fast_launch else impact_recovery,ratio-1.0 if fast_launch else 0.0,ratio if fast_launch else 0.0)
	if impulse > 0:
		emit_event(&"weapon_recoil",other.fighter,{"impulse":impulse,"target_weight_class":other.fighter.weight_class})

func _launch_speed_ratio(victim: ArenaBall) -> float:
	# Light / below average / medium: strongest burst first. Heavier classes opt out.
	return [3.0,2.6,2.2][clampi(victim.weight_class,0,2)]

func _show_impact_wave(position: Vector2, direction: Vector2) -> void:
	if is_instance_valid(fighter.combat_effects):
		fighter.combat_effects.call("spawn_shockwave",position,direction,weapon_scale*.8)

func _apply_momentum(victim: ArenaBall, angle: float, angular_direction: int) -> void:
	var segment := blade_segment(angle)
	var contact := Geometry2D.get_closest_point_to_segment(victim.global_position,segment[0],segment[1])
	var normal := (victim.global_position-contact).normalized()
	if normal.is_zero_approx(): normal = (victim.global_position-fighter.global_position).normalized()
	if normal.is_zero_approx(): normal = Vector2.RIGHT
	var lever := contact-fighter.global_position
	var surface_velocity := fighter.linear_velocity+Vector2(-lever.y,lever.x)*angular_direction*effective_spin_speed()
	_show_impact_wave(victim.global_position-normal*victim.visual_diameter()*.5,normal)
	var applied := 0.0
	if victim.weight_class <= WEIGHTS.Category.MEDIUM:
		var away := (victim.global_position-fighter.global_position).normalized()
		if away.is_zero_approx(): away = normal
		var ratio := _launch_speed_ratio(victim)
		var strength := launch_strength*maxf(1.0,victim.adjusted_movement_speed()/320.0)
		applied = victim.receive_weapon_clash_impact(away,definition.weapon_weight_class,strength,launch_recovery,ratio-1.0,ratio)
	else:
		applied = victim.receive_heavy_weapon_impact(normal,surface_velocity,definition.weapon_weight_class,impact_restitution,impact_recovery,definition.impact_strength)
	if applied > 0:
		emit_event(&"weapon_impact",victim,{"weapon_weight_class":definition.weapon_weight_class,
			"target_weight_class":victim.weight_class,"effective_impulse":applied,
			"velocity":[victim.linear_velocity.x,victim.linear_velocity.y]})

func blade_segment(angle: float) -> PackedVector2Array:
	var direction := Vector2.from_angle(angle+fighter.global_rotation)
	var root := fighter.visual_diameter()*.5+13.0*fighter.diameter/70.0*weapon_scale
	# One scale controls both artwork and collision geometry, anchored at the body.
	return PackedVector2Array([fighter.global_position+direction*root,
		fighter.global_position+direction*(root+blade_length*weapon_scale)])

func intersects_target(victim: ArenaBall, angle: float) -> bool:
	var segment := blade_segment(angle)
	var point := Geometry2D.get_closest_point_to_segment(victim.global_position,segment[0],segment[1])
	return point.distance_to(victim.global_position) <= victim.visual_diameter()*.5+weapon_radius()+.025

func weapon_radius() -> float:
	return 10.0*weapon_scale

func _draw() -> void:
	if not is_enabled(): return
	var base := fighter.visual_diameter()*.5
	draw_set_transform(Vector2(base*(1.0-weapon_scale),0),0,Vector2.ONE*weapon_scale)
	var root := base+13.0*fighter.diameter/70.0
	var end := root+blade_length
	var brightness := .3 if fighter.current_health <= 0 else (.48 if fighter.is_paralyzed() else 1.0)
	var outline := Color("160e12")
	# Faceted hardwood and dark iron bands retain the body artwork's simple shading.
	var shape := PackedVector2Array([Vector2(root,-3),Vector2(root+30,-7),Vector2(end-9,-11),
		Vector2(end,-7),Vector2(end+1,5),Vector2(end-9,11),Vector2(root+30,7),Vector2(root,3)])
	draw_line(Vector2(base+3,0),Vector2(root+35,0),outline,9,true)
	draw_line(Vector2(base+3,0),Vector2(root+35,0),Color("74462d")*brightness,5,true)
	for i in 4:
		var x := base+5+i*3.0
		draw_line(Vector2(x,-3),Vector2(x+1,3),Color("b08251")*brightness,1,true)
	var edge := shape.duplicate()
	edge.append(edge[0])
	draw_colored_polygon(shape,Color("82502e")*brightness)
	draw_colored_polygon(PackedVector2Array([shape[0],shape[1],shape[2],shape[3],Vector2(end-3,-1),Vector2(root+28,-1)]),Color("c28a4e")*brightness)
	draw_colored_polygon(PackedVector2Array([Vector2(root+28,2),Vector2(end,2),shape[4],shape[5],shape[6]]),Color("573225")*brightness)
	draw_polyline(edge,outline,2.6,true)
	for x in [end-43,end-13]:
		draw_line(Vector2(x,-9),Vector2(x,9),outline,9,true)
		draw_line(Vector2(x,-8),Vector2(x,8),Color("4f5660")*brightness,5,true)
		draw_line(Vector2(x-1.5,-7),Vector2(x-1.5,0),Color("a7b1b7")*brightness,1.3,true)
	draw_set_transform(Vector2.ZERO)
	if flash_remaining > 0.0:
		draw_arc(Vector2.ZERO,base+(end-base)*weapon_scale,-.25,.05,16,Color(1,.76,.38,flash_remaining/.22*.4),2,true)

