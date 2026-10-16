class_name ArenaBlood
extends Node2D
## Blood positions are stored in arena space, independent of fang rotation.

signal drop_landed
signal spray_hit

@export var arena_width: float = 960.0
@export_range(16, 1024, 1) var max_splashes: int = 512
@export_range(16, 256, 1) var max_surface_pools: int = 128
@export var floor_y: float = 600.0
@export_range(10.0, 3000.0, 10.0) var gravity: float = 750.0
@export_range(0.1, 10.0, 0.1) var stain_lifetime: float = 1.25
@export_range(4, 512, 1) var max_drops: int = 144

var impact_drops: Array[Dictionary] = []
var surface_marks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _pool_layer: Node2D
var _particle_layer: MultiMeshInstance2D
var drops: Array[Dictionary] = []
var splashes: Array[Dictionary] = []


func spawn_drop(world_position: Vector2, radius: float = 2.8) -> void:
	if drops.size() >= max_drops:
		drops.pop_front()
	var p := to_local(world_position)
	p.y = minf(p.y, floor_y - radius)
	drops.append({
		"position": p,
		"fall_speed": 32.0,
		"radius": radius,
		"landed": false,
		"age": 0.0,
	})
	queue_redraw()


# Reusable ballistic spray; unlike large drips it disappears only on boundary impact.
func spawn_spray(world_position: Vector2, world_velocity: Vector2, radius: float = 1.2) -> bool:
	if splashes.size() >= max_splashes:
		return false
	var p := to_local(world_position)
	p = p.clamp(Vector2.ONE * radius, Vector2(arena_width - radius, floor_y - radius))
	var velocity := to_local(world_position + world_velocity) - to_local(world_position)
	splashes.append({"position": p, "velocity": velocity, "radius": radius})
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	# Pools are deposited with settled geometry; redraw only when particles move.
	if is_instance_valid(_particle_layer):_particle_layer.multimesh.visible_instance_count=0
	if drops.is_empty() and splashes.is_empty() and impact_drops.is_empty():
		return
	for index in range(impact_drops.size() - 1, -1, -1):
		var tiny := impact_drops[index]
		tiny["age"] += delta
		var hit := _boundary_hit(tiny["position"],tiny["velocity"],tiny["radius"],delta)
		if not hit.is_empty():
			_add_surface_pool(hit["position"],hit["normal"],tiny["radius"])
		if not hit.is_empty() or tiny["age"] >= 0.65:
			impact_drops.remove_at(index) # Secondary splashes never recursively spawn splashes.
		else:
			tiny["position"] += tiny["velocity"] * delta + Vector2.DOWN * gravity * delta * delta * 0.5
			tiny["velocity"] += Vector2.DOWN * gravity * delta
	for index in range(splashes.size() - 1, -1, -1):
		var spray := splashes[index]
		var p: Vector2 = spray["position"]
		var velocity: Vector2 = spray["velocity"]
		var radius: float = spray["radius"]
		var hit := _boundary_hit(p,velocity,radius,delta)
		if not hit.is_empty():
			splashes.remove_at(index)
			_surface_splash(hit["position"],hit["normal"],radius)
			spray_hit.emit()
		else:
			spray["position"] = p + velocity * delta + Vector2.DOWN * gravity * delta * delta * 0.5
			spray["velocity"] = velocity + Vector2.DOWN * gravity * delta
	for index in range(drops.size() - 1, -1, -1):
		var drop := drops[index]
		var radius: float = drop["radius"]
		if drop["landed"]:
			drop["age"] += delta
			if drop["age"] >= stain_lifetime:
				drops.remove_at(index)
		else:
			var p: Vector2 = drop["position"]
			var speed: float = drop["fall_speed"]
			p.y += speed * delta + gravity * delta * delta * 0.5
			drop["fall_speed"] = speed + gravity * delta
			if p.y >= floor_y - radius:
				p.y = floor_y - radius
				drop["landed"] = true
				drop["age"] = 0.0
				_surface_splash(p, Vector2.UP, radius)
				drop_landed.emit()
			drop["position"] = p
	_update_particles()
	queue_redraw()


