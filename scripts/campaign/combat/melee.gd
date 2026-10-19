extends SwordAbility
## Reuses the director's continuous angular sweep and single-contact rearming.
var weapon_kind: String = "rapier"
var boss_kind: String = ""
var _clock := 0.0
var _spring := 0.0
var _spring_velocity := 0.0
var _hook_cd := 0.0
var _pull_left := 0.0
var _hook_target: WeakRef
var _shaft_contacts: Dictionary = {}

func _ready() -> void:
	# SwordAbility's free-profile configure must not replace campaign parameters.
	fighter = get_parent() as ArenaBall
	z_index = -1
	rotation = -PI * 0.5

func is_enabled() -> bool:
	return enabled and is_instance_valid(fighter)

func reset_runtime() -> void:
	starting_speed_ratio = 1.0
	max_speed = fighter.movement_speed
	speed_gain = 0
	damage_gain = 0
	max_damage = 0
	post_hit_slow_duration = 0.25 if weapon_kind == "axe" else 0.0
	post_hit_speed_ratio = 0.6
	super.reset_runtime()

func effective_spin_speed() -> float:
	var phase := 1.0
	if not boss_kind.is_empty() and fighter.current_health < fighter.max_health * (0.4 if boss_kind == "chain" else 0.5):
		phase = 1.2 if boss_kind == "chain" else 1.15
	if boss_kind=="guard" and fmod(_clock,5.0)>4.3: phase*=0.72
	return super.effective_spin_speed() * (fighter as CampaignBall).rotation_multiplier * phase

func combat_step(delta: float) -> void:
	_clock += delta
	_hook_cd = maxf(0.0, _hook_cd - delta)
	if weapon_kind == "flail":
		_spring_velocity += (-_spring * 34.0 - _spring_velocity * 7.0) * delta
		_spring = clampf(_spring + _spring_velocity * delta, -0.42, 0.42)
	if weapon_kind == "shield" or boss_kind == "guard":
		var direction := Vector2.from_angle(rotation+fighter.global_rotation)*(-1 if boss_kind=="guard" else 1)
		(fighter as CampaignBall).shield_sector = {"facing": direction, "reduction": 0.55 if boss_kind=="guard" and fmod(_clock,5.0)>4.3 else 0.35}
	if _pull_left > 0 and _hook_target != null:
		_pull_left -= delta
		var target := _hook_target.get_ref() as ArenaBall
		if is_instance_valid(target) and target.can_attack() and fighter.can_attack():
			target.receive_weapon_impact((fighter.global_position-target.global_position).normalized(), 2, 70 * delta)
	if fighter.can_attack() and weapon_kind == "rapier" and _hook_cd <= 0 and is_instance_valid(fighter.opponent):
		if fighter.global_position.distance_to(fighter.opponent.global_position) < 160:
			fighter.receive_weapon_impact((fighter.opponent.global_position-fighter.global_position).normalized(), 0, 70)
			_hook_cd = 4.0
	super.combat_step(delta)
	if weapon_kind in ["spear","harpoon"] and fighter.can_attack():
		var current := {}
		var shaft := _shaft(rotation)
		for target in hostile_targets():
			var closest := Geometry2D.get_closest_point_to_segment(target.global_position,shaft[0],shaft[1])
			if closest.distance_to(target.global_position)<=target.diameter*0.5+3 and not intersects_target(target,rotation):
				current[target.actor_id]=true
				if not _shaft_contacts.has(target.actor_id): target.receive_weapon_impact((target.global_position-closest).normalized(),1,25)
		_shaft_contacts=current
	if weapon_kind in ["flail", "harpoon"] or not boss_kind.is_empty(): queue_redraw()

func _reach() -> float:
	var multiplier := 1.0
	if boss_kind == "chain":
		if fighter.current_health < fighter.max_health * 0.4: multiplier += 0.1
		if fmod(_clock, 6.0) > 5.2: multiplier += 0.08
	return blade_length * multiplier

func _shaft(angle: float) -> PackedVector2Array:
	var forward := Vector2.from_angle(angle + fighter.global_rotation + _spring)
	var base := fighter.visual_diameter() * 0.5 + 8.0
	return PackedVector2Array([fighter.global_position + forward * base, fighter.global_position + forward * (base + _reach())])

func blade_segment(angle: float) -> PackedVector2Array:
	return _shaft(angle)

func body_segments(angle: float) -> Array[PackedVector2Array]:
	var s := _shaft(angle)
	var side := (s[1]-s[0]).normalized().orthogonal()
	match weapon_kind:
		"spear", "harpoon": return [PackedVector2Array([s[1].lerp(s[0], minf(0.25, 14.0/_reach())), s[1]])]
		"flail", "chakram": return [PackedVector2Array([s[1]-side*7, s[1]+side*7])]
		"axe", "hammer": return [PackedVector2Array([s[1]-side*10, s[1]+side*10])]
		"trident": return [PackedVector2Array([s[1]-side*9, s[1]-side*9-(s[1]-s[0]).normalized()*13]),
			PackedVector2Array([s[1],s[1]-(s[1]-s[0]).normalized()*17]), PackedVector2Array([s[1]+side*9,s[1]+side*9-(s[1]-s[0]).normalized()*13])]
	return [s]

func intersects_target(victim: ArenaBall, angle: float) -> bool:
	for s in body_segments(angle):
		if victim.global_position.distance_to(Geometry2D.get_closest_point_to_segment(victim.global_position,s[0],s[1])) <= victim.visual_diameter()*0.5 + weapon_radius() + 0.025:
			return true
	return false

