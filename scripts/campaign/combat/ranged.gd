extends CombatAbility
## Telegraph locks the firing direction; projectiles live in the arena, not the owner.
var weapon_kind: String = "crossbow"
var boss_kind: String = ""
var base_damage: int = 1000
var hit_cooldown: float = 3.0
var blade_length: float = 40.0
var spin_speed: float = 0.0
var cooldown_remaining := 0.5
var windup := 0.0
var aim := Vector2.RIGHT
var shots := 0
var _pulse_left := 0.0
var _summoned := false

func _ready() -> void:
	super._ready()
	z_index = -1

func reset_runtime() -> void:
	cooldown_remaining = 0.6
	windup = 0.0
	shots = 0
	_summoned = false

func is_enabled() -> bool:
	return enabled and is_instance_valid(fighter)

func cooldown_time_left() -> float: return cooldown_remaining
func cooldown_full_duration() -> float: return hit_cooldown

func on_hit_received(_source: ArenaBall, _ability: StringName, _amount: int) -> void:
	if boss_kind == "archon" and not _summoned and fighter.current_health > 0 and fighter.current_health < fighter.max_health*0.5:
		_summoned = true
		var arena := fighter.get_parent().get_parent()
		if arena.has_method("summon_drone"): arena.call("summon_drone",fighter)

func combat_step(delta: float) -> void:
	if not fighter.can_attack(): return
	var field := _field()
	if field == null: return
	if _pulse_left > 0:
		_pulse_left = maxf(0,_pulse_left-delta)
		for target in hostile_targets():
			var distance := target.global_position.distance_to(fighter.global_position)
			if distance < 360 and target.can_attack():
				target.receive_weapon_impact((fighter.global_position-target.global_position).normalized(),4,190*delta)
		if _pulse_left == 0 and boss_kind == "archon":
			for target in hostile_targets(): target.receive_weapon_impact((target.global_position-fighter.global_position).normalized(),4,170)
	cooldown_remaining = maxf(0,cooldown_remaining-delta)
	if windup > 0:
		windup -= delta
		if windup <= 0:
			_fire(field)
			shots += 1
			cooldown_remaining = hit_cooldown
			if not boss_kind.is_empty() and fighter.current_health < fighter.max_health*0.4: cooldown_remaining *= 0.85
	elif cooldown_remaining <= 0 and is_instance_valid(fighter.opponent):
		aim = _lead_direction(fighter.opponent)
		windup = 0.8 if weapon_kind == "magnet" else 0.28
		emit_event(&"telegraph",fighter.opponent,{"duration":windup})
	if windup <= 0 and is_instance_valid(fighter.opponent):
		rotation = (fighter.opponent.global_position-fighter.global_position).angle()
	else: rotation = aim.angle()
	queue_redraw()

func _lead_direction(target: ArenaBall) -> Vector2:
	var offset := target.global_position-fighter.global_position
	if weapon_kind=="magnet": return offset.normalized()
	var velocity := target.linear_velocity
	var speed := (720.0 if boss_kind=="storm" else 510.0) * float(CampaignProgression.data().get("movement_factor",1.0))
	var future := offset+velocity*0.28
	var a := velocity.length_squared()-speed*speed
	var b := 2*future.dot(velocity)
	var c := future.length_squared()
	var discriminant := b*b-4*a*c
	var time := 0.0
	if discriminant>=0 and absf(a)>0.001:
		var t1 := (-b-sqrt(discriminant))/(2*a)
		var t2 := (-b+sqrt(discriminant))/(2*a)
		time=minf(t1 if t1>0 else INF,t2 if t2>0 else INF)
	if not is_finite(time): time=0
	return (future+velocity*minf(time,1.2)).normalized()

func _field() -> Node2D:
	var arena := fighter.get_parent().get_parent()
	return arena.get_node_or_null("ProjectileField") as Node2D

func _fire(field: Node2D) -> void:
	if weapon_kind == "magnet":
		_pulse_left = 0.8 if boss_kind == "archon" else 0.6
		# Contact damage is finite and requires actual proximity, not merely a pull.
		for target in hostile_targets():
			if target.global_position.distance_to(fighter.global_position) < (target.diameter+fighter.diameter)*0.5+14:
				target.take_damage(base_damage,fighter,ability_id)
		emit_event(&"magnetic_pulse")
		return
	var kind := weapon_kind
	if boss_kind == "nox": kind = ["flask","acid","fire_flask"][shots%3]
	if boss_kind == "storm" and shots%2 == 1:
		for angle in [-0.13,0.13]: field.call("launch",fighter,aim.rotated(angle),base_damage,kind,650.0*_tempo(),2)
	else: field.call("launch",fighter,aim,base_damage,kind,(720.0 if boss_kind == "storm" else 510.0)*_tempo(),2 if boss_kind == "nox" else 1)
	emit_event(&"projectile_fired",null,{"kind":kind})

func _tempo() -> float: return float(CampaignProgression.data().get("movement_factor",1.0))

func _draw() -> void:
	if not is_enabled(): return
	var x := fighter.diameter*0.5+10
	var pale := Color("d0e3ef")
	match weapon_kind:
		"magnet":
			draw_arc(Vector2.ZERO,fighter.diameter*0.5+8,-0.9,0.9,20,Color("8b90bf"),6,true)
			if windup > 0 or _pulse_left > 0: draw_arc(Vector2.ZERO,60+40*sin(windup*4+_pulse_left*6),0,TAU,40,Color(0.6,0.5,1,0.35),2,true)
		"crossbow":
			draw_line(Vector2(x-6,-17),Vector2(x+4,0),Color("8c6440"),6,true)
			draw_line(Vector2(x+4,0),Vector2(x-6,17),Color("8c6440"),6,true)
			draw_line(Vector2(x-6,-17),Vector2(x-6,17),pale,1,true)
			draw_line(Vector2(x-10,0),Vector2(x+18,0),pale,3,true)
		"boomerang":
			if cooldown_remaining < hit_cooldown-1.4:
				draw_polyline(PackedVector2Array([Vector2(x,-14),Vector2(x+10,0),Vector2(x,14)]),Color("c5a76c"),7,true)
		_: 
			var color := Color("ff963f") if weapon_kind == "fireball" else (Color("84d8ff") if weapon_kind == "iceball" else Color("9fc45f"))
			draw_circle(Vector2(x,0),9,Color("182132")); draw_circle(Vector2(x,0),7,color)
			draw_circle(Vector2(x-2,-3),2,Color("e9faff"))
	if windup > 0: draw_line(Vector2(x,0),Vector2(x+45,0),Color(1,0.8,0.6,0.4),2,true)