func _draw() -> void:
	for drop in drops:
		var p: Vector2 = drop["position"]
		var radius: float = drop["radius"]
		var scale_factor := Vector2(1.0, 1.35)
		var alpha := 0.9
		if drop["landed"]:
			var age: float = drop["age"]
			var squash := clampf(age / 0.12, 0.0, 1.0)
			scale_factor = Vector2(lerpf(1.0, 2.8, squash), lerpf(1.0, 0.18, squash))
			p.y = floor_y - radius * scale_factor.y
			alpha *= pow(1.0 - clampf(age / stain_lifetime, 0.0, 1.0), 2.0)
		if drop["landed"]:
			draw_set_transform(p, 0.0, scale_factor)
			draw_circle(Vector2.ZERO, radius, Color(0.33, 0.005, 0.02, alpha))
			draw_circle(Vector2.ZERO, radius * 0.83, Color(0.77, 0.012, 0.035, alpha))
			draw_set_transform(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	rng.randomize()
	_pool_layer = Node2D.new()
	_pool_layer.set_script(preload("res://scripts/blood_pool_layer.gd"))
	_pool_layer.show_behind_parent = true
	add_child(_pool_layer)
	_pool_layer.queue_redraw()
	_particle_layer=BloodDrawing.make_instances(BloodDrawing.get_drop_mesh(),max_drops+max_splashes+160)
	add_child(_particle_layer)

func spawn_hit_blood(world_position: Vector2) -> void:
	# Same 4.2-unit radius and glossy drawing as the large post-bite drips.
	for index in 3:
		if splashes.size() >= max_splashes:
			splashes.pop_front()
		spawn_spray(world_position,Vector2.from_angle(rng.randf_range(-PI,PI)) * rng.randf_range(150.0,330.0),4.2)
	queue_redraw()

# Reusable wound emission: random points on the cut, independent ballistic directions.
func spawn_wound_blood(start: Vector2, end: Vector2, count: int = 1) -> void:
	for index in count:
		if splashes.size() >= max_splashes:
			splashes.pop_front()
		var origin := start.lerp(end, rng.randf())
		var velocity := Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(150.0, 330.0)
		spawn_spray(origin, velocity, 4.2)
	queue_redraw()

func _surface_splash(position: Vector2, normal: Vector2, radius: float) -> void:
	_add_surface_pool(position, normal, radius)
	for index in 5:
		if impact_drops.size() >= 160:
			impact_drops.pop_front()
		var small_radius := clampf(radius * rng.randf_range(0.27,0.48),0.75,2.1)
		impact_drops.append({"position":position + normal * 1.5,
			"velocity":normal.rotated(rng.randf_range(-1.15,1.15)) * rng.randf_range(35.0,110.0),
			"radius":small_radius,"age":0.0})

# Analytic first contact with all four walls, including an upward arc that
# touches the ceiling and returns inside the arena within one long frame.
func _boundary_hit(p: Vector2, velocity: Vector2, radius: float, delta: float) -> Dictionary:
	var earliest := delta + 1.0
	var normal := Vector2.ZERO
	if absf(velocity.x) > 0.000001:
		var edge := radius if velocity.x < 0.0 else arena_width - radius
		var time := (edge - p.x) / velocity.x
		if time >= -0.000001 and time <= delta:
			earliest = maxf(0.0,time)
			normal = Vector2.RIGHT if velocity.x < 0.0 else Vector2.LEFT
	for boundary in [{"y":radius,"normal":Vector2.DOWN},{"y":floor_y-radius,"normal":Vector2.UP}]:
		var discriminant: float = velocity.y * velocity.y - 2.0 * gravity * (p.y - boundary["y"])
		if discriminant < 0.0:
			continue
		for root in [-1.0,1.0]:
			var time: float = (-velocity.y + root * sqrt(discriminant)) / gravity
			var incoming := Vector2(velocity.x,velocity.y + gravity * time)
			if time >= -0.000001 and time <= delta and time < earliest and incoming.dot(boundary["normal"]) < 0.0:
				earliest = maxf(0.0,time)
				normal = boundary["normal"]
	if normal.is_zero_approx():
		return {}
	return {"position":p + velocity * earliest + Vector2.DOWN * gravity * earliest * earliest * 0.5,"normal":normal}


func _add_surface_pool(position: Vector2, normal: Vector2, radius: float) -> void:
	var surface := position - normal * radius
	var tangent := Vector2.from_angle(normal.angle() + PI * 0.5)
	var coordinate := surface.dot(tangent)
	var start := coordinate - radius * 2.8
	var end := coordinate + radius * 2.8
	var area := radius * radius
	var seed_value := rng.randf_range(0.0,TAU)
	var wall_pools := 0
	var nearest := -1
	var distance := INF
	for index in surface_marks.size():
		var mark := surface_marks[index]
		if Vector2(mark["normal"]).dot(normal) < 0.99:
			continue
		wall_pools += 1
		var separation := absf(float(mark["position"].dot(tangent)) - coordinate)
		if separation < distance:
			distance = separation
			nearest = index
	# Keep the existing per-wall budget. A saturated wall folds a new deposit
	# into its closest pool, then the same connected-component merge applies.
	if nearest >= 0 and wall_pools >= maxi(1,max_surface_pools / 4):
		var nearest_pool := surface_marks[nearest]
		start = minf(start,nearest_pool["start"])
		end = maxf(end,nearest_pool["end"])
	var merged := true
	while merged:
		merged = false
		for index in range(surface_marks.size() - 1,-1,-1):
			var mark := surface_marks[index]
			if Vector2(mark["normal"]).dot(normal) < 0.99:
				continue
			if float(mark["end"]) < start - 0.05 or float(mark["start"]) > end + 0.05:
				continue
			start = minf(start,mark["start"])
			end = maxf(end,mark["end"])
			area += float(mark["area"])
			seed_value = mark["seed"]
			surface_marks.remove_at(index)
			merged = true
	if surface_marks.size() >= max_surface_pools:
		return
	var center := (start + end) * 0.5
	var depth := minf(12.0,sqrt(area))
	var half_width := (end - start) * 0.5
	surface += tangent * (center - coordinate)
	surface_marks.append({"position":surface,"normal":normal,"radius":depth,"age":0.22,
		"seed":seed_value,"area":area,"start":start,"end":end,"half_width":half_width,
		"shape":_pool_shape(depth,seed_value,half_width)})
	if is_instance_valid(_pool_layer): _pool_layer.queue_redraw()

func _pool_shape(radius: float, seed_value: float, half_width: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	# Fixed vertex budget, even if an entire wall becomes a single connected pool.
	for index in 48:
		var angle := TAU * index / 48.0
		var irregularity := 1.0 + sin(angle * 3.0 + seed_value) * 0.09 + sin(angle * 5.0 - seed_value) * 0.05
		points.append(Vector2(cos(angle) * half_width,sin(angle) * radius * 0.50 * irregularity))
	return points

func draw_pools(canvas: Node2D) -> void:
	for mark in surface_marks:
		var normal: Vector2 = mark["normal"]
		var radius: float = mark["radius"]
		var spread := lerpf(0.65,1.0,smoothstep(0.0,0.22,float(mark["age"])))
		canvas.draw_set_transform(mark["position"] + normal * radius * 0.30, normal.angle() + PI * 0.5, Vector2(spread,1.0))
		canvas.draw_colored_polygon(mark["shape"], Color(0.24,0.002,0.012,0.98))
		canvas.draw_set_transform(mark["position"] + normal * radius * 0.36, normal.angle() + PI * 0.5, Vector2(spread * 0.91,0.84))
		canvas.draw_colored_polygon(mark["shape"], Color(0.64,0.008,0.025,0.97))
		# Thin wet highlights; geometry is cached per pool rather than rebuilt per frame.
		canvas.draw_line(Vector2(-float(mark["half_width"]) * 0.5,-radius * 0.15),Vector2(float(mark["half_width"]) * 0.10,-radius * 0.22),Color(1.0,0.28,0.30,0.66),0.7,true)
		canvas.draw_line(Vector2(-float(mark["half_width"]) * 0.33,-radius * 0.20),Vector2(-float(mark["half_width"]) * 0.10,-radius * 0.23),Color(1.0,0.82,0.78,0.65),0.45,true)
	canvas.draw_set_transform(Vector2.ZERO)

func _update_particles() -> void:
	if not is_instance_valid(_particle_layer):return
	BloodDrawing.ensure_capacity(_particle_layer, maxi(
		max_drops + max_splashes + 160, drops.size() + splashes.size() + impact_drops.size()
	))
	var multi := _particle_layer.multimesh
	var index := 0
	for tiny in impact_drops:
		multi.set_instance_transform_2d(index,Transform2D(0,Vector2.ONE*float(tiny["radius"]),0,tiny["position"]))
		multi.set_instance_color(index,Color(1,1,1,1.0-float(tiny["age"])/.65))
		index+=1
	for spray in splashes:
		var velocity: Vector2=spray["velocity"]
		var angle := Vector2.DOWN.angle_to(velocity.normalized()) if not velocity.is_zero_approx() else 0.0
		multi.set_instance_transform_2d(index,Transform2D(angle,Vector2.ONE*float(spray["radius"]),0,spray["position"]))
		multi.set_instance_color(index,Color.WHITE)
		index+=1
	for drop in drops:
		if drop["landed"]:continue
		multi.set_instance_transform_2d(index,Transform2D(0,Vector2.ONE*float(drop["radius"]),0,drop["position"]))
		multi.set_instance_color(index,Color(1,1,1,.9))
		index+=1
	multi.visible_instance_count=index