func weapon_segments_at(fraction: float) -> Array[PackedVector2Array]:
	var angle := lerpf(_weapon_start_rotation, _weapon_end_rotation, fraction)
	var offset := _weapon_start_position.lerp(fighter.global_position, fraction)-fighter.global_position
	var shaft := _shaft(angle)
	var segments: Array[PackedVector2Array] = [shaft]
	if weapon_kind in ["axe","hammer","chakram","trident"]: segments.append_array(body_segments(angle))
	if weapon_kind == "shield" or boss_kind == "guard":
		var direction := Vector2.from_angle(angle+fighter.global_rotation)*(-1 if boss_kind=="guard" else 1)
		var center := fighter.global_position + direction * (fighter.diameter*0.5+5)
		segments.append(PackedVector2Array([center-direction.orthogonal()*17,center+direction.orthogonal()*17]))
	for i in segments.size(): segments[i] = PackedVector2Array([segments[i][0]+offset,segments[i][1]+offset])
	return segments

func weapon_sweep_motion() -> Dictionary:
	var result := super.weapon_sweep_motion()
	result["angle"] += absf(_spring_velocity) / Engine.physics_ticks_per_second
	return result

func weapon_radius() -> float:
	return 6.0 if weapon_kind in ["flail", "chakram", "hammer"] else 3.0

func on_weapon_clash(other: CombatAbility, point: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	if weapon_kind == "flail": _spring_velocity = clampf(velocity.length()*0.01*spin_direction, -4.0, 4.0)
	super.on_weapon_clash(other, point, velocity)

func try_hit(victim: ArenaBall) -> bool:
	var success := super.try_hit(victim)
	if not success: return false
	var target := victim as CampaignBall
	match weapon_kind:
		"hammer":
			target.add_campaign_effect("slow",fighter,0.1,0.8)
			if is_instance_valid(fighter.combat_effects): fighter.combat_effects.call("spawn_shockwave",victim.global_position,Vector2.RIGHT,0.6)
			var audio := fighter.get_parent().get_parent().get_node_or_null("CampaignAudio")
			if audio!=null: audio.call("thud")
		"sickle":
			if rng.randf() < 0.15: target.add_campaign_effect("cut",fighter,0.2,4.0,2)
		"harpoon":
			if _hook_cd <= 0:
				_hook_target = weakref(target)
				_pull_left = 0.6
				_hook_cd = 7.0
	return true

func resolve_hit_damage(victim: ArenaBall) -> int:
	return victim.take_damage(current_damage,fighter,ability_id)

func current_weapon_segments() -> Array[PackedVector2Array]:
	return weapon_segments_at(1.0)

func _draw() -> void:
	if not is_enabled(): return
	var base := fighter.visual_diameter()*0.5+8
	var tip := Vector2(base+_reach(),0).rotated(_spring)
	var root := Vector2(base,0).rotated(_spring)
	var dark := Color("121723")
	var steel := Color("dce7ef")
	var gold := Color("b89765")
	if weapon_kind == "chakram":
		draw_circle(tip,12,dark)
		draw_arc(tip,10,0,TAU,32,steel,4,true)
		draw_arc(tip,7,0,TAU,24,gold,1,true)
		return
	draw_line(root,tip,dark,7,true)
	draw_line(root,tip,gold if weapon_kind in ["spear","harpoon","trident","hammer","axe"] else steel,3,true)
	match weapon_kind:
		"flail":
			for i in 6:
				draw_circle(root.lerp(tip,(i+0.5)/6.0),2,Color("8193ab"),false,1,true)
			draw_circle(tip,9,dark)
			draw_circle(tip,7,Color("738299"))
			for i in 6: draw_line(tip+Vector2.from_angle(i*TAU/6)*6,tip+Vector2.from_angle(i*TAU/6)*12,steel,3,true)
		"axe", "hammer":
			var points := PackedVector2Array([tip+Vector2(-9,-13),tip+Vector2(7,-10),tip+Vector2(10,10),tip+Vector2(-9,13)])
			if weapon_kind == "hammer": points = PackedVector2Array([tip+Vector2(-8,-12),tip+Vector2(8,-12),tip+Vector2(8,12),tip+Vector2(-8,12)])
			draw_colored_polygon(points,Color("a4afc4"))
			points.append(points[0]); draw_polyline(points,dark,2,true)
			draw_line(tip+Vector2(-5,-10),tip+Vector2(6,-8),steel,2,true)
		"sickle": draw_arc(tip-Vector2(7,0),12,-PI*0.6,PI*0.7,20,steel,5,true)
		"shield":
			draw_rect(Rect2(root.x-6,-18,9,36),dark)
			draw_rect(Rect2(root.x-5,-16,7,32),Color("6f89ab"))
		_: 
			var blade := PackedVector2Array([tip+Vector2(-15,-4),tip,tip+Vector2(-15,4)])
			draw_colored_polygon(blade,steel)
			if weapon_kind == "trident":
				for y in [-9,9]: draw_line(tip+Vector2(-14,y),tip+Vector2(0,y),steel,3,true)
			if weapon_kind == "harpoon": draw_line(tip,tip+Vector2(-7,8),steel,3,true)
	if _pull_left > 0 and _hook_target != null:
		var target := _hook_target.get_ref() as ArenaBall
		if is_instance_valid(target): draw_line(Vector2.ZERO,to_local(target.global_position),Color(0.6,0.75,0.8,0.5),1,true)
	if boss_kind == "guard":
		var phase := fmod(_clock,5)
		var alpha := 0.8 if phase>4.3 else (0.35+0.25*sin(_clock*24) if phase>3.9 else 0.35)
		draw_arc(Vector2.ZERO,fighter.diameter*0.5+6,PI-0.9,PI+0.9,24,Color(0.7,0.85,1,alpha),5,true)
