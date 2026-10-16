class_name ArenaCombatEffects
extends Node2D
## Reusable drain and spray service. Abilities explicitly start/stop their effects.

@export var max_orbs: int = 96
@export var spray_rate: float = 25.0
@export var orb_rate: float = 25.0
var _spark_layer: MultiMeshInstance2D
var _orb_layer: MultiMeshInstance2D
var sparks: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var counter_slashes: Array[Dictionary] = []
var drains: Dictionary = {}
var orbs: Array[Dictionary] = []
var next_id: int = 0
var number_layer: Node2D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_spark_layer=BloodDrawing.make_instances(BloodDrawing.get_spark_mesh(),160)
	_spark_layer.show_behind_parent=true
	add_child(_spark_layer)
	_orb_layer=BloodDrawing.make_instances(BloodDrawing.get_orb_mesh(),max_orbs)
	add_child(_orb_layer)
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
	if shockwaves.is_empty() and counter_slashes.is_empty() and sparks.is_empty() and slashes.is_empty() and drains.is_empty() and orbs.is_empty():
		if is_instance_valid(_spark_layer):_spark_layer.multimesh.visible_instance_count=0
		if is_instance_valid(_orb_layer):_orb_layer.multimesh.visible_instance_count=0
		return
	for index in range(shockwaves.size()-1,-1,-1):
		shockwaves[index]["age"] += delta
		if shockwaves[index]["age"] >= .32: shockwaves.remove_at(index)
	for index in range(counter_slashes.size()-1,-1,-1):
		counter_slashes[index]["age"] += delta
		if counter_slashes[index]["age"] >= 0.32:
			counter_slashes.remove_at(index)
	for index in range(sparks.size() - 1, -1, -1):
		var spark := sparks[index]
		spark["age"] += delta
		if spark["age"] >= spark["life"]:
			sparks.remove_at(index)
		else:
			spark["position"] += spark["velocity"] * delta
			spark["velocity"] += Vector2.DOWN * 240.0 * delta
	for index in range(slashes.size() - 1, -1, -1):
		slashes[index]["age"] += delta
		if slashes[index]["age"] >= 0.22:
			slashes.remove_at(index)
	for id in drains.keys():
		var drain: Dictionary = drains[id]
		var attacker := _drain_actor(drain["attacker"])
		var victim := _drain_actor(drain["victim"])
		if not is_instance_valid(attacker) or not is_instance_valid(victim):
			stop_drain(id)
			continue
		drain["bolt_elapsed"] += delta
		if drain["bolt_elapsed"] >= 0.055:
			drain["bolt_elapsed"] = fmod(drain["bolt_elapsed"], 0.055)
			drain["bolt"] = _new_bolt()
		var spray_batches := 0
		if spray_rate > 0.0:
			drain["spray_elapsed"] += delta
			var period := 3.0/spray_rate
			spray_batches = mini(8,floori(drain["spray_elapsed"]/period))
			drain["spray_elapsed"] = fmod(drain["spray_elapsed"],period)
		for batch in spray_batches:
			var facing := (attacker.global_position - victim.global_position).normalized()
			var wound := victim.global_position + facing * victim.visual_diameter() * 0.42
			if is_instance_valid(attacker.blood_effects):
				for index in 3:
					var velocity := Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(70.0, 300.0)
					attacker.blood_effects.call("spawn_spray", wound, velocity, rng.randf_range(1.70, 3.30))
		var orb_count := 0
		if orb_rate > 0.0:
			drain["orb_elapsed"] += delta
			var period := 1.0/orb_rate
			orb_count = mini(maxi(0,max_orbs-orbs.size()),floori(drain["orb_elapsed"]/period))
			drain["orb_elapsed"] = fmod(drain["orb_elapsed"],period)
		for batch in orb_count:
			if orbs.size() < max_orbs:
				var offset := Vector2.from_angle(rng.randf_range(-PI, PI)) 					* sqrt(rng.randf()) * victim.visual_diameter() * 0.48
				orbs.append({"drain": id, "offset": offset, "age": 0.0,
					"duration": rng.randf_range(0.35, 0.62), "radius": rng.randf_range(1.8, 3.0)})
	for index in range(orbs.size() - 1, -1, -1):
		orbs[index]["age"] += delta
		if orbs[index]["age"] >= orbs[index]["duration"]:
			orbs.remove_at(index)
	_update_instances()
	queue_redraw()


func orb_position(orb: Dictionary) -> Vector2:
	# A caller may still hold an orb after its drain has ended or its actors left.
	if not drains.has(orb["drain"]):
		return Vector2.ZERO
	var drain: Dictionary = drains[orb["drain"]]
	var victim := _drain_actor(drain["victim"])
	var attacker := _drain_actor(drain["attacker"])
	if victim == null or attacker == null:
		return Vector2.ZERO
	return _orb_position(orb, victim, attacker)


func _orb_position(orb: Dictionary, victim: ArenaBall, attacker: ArenaBall) -> Vector2:
	var progress := smoothstep(0.0, 1.0, float(orb["age"]) / float(orb["duration"]))
	return (victim.global_position + Vector2(orb["offset"])).lerp(attacker.global_position, progress)


func _drain_actor(reference: WeakRef) -> ArenaBall:
	var actor := reference.get_ref() as ArenaBall
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return null
	return actor


func _draw() -> void:
	_draw_shockwaves()
	_draw_counter_slashes()
	_draw_slashes()
	for drain in drains.values():
		var victim := _drain_actor(drain["victim"])
		var attacker := _drain_actor(drain["attacker"])
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



