class_name ArenaCombatEffects
extends Node2D
## Reusable drain and spray service. Abilities explicitly start/stop their effects.

@export var max_orbs: int = 96
@export var spray_rate: float = 25.0
@export var orb_rate: float = 25.0
var drains: Dictionary = {}
var orbs: Array[Dictionary] = []
var next_id: int = 0
var number_layer: Node2D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	number_layer = Node2D.new()
	number_layer.name = "FloatingNumbers"
	number_layer.z_index = 3
	number_layer.set_script(preload("res://scripts/combat_numbers.gd"))
	add_child(number_layer)


func start_drain(attacker: ArenaBall, victim: ArenaBall) -> int:
	var id := next_id
	next_id += 1
	drains[id] = {"attacker": weakref(attacker), "victim": weakref(victim),
		"spray_elapsed": 0.0, "orb_elapsed": 0.0, "bolt_elapsed": 0.0,
		"bolt": _new_bolt()}
	queue_redraw()
	return id


func stop_drain(id: int) -> void:
	drains.erase(id)
	for index in range(orbs.size() - 1, -1, -1):
		if orbs[index]["drain"] == id:
			orbs.remove_at(index)
	queue_redraw()


func spawn_number(world_position: Vector2, amount: int, healing: bool) -> void:
	number_layer.call("spawn", world_position, amount, healing)


func _new_bolt() -> PackedFloat32Array:
	var jitter := PackedFloat32Array()
	for index in 15:
		jitter.append(0.0 if index == 0 or index == 14 else rng.randf_range(-1.0, 1.0))
	return jitter


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for id in drains.keys():
		var drain: Dictionary = drains[id]
		var attacker: ArenaBall = drain["attacker"].get_ref()
		var victim: ArenaBall = drain["victim"].get_ref()
		if not is_instance_valid(attacker) or not is_instance_valid(victim):
			stop_drain(id)
			continue
		drain["bolt_elapsed"] += delta
		if drain["bolt_elapsed"] >= 0.055:
			drain["bolt_elapsed"] = fmod(drain["bolt_elapsed"], 0.055)
			drain["bolt"] = _new_bolt()
		drain["spray_elapsed"] += delta
		while drain["spray_elapsed"] >= 3.0 / spray_rate:
			drain["spray_elapsed"] -= 3.0 / spray_rate
			var facing := (attacker.global_position - victim.global_position).normalized()
			var wound := victim.global_position + facing * victim.visual_diameter() * 0.42
			if is_instance_valid(attacker.blood_effects):
				for index in 3:
					var velocity := Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(70.0, 300.0)
					attacker.blood_effects.call("spawn_spray", wound, velocity, rng.randf_range(1.70, 3.30))
		drain["orb_elapsed"] += delta
		while drain["orb_elapsed"] >= 1.0 / orb_rate:
			drain["orb_elapsed"] -= 1.0 / orb_rate
			if orbs.size() < max_orbs:
				var offset := Vector2.from_angle(rng.randf_range(-PI, PI)) 					* sqrt(rng.randf()) * victim.visual_diameter() * 0.48
				orbs.append({"drain": id, "offset": offset, "age": 0.0,
					"duration": rng.randf_range(0.35, 0.62), "radius": rng.randf_range(1.8, 3.0)})
	for index in range(orbs.size() - 1, -1, -1):
		orbs[index]["age"] += delta
		if orbs[index]["age"] >= orbs[index]["duration"]:
			orbs.remove_at(index)
	queue_redraw()


func orb_position(orb: Dictionary) -> Vector2:
	var drain: Dictionary = drains[orb["drain"]]
	var victim: ArenaBall = drain["victim"].get_ref()
	var attacker: ArenaBall = drain["attacker"].get_ref()
	var progress := smoothstep(0.0, 1.0, float(orb["age"]) / float(orb["duration"]))
	return (victim.global_position + Vector2(orb["offset"])).lerp(attacker.global_position, progress)


func _draw() -> void:
	for drain in drains.values():
		var victim: ArenaBall = drain["victim"].get_ref()
		var attacker: ArenaBall = drain["attacker"].get_ref()
		if not is_instance_valid(victim) or not is_instance_valid(attacker):
			continue
		var from := to_local(victim.global_position)
		var to := to_local(attacker.global_position)
		var side := (to - from).normalized().orthogonal()
		var points := PackedVector2Array()
		var jitter: PackedFloat32Array = drain["bolt"]
		for index in 15:
			var t := float(index) / 14.0
			points.append(from.lerp(to, t) + side * jitter[index] * 3.2)
		draw_polyline(points, Color(0.22, 1.0, 0.42, 0.07), 4.0, true)
		draw_polyline(points, Color(0.63, 1.0, 0.72, 0.29), 1.2, true)
	for orb in orbs:
		if not drains.has(orb["drain"]):
			continue
		var drain: Dictionary = drains[orb["drain"]]
		if drain["attacker"].get_ref() == null or drain["victim"].get_ref() == null:
			continue
		var p := to_local(orb_position(orb))
		var progress: float = orb["age"] / orb["duration"]
		var opacity := sin(progress * PI)
		var radius: float = orb["radius"]
		draw_circle(p, radius * 1.7, Color(0.20, 1.0, 0.32, opacity * 0.06))
		draw_circle(p, radius, Color(0.32, 0.95, 0.43, opacity * 0.35))
		draw_circle(p + Vector2(-0.4, -0.5), radius * 0.35, Color(0.75, 1.0, 0.78, opacity * 0.5))
