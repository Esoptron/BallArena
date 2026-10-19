extends Node2D
## Bounded, swept, arena-owned arrays. No physics bodies/timers per projectile.
const LIMIT := 96
var director: CombatDirector
var bounds := Rect2(0,0,960,600)
var shots: Array[Dictionary] = []
var zones: Array[Dictionary] = []

func launch(owner: ArenaBall, direction: Vector2, damage: int, kind: String, speed: float = 510, zone_limit: int = 1) -> void:
	if shots.size() >= LIMIT or owner.current_health <= 0: return
	shots.append({"owner":weakref(owner),"position":owner.global_position+direction*(owner.diameter*0.5+18),"velocity":direction*speed,
		"origin":owner.global_position,"kind":kind,"damage":damage,"age":0.0,"hit":{},"zones":zone_limit})

func _physics_process(delta: float) -> void:
	if director == null or director.match_over: return
	var had_visuals := not shots.is_empty() or not zones.is_empty()
	for i in range(shots.size()-1,-1,-1):
		var p := shots[i]
		var source := p["owner"].get_ref() as ArenaBall
		if not is_instance_valid(source): shots.remove_at(i); continue
		p["age"] += delta
		var previous: Vector2 = p["position"]
		var next: Vector2 = previous + p["velocity"]*delta
		if p["kind"] == "boomerang":
			var progress: float = p["age"]
			if progress > 0.65: p["velocity"] = (source.global_position-previous).normalized()*530*float(CampaignProgression.data().get("movement_factor",1.0))
			else: p["velocity"] = (p["velocity"] as Vector2).rotated(delta*0.8)
			next = previous + p["velocity"]*delta
			if progress > 0.75 and next.distance_to(source.global_position) < source.diameter*0.5+12:
				shots.remove_at(i); continue
		var struck: ArenaBall
		var closest_t := INF
		var travel := next-previous
		for target in director.opponents_of(source):
			if p["hit"].has(target.actor_id): continue
			var t := _entry(previous,travel,target.global_position,target.diameter*0.5+5)
			if t < closest_t: closest_t=t; struck=target
		var wall_t := _wall_fraction(previous,next)
		var dead := false
		if struck != null and closest_t <= wall_t:
			p["position"] = previous+travel*closest_t
			if struck.take_damage(p["damage"],source,StringName(p["kind"])) > 0:
				source.combat_event(&"projectile_hit",struck,StringName(p["kind"]),{"amount":p["damage"]})
				if is_instance_valid(source.blood_effects): source.blood_effects.call("spawn_hit_blood",p["position"])
				_status(struck,source,p)
			p["hit"][struck.actor_id]=true
			dead = p["kind"] != "boomerang"
		elif wall_t < 1.0:
			p["position"] = previous+travel*wall_t
			dead = true
		else: p["position"] = next
		var lifetime := 2.3 if p["kind"]=="boomerang" else (0.75/float(CampaignProgression.data().get("movement_factor",1.0)) if p["kind"] in ["flask","acid","fire_flask"] else 2.0)
		if float(p["age"]) >= lifetime: dead=true
		if dead:
			if p["kind"] in ["flask","acid","fire_flask"]: _zone(source,p)
			shots.remove_at(i)
	for i in range(zones.size()-1,-1,-1):
		var zone := zones[i]
		zone["remaining"] -= delta
		var source := zone["owner"].get_ref() as ArenaBall
		if not is_instance_valid(source) or zone["remaining"] <= 0: zones.remove_at(i); continue
		for target in director.opponents_of(source):
			if target.global_position.distance_squared_to(zone["position"]) < pow(target.diameter*0.5+42,2):
				(target as CampaignBall).add_campaign_effect("acid",source,zone["dps"],0.25)
	if had_visuals: queue_redraw()

static func _entry(start: Vector2, travel: Vector2, center: Vector2, radius: float) -> float:
	var relative := start-center
	var a := travel.length_squared()
	var c := relative.length_squared()-radius*radius
	if c <= 0: return 0
	if a < 0.000001: return INF
	var b := 2*relative.dot(travel)
	var discriminant := b*b-4*a*c
	if discriminant < 0: return INF
	var value := (-b-sqrt(discriminant))/(2*a)
	return value if value >= 0 and value <= 1 else INF

func _wall_fraction(start: Vector2, end: Vector2) -> float:
	var fraction := 1.0
	var delta := end-start
	for axis in 2:
		if end[axis] < bounds.position[axis] and delta[axis] < 0: fraction=minf(fraction,(bounds.position[axis]-start[axis])/delta[axis])
		if end[axis] > bounds.end[axis] and delta[axis] > 0: fraction=minf(fraction,(bounds.end[axis]-start[axis])/delta[axis])
	return clampf(fraction,0,1)

func _status(target: ArenaBall, source: ArenaBall, p: Dictionary) -> void:
	if p["kind"] == "fireball": (target as CampaignBall).add_campaign_effect("burn",source,1.0/3.0,3.0)
	if p["kind"] == "iceball": (target as CampaignBall).add_campaign_effect("ice",source,0.15,1.6)

func _zone(source: ArenaBall, p: Dictionary) -> void:
	var owned: Array[int] = []
	for i in zones.size():
		if zones[i]["owner"].get_ref() == source: owned.append(i)
	if owned.size() >= int(p["zones"]): zones.remove_at(owned[0])
	zones.append({"owner":weakref(source),"position":p["position"],"remaining":2.0,"dps":0.5 if p["kind"]=="flask" else 0.65})

func _draw() -> void:
	for zone in zones: draw_circle(zone["position"],42,Color(0.6,0.8,0.2,0.18*minf(1,zone["remaining"])))
	for p in shots:
		var point: Vector2 = p["position"]
		var direction: Vector2 = (p["velocity"] as Vector2).normalized()
		match p["kind"]:
			"crossbow":
				draw_line(point-direction*17,point,Color("ede6d5"),3,true)
				draw_colored_polygon(PackedVector2Array([point+direction*4,point-direction*3+direction.orthogonal()*4,point-direction*3-direction.orthogonal()*4]),Color("b3c4df"))
			"boomerang": draw_polyline(PackedVector2Array([point+direction*10,point+direction.orthogonal()*8,point-direction*10]),Color("d7b37a"),5,true)
			_: 
				var color := Color("80d5ff") if p["kind"]=="iceball" else (Color("ff8f39") if p["kind"] in ["fireball","fire_flask"] else Color("b4cf77"))
				draw_circle(point,6,Color("202b3d")); draw_circle(point,4.5,color); draw_circle(point+Vector2(-1,-1),1.5,Color("f7ffef"))