# Shared bounded impact effect: two expanding rings and a brief directional front.
func spawn_shockwave(position: Vector2, direction: Vector2, size: float = 1.0) -> void:
	for wave in shockwaves:
		if wave["age"] < .02 and Vector2(wave["position"]).distance_squared_to(position) < 36: return
	if shockwaves.size() >= 24: shockwaves.pop_front()
	shockwaves.append({"position":position,"direction":direction.normalized(),"size":size,"age":0.0})
	queue_redraw()

func _draw_shockwaves() -> void:
	for wave in shockwaves:
		var t: float = wave["age"]/.32
		var fade := (1.0-t)*(1.0-t)
		var size: float = wave["size"]
		var center := to_local(wave["position"])
		var radius := (7.0+55.0*(1.0-pow(1.0-t,2)))*size
		draw_arc(center,radius,0,TAU,32,Color(1.0,.62,.20,fade*.14),6.0*size*(1.0-t)+.5,true)
		draw_arc(center,radius,0,TAU,32,Color(1.0,.91,.67,fade*.78),1.6*size,true)
		var angle: float = Vector2(wave["direction"]).angle()
		draw_arc(center,radius*.76,angle-.75,angle+.75,14,Color(1.0,.98,.89,fade*.7),2.5*size*(1.0-t)+.4,true)
		if t < .18: draw_circle(center,(1.0-t/.18)*8*size,Color(1,.95,.76,(1.0-t/.18)*.55))

func spawn_slash(world_position: Vector2, direction: Vector2, size: float = 1.0) -> void:
	if slashes.size() >= 32:
		slashes.pop_front()
	slashes.append({"center": world_position, "direction": direction.normalized(), "size": size, "age": 0.0})
	queue_redraw()


func _draw_slashes() -> void:
	for slash in slashes:
		var progress: float = slash["age"] / 0.22
		var opacity := pow(1.0 - progress, 2.0)
		var direction: Vector2 = slash["direction"]
		var side := direction.orthogonal()
		var center := to_local(slash["center"])
		var length: float = (48.0 + 22.0 * progress) * slash["size"]
		# Thin ivory cut with tapered tips and a soft amber fringe.
		for layer in 3:
			var width: float = [4.5, 2.0, 0.65][layer] * slash["size"]
			var tint: Color = [Color(1.0, 0.65, 0.20, opacity * 0.14), Color(1.0, 0.88, 0.50, opacity * 0.65), Color(1.0, 1.0, 0.93, opacity)][layer]
			var points := PackedVector2Array([center - direction * length,
				center - direction * length * 0.18 + side * width,
				center + direction * length,
				center + direction * length * 0.18 - side * width])
			draw_colored_polygon(points, tint)


func spawn_sparks(world_position: Vector2) -> void:
	for index in 12:
		if sparks.size() >= 160:
			sparks.pop_front()
		var direction := Vector2.from_angle(rng.randf_range(-PI,PI))
		sparks.append({"position":to_local(world_position), "velocity":direction * rng.randf_range(70.0,240.0),
			"age":0.0,"life":rng.randf_range(0.16,0.35)})
	queue_redraw()


func spawn_berserk(world_position: Vector2) -> void:
	number_layer.call("spawn_berserk", world_position)

func spawn_notice(world_position: Vector2, text: String, tint: Color) -> void:
	number_layer.call("spawn_notice",world_position,text,tint)


func spawn_counter_slash(world_center: Vector2, direction: Vector2, length: float) -> void:
	if counter_slashes.size() >= 16:
		counter_slashes.pop_front()
	counter_slashes.append({"center":world_center,"direction":direction.normalized(),"length":length,"age":0.0})
	queue_redraw()

func _draw_counter_slashes() -> void:
	for slash in counter_slashes:
		var progress: float = slash["age"]/0.32
		var opacity := pow(1.0-progress,2.0)
		var direction: Vector2 = slash["direction"]
		var side := direction.orthogonal()
		var center := to_local(slash["center"])
		var half_length: float = slash["length"]*0.5*(1.0+progress*0.20)
		for layer in 4:
			var width: float = [7.0,3.2,1.35,0.40][layer]*(1.0-progress*0.4)
			var tint: Color = [Color(0.95,0.01,0.025,opacity*0.15),Color(1.0,0.015,0.045,opacity),
				Color(1.0,0.20,0.24,opacity),Color(1.0,0.78,0.78,opacity)][layer]
			draw_colored_polygon(PackedVector2Array([center-direction*half_length,
				center-direction*half_length*0.22+side*width,center+direction*half_length,
				center+direction*half_length*0.22-side*width]),tint)

func _update_instances() -> void:
	if not is_instance_valid(_spark_layer):return
	BloodDrawing.ensure_capacity(_spark_layer, sparks.size())
	BloodDrawing.ensure_capacity(_orb_layer, maxi(max_orbs, orbs.size()))
	var multi := _spark_layer.multimesh
	for index in sparks.size():
		var spark := sparks[index]
		var velocity: Vector2=spark["velocity"]
		multi.set_instance_transform_2d(index,Transform2D(velocity.angle(),spark["position"]))
		multi.set_instance_color(index,Color(1,1,1,pow(1.0-float(spark["age"])/float(spark["life"]),1.5)))
	multi.visible_instance_count=sparks.size()
	multi=_orb_layer.multimesh
	var index := 0
	for orb in orbs:
		if not drains.has(orb["drain"]):continue
		var drain: Dictionary=drains[orb["drain"]]
		var victim := _drain_actor(drain["victim"])
		var attacker := _drain_actor(drain["attacker"])
		if victim == null or attacker == null:
			continue
		var p := to_local(_orb_position(orb, victim, attacker))
		multi.set_instance_transform_2d(index,Transform2D(0,Vector2.ONE*float(orb["radius"]),0,p))
		multi.set_instance_color(index,Color(1,1,1,sin(float(orb["age"])/float(orb["duration"])*PI)))
		index+=1
	multi.visible_instance_count=index
