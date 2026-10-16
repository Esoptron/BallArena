@tool
class_name KatanaAbility
extends SwordAbility
var critical_start_chance: float = 0.10
var critical_chance_gain: float = 0.02
var critical_max_chance: float = 1.0
var bleed_tick_damage: int = 1
var bleed_tick_interval: float = 1.0
var critical_chance: float = 0.10
var last_hit_critical: bool = false

func _ready() -> void:
	fighter = get_parent() as ArenaBall
	z_index = -1
	rotation = -PI * 0.5
	configure(CharacterCatalog.ability(&"katana"))
	current_damage = base_damage
	critical_chance = critical_start_chance

func is_enabled() -> bool:
	return enabled and fighter != null and fighter.character_definition != null and fighter.character_definition.tags.has("katana")

func reset_progression(base_speed: float = -1.0) -> void:
	super.reset_progression(base_speed)
	critical_chance = critical_start_chance
	last_hit_critical = false

func resolve_hit_damage(victim: ArenaBall) -> int:
	last_hit_critical = false
	var damage := super.resolve_hit_damage(victim)
	if damage <= 0:
		return damage
	var rolled_chance := critical_chance
	last_hit_critical = rolled_chance >= 1.0 or rng.randf() < rolled_chance
	critical_chance = minf(critical_max_chance,critical_chance + critical_chance_gain)
	if last_hit_critical:
		victim.add_bleeding(fighter,bleed_tick_damage,bleed_tick_interval,ability_id)
		victim.deepen_katana_wound()
		emit_event(&"critical_hit",victim,{"chance":rolled_chance,"stacks":victim.bleeding_stacks.size()})
		if is_instance_valid(fighter.combat_effects):
			fighter.combat_effects.call("spawn_notice",victim.global_position,"КРОВЬ",Color(1.0,0.74,0.36))
	return damage

func emit_weapon_blood(victim: ArenaBall, world_position: Vector2) -> void:
	if last_hit_critical:
		victim.emit_katana_wound_blood(3)
	else:
		super.emit_weapon_blood(victim, world_position)

func blade_segment(angle: float) -> PackedVector2Array:
	var ratio := fighter.diameter / 70.0
	var root := fighter.visual_diameter() * 0.5 + 13.0 * ratio
	var transform := Transform2D(angle + fighter.global_rotation,fighter.global_position)
	return PackedVector2Array([transform * Vector2(root,0),transform * Vector2(root + blade_length * ratio,-5.0 * ratio)])

func _draw() -> void:
	if not is_enabled():
		return
	var s := fighter.diameter / 70.0
	var base := fighter.visual_diameter() * 0.5
	var root := base + 13.0 * s
	var brightness := 0.3 if fighter.current_health <= 0 else (0.48 if fighter.is_paralyzed() else 1.0)
	var outline := Color(0.035,0.015,0.025)
	var blade := PackedVector2Array()
	var facet := PackedVector2Array()
	for index in 10:
		var t := index / 10.0
		var point := Vector2(root + blade_length * s * t,-5.0 * s * sin(t * PI * 0.5))
		blade.append(point + Vector2(0,-3.1 * s * (1.0-t*0.25)))
		facet.append(blade[-1])
	var tip := Vector2(root + blade_length*s,-5.0*s)
	blade.append(tip)
	facet.append(tip)
	for index in range(9,-1,-1):
		var t := index / 10.0
		var point := Vector2(root + blade_length * s * t,-5.0 * s * sin(t * PI * 0.5))
		blade.append(point + Vector2(0,2.3 * s * (1.0-t*0.25)))
		facet.append(point)
	var edge := blade.duplicate()
	edge.append(edge[0])
	draw_polyline(edge,outline,2.8*s,true)
	draw_colored_polygon(blade,Color(0.57,0.65,0.76)*brightness)
	draw_colored_polygon(facet,Color(0.95,0.98,1.0)*brightness)
	draw_line(Vector2(base+2*s,0),Vector2(root-1*s,0),outline,8*s,true)
	draw_line(Vector2(base+2*s,0),Vector2(root-1*s,0),Color(0.16,0.17,0.22)*brightness,5*s,true)
	for index in 5:
		var x := base + (3.0+index*1.8)*s
		draw_colored_polygon(PackedVector2Array([Vector2(x,-2*s),Vector2(x+1.3*s,0),Vector2(x,2*s),Vector2(x-1.3*s,0)]),Color(0.66,0.48,0.27)*brightness)
	draw_set_transform(Vector2(root,0),0.0,Vector2(0.55,1.0))
	draw_circle(Vector2.ZERO,8.0*s,outline)
	draw_circle(Vector2.ZERO,6.2*s,Color(0.78,0.60,0.31)*brightness)
	draw_set_transform(Vector2.ZERO)
	if flash_remaining > 0.0:
		draw_arc(Vector2.ZERO,tip.length(),-0.20,0.04,16,Color(1.0,0.86,0.55,flash_remaining/0.22*0.4),1.4*s,true)


func progression_stats() -> Array[Dictionary]:
	var stats := super.progression_stats()
	if critical_chance_gain > 0:
		stats.append({"label":"Крит", "value":critical_chance, "base":critical_start_chance, "format":"percent"})
	return stats
