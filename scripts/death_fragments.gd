class_name ArenaDeathFragments
extends Node2D
## GPU-retained portraits and shared precomputed puzzle cells; no GPU readback on death.
const BALL := preload("res://scenes/ball.tscn")
const SHARD := preload("res://scripts/death_fragment.gd")
const CAPTURE_SIZE := Vector2i(768, 768)
const CAPTURE_SCALE := 2.0
const MAX_FRAGMENTS := 40
static var _body_cells: Array[PackedVector2Array] = []
var _captures: Dictionary = {}
var _capture_queue: Array[Dictionary] = []
var _capture_busy := false
var _weapons_built := false
var groups: Array[Node2D] = []
var weapons: Array[Dictionary] = []
var fighters: Array[ArenaBall] = []
var rng := RandomNumberGenerator.new()
var body_contacts: int = 0
var weapon_contacts: int = 0
## Optional scene adapter; defaults retain the free-battle portrait exactly.
var portrait_factory: Callable

func _ready() -> void:
	z_index = 4
	process_physics_priority = 200
	rng.randomize()
	if _body_cells.is_empty(): _prepare_body_cells()

func watch(fighter: ArenaBall) -> void:
	if not is_instance_valid(fighter) or fighter in fighters:
		return
	fighters.append(fighter)
	fighter.died.connect(_on_death.bind(fighter))
	_weapons_built = false

func _on_death(attacker: ArenaBall, _ability: StringName, fighter: ArenaBall) -> void:
	var portrait_size := fighter.visual_diameter()
	var departure := fighter._last_direction * fighter.movement_speed * 0.25
	if is_instance_valid(attacker) and attacker != fighter:
		departure += (fighter.global_position - attacker.global_position).normalized() * 70.0
	fighter.hide()
	fighter.set_deferred("collision_layer", 0)
	fighter.set_deferred("collision_mask", 0)
	if DisplayServer.get_name() != "headless":
		_capture_queue.append({"fighter":weakref(fighter),"diameter":portrait_size,"departure":departure})

func _begin_capture(request: Dictionary) -> void:
	# Deferred calls must carry a weak reference: a freed typed Node argument
	# would fail before _capture could execute its own validity check.
	var fighter := request["fighter"].get_ref() as ArenaBall
	if not is_instance_valid(fighter):
		_capture_busy = false
		return
	_capture(fighter, request["diameter"], request["departure"])


func _capture(fighter: ArenaBall, portrait_size: float, departure: Vector2) -> void:
	if not is_inside_tree() or not is_instance_valid(fighter) or not fighter.is_inside_tree() or fighter.is_queued_for_deletion():
		_capture_busy = false
		return
	_capture_busy = true
	var origin := fighter.global_position
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var portrait := (portrait_factory.call(fighter) if portrait_factory.is_valid() else BALL.instantiate()) as ArenaBall
	portrait.is_vampire = fighter.is_vampire
	portrait.is_swordsman = fighter.is_swordsman
	portrait.ball_color = fighter.ball_color.darkened(0.55) if fighter.is_paralyzed() else fighter.ball_color
	portrait.diameter = portrait_size
	portrait.pulse_minimum_ratio = 1.0
	portrait.position = Vector2(CAPTURE_SIZE) * 0.5
	portrait.rotation = fighter.global_rotation
	portrait.scale = Vector2.ONE * CAPTURE_SCALE
	viewport.add_child(portrait)
	if fighter.character_definition != null:
		CharacterCatalog.apply(portrait,fighter.character_definition,portrait_size / fighter.character_definition.diameter_multiplier)
	if portrait.has_method("prepare_death_portrait"):
		portrait.call("prepare_death_portrait",fighter)
	portrait.freeze = true
	portrait.collision_layer = 0
	portrait.collision_mask = 0
	portrait.current_health = 100
	portrait.katana_wound_stage = fighter.katana_wound_stage
	portrait.get_node("KatanaWound").call("_process", 0.0)
	portrait.bite_marks = fighter.bite_marks.duplicate()
	portrait.bite_marks_remaining = fighter.bite_marks_remaining
	_disable_processing(portrait)
	portrait.get_node("HealthDisplay").hide()
	portrait.get_node("CooldownIndicator").hide()
	portrait.get_node("BloodRunoff").hide()
	var sword := portrait.get_node("Sword") as SwordAbility
	var source_sword := fighter.get_node("Sword") as SwordAbility
	sword.rotation = source_sword.rotation
	sword.blade_length = source_sword.blade_length
	sword.visible = fighter.is_swordsman and not fighter.is_vampire
	sword.queue_redraw()
	var fangs := portrait.get_node("Vampire") as VampireFangs
	var source_fangs := fighter.get_node("Vampire") as VampireFangs
	fangs.rotation = source_fangs.rotation
	fangs.visible = false # Fang imagery is in ApprovedVampireArt; omit the aura.
	fangs._fixed_fang_diameter = source_fangs.fang_diameter()
	if fighter.is_vampire:
		fangs.bite_target = portrait # Preserve tooth size independently of body pulsation.
	portrait.get_node("OrdinaryBallArt").call("_process", 0.0)
	portrait.get_node("ApprovedVampireArt").call("_process", 0.0)
	for source in fighter.get_children():
		if source is SwordAbility and not source is DaggerAbility and source.name == "Sword":
			continue
		if source is SwordAbility:
			var copy := portrait.get_node_or_null(NodePath(source.name)) as SwordAbility
			if copy != null:
				copy.rotation = source.rotation
				copy.blade_length = source.blade_length
				copy.visible = source.is_enabled()
				copy.queue_redraw()
	_disable_processing(portrait)
	portrait.queue_redraw()
	await RenderingServer.frame_post_draw
	# Scene replacement or actor removal can happen while the GPU renders.
	if not is_inside_tree() or not is_instance_valid(fighter) or not fighter.is_inside_tree() or fighter.is_queued_for_deletion():
		if is_instance_valid(viewport):
			viewport.queue_free()
		_capture_busy = false
		return
	var group := _spawn_retained_puzzle(viewport.get_texture(),origin,portrait_size,fighter,departure)
	_captures[group.get_instance_id()] = viewport
	_capture_busy = false

func _prepare_body_cells() -> void:
	var circle := PackedVector2Array()
	for index in 48:circle.append(Vector2.from_angle(index*TAU/48))
	var sites := PackedVector2Array()
	var random := RandomNumberGenerator.new()
	random.seed = 42017
	for y in 5:
		for x in 5:
			var point := Vector2((x+random.randf_range(.25,.75))/5.0*2-1,(y+random.randf_range(.25,.75))/5.0*2-1)
			if point.length_squared() < 1.1:sites.append(point)
	for index in sites.size():
		var cell := circle
		for other in sites.size():
			if other != index:cell = _clip(cell,(sites[index]+sites[other])*.5,sites[other]-sites[index])
		if cell.size() >= 3:_body_cells.append(cell)

func _spawn_retained_puzzle(texture: Texture2D,origin: Vector2,diameter: float,fighter: ArenaBall,departure: Vector2) -> Node2D:
	var group := Node2D.new()
	group.name = "DeathPuzzle"
	add_child(group)
	groups.append(group)
	var radius := (diameter*.56 if fighter.is_vampire else diameter*.5+1.25)*CAPTURE_SCALE
	var center := Vector2(CAPTURE_SIZE)*.5
	for template in _body_cells:
		var polygon := PackedVector2Array()
		for point in template:polygon.append(center+point*radius)
		_add_piece(group,texture,polygon,origin,-center,departure)
	for child in fighter.get_children():
		if child is CombatAbility and child.is_enabled():
			for segment in child.current_weapon_segments():
				var direction: Vector2 = (segment[1]-segment[0]).normalized()
				var start: Vector2 = center+(segment[0]-origin-direction*10*fighter.diameter/70)*CAPTURE_SCALE
				var end: Vector2 = center+(segment[1]-origin)*CAPTURE_SCALE
				var side: Vector2 = direction.orthogonal()*child.weapon_radius()*CAPTURE_SCALE*2.5
				for index in 4:
					var t0 := float(index)/4
					var t1 := float(index+1)/4
					var first: Vector2 = start.lerp(end,t0)
					var last: Vector2 = start.lerp(end,t1)
					var skew: Vector2 = direction*side.length()*.25*sin(index*2.7)
					_add_piece(group,texture,PackedVector2Array([first-side,first+side+skew,last+side,last-side-skew]),origin,-center,departure)
	if fighter.is_vampire:
		var fangs := fighter.get_node("Vampire") as VampireFangs
		for tooth in 4:
			var polygon := PackedVector2Array()
			for point in fangs._tooth_shape(tooth,1,0,6):
				polygon.append(center+point.rotated(fangs.global_rotation)*fangs.fang_diameter()*.5*CAPTURE_SCALE)
			# Two uneven pieces from each tooth, preserving its actual silhouette.
			var pivot := Vector2.ZERO
			for point in polygon:pivot+=point
			pivot/=polygon.size()
			for sign_value in [-1.0,1.0]:
				var cell := _clip(polygon,pivot,Vector2(.2,sign_value))
				if cell.size() >= 3:_add_piece(group,texture,cell,origin,-center,departure)
	return group

func _add_piece(group: Node2D,texture: Texture2D,cell: PackedVector2Array,origin: Vector2,crop_offset: Vector2,departure: Vector2) -> void:
	if cell.size() < 3 or group.get_child_count() >= MAX_FRAGMENTS:return
	var center := Vector2.ZERO
	for point in cell:center+=point
	center/=cell.size()
	var geometry := PackedVector2Array()
	for point in cell:geometry.append((point-center)/CAPTURE_SCALE)
	var body := RigidBody2D.new()
	body.set_script(SHARD)
	body.mass = .015
	body.gravity_scale = .35
	body.collision_layer = 4
	# Fragment/fragment contacts are visual noise and quadratic physics work.
	body.collision_mask = 1 | 8
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body.linear_damp = .4
	body.angular_damp = .5
	var material := PhysicsMaterial.new()
	material.bounce = .45
	material.friction = .5
	body.physics_material_override = material
	var collision := CollisionPolygon2D.new()
	collision.polygon = geometry
	body.add_child(collision)
	var art := Polygon2D.new()
	art.texture = texture
	art.polygon = geometry
	art.uv = cell
	body.add_child(art)
	body.position = group.to_local(origin+(center+crop_offset)/CAPTURE_SCALE)
	body.linear_velocity = departure+(center+crop_offset).normalized().rotated(rng.randf_range(-.35,.35))*rng.randf_range(60,145)
	body.angular_velocity = rng.randf_range(-5,5)
	body.max_contacts_reported = 4
	body.contact_monitor = true
	body.body_entered.connect(_on_shard_contact)
	group.add_child(body)

func _disable_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_processing(child)

func spawn_puzzle(image: Image,origin: Vector2,crop_offset: Vector2,departure: Vector2) -> Node2D:
	# Compatibility utility for synthetic test images; the game uses retained GPU textures.
	var group := Node2D.new()
	add_child(group)
	groups.append(group)
	var texture := ImageTexture.create_from_image(image)
	var size := Vector2(image.get_size())
	for template in _body_cells:
		var polygon := PackedVector2Array()
		for point in template:polygon.append((point+Vector2.ONE)*size*.5)
		_add_piece(group,texture,polygon,origin,crop_offset,departure)
	return group

func _clip(points: PackedVector2Array, midpoint: Vector2, normal: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty():
		return result
	var previous := points[-1]
	var previous_distance := (previous - midpoint).dot(normal)
	for current in points:
		var distance := (current - midpoint).dot(normal)
		if (distance <= 0.0) != (previous_distance <= 0.0):
			result.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance <= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result

func _on_shard_contact(body: Node) -> void:
	if body is ArenaBall:
		body_contacts += 1
	elif body is AnimatableBody2D:
		weapon_contacts += 1

func _process(_delta: float) -> void:
	if not _capture_busy and not _capture_queue.is_empty():
		var request: Dictionary = _capture_queue.pop_front()
		_capture_busy = true
		_begin_capture.call_deferred(request)
	for index in range(groups.size() - 1, -1, -1):
		if not is_instance_valid(groups[index]):
			groups.remove_at(index)
			_release_orphan_captures()
			continue
		var group := groups[index]
		if group.get_child_count() == 0:
			var id := group.get_instance_id()
			if _captures.has(id):
				if is_instance_valid(_captures[id]):
					_captures[id].queue_free()
				_captures.erase(id)
			group.queue_free()
			groups.remove_at(index)
	if groups.is_empty():
		_clear_weapons()

func _physics_process(_delta: float) -> void:
	if groups.is_empty():
		return
	if not _weapons_built:
		_clear_weapons()
		_build_weapons()
		_weapons_built = true
	for weapon in weapons:
		# Validate before typed assignment: Godot rejects a freed object at assignment,
		# and comparing a freed reference to null cannot distinguish a fang proxy.
		var fighter: Variant = weapon["fighter"]
		var body: Variant = weapon["body"]
		if not is_instance_valid(body):
			continue
		if not is_instance_valid(fighter) or not fighter.is_inside_tree() or fighter.current_health <= 0:
			body.collision_layer = 0
			continue
		var ability: Variant = weapon.get("ability")
		if not weapon["fangs"] and (not is_instance_valid(ability) or not ability.is_enabled()):
			body.collision_layer = 0
			continue
		var segment := _weapon_segment(fighter, weapon["index"], ability)
		if segment.size() < 2:
			body.collision_layer = 0
			continue
		body.collision_layer = 8
		body.global_position = (segment[0] + segment[1]) * 0.5
		body.global_rotation = (segment[1] - segment[0]).angle() + PI * 0.5
		var shape: CapsuleShape2D = weapon["shape"]
		var height := maxf(shape.radius * 2.0, segment[0].distance_to(segment[1]) + shape.radius * 2.0)
		if not is_equal_approx(shape.height, height):
			shape.height = height

func _build_weapons() -> void:
	for fighter in fighters:
		if not is_instance_valid(fighter) or fighter.current_health <= 0:
			continue
		for child in fighter.get_children():
			if child is CombatAbility and child.is_enabled():
				for index in child.current_weapon_segments().size():
					_add_weapon_proxy(fighter,index,child)
		if fighter.is_vampire:
			for index in 2:
				_add_weapon_proxy(fighter,index,null)

func _add_weapon_proxy(fighter: ArenaBall, index: int, ability: CombatAbility) -> void:
	var initial_segment := _weapon_segment(fighter, index, ability)
	if initial_segment.size() < 2:
		return
	var body := AnimatableBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 4
	body.sync_to_physics = false
	var shape := CapsuleShape2D.new()
	shape.radius = ability.weapon_radius() if ability != null else 3.5 * fighter.diameter / 70.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = to_local((initial_segment[0] + initial_segment[1]) * 0.5)
	body.rotation = (initial_segment[1] - initial_segment[0]).angle() + PI * 0.5 - global_rotation
	shape.height = maxf(shape.radius * 2.0, initial_segment[0].distance_to(initial_segment[1]) + shape.radius * 2.0)
	add_child(body)
	weapons.append({
		"fighter": fighter, "body": body, "shape": shape, "index": index,
		"ability": ability, "fangs": ability == null,
	})

func _weapon_segment(fighter: ArenaBall, index: int, ability: CombatAbility = null) -> PackedVector2Array:
	if ability != null:
		var segments := ability.current_weapon_segments()
		return segments[index] if index >= 0 and index < segments.size() else PackedVector2Array()
	var fangs := fighter.get_node_or_null("Vampire") as VampireFangs
	if fangs == null or not fighter.is_vampire:
		return PackedVector2Array()
	var pixel_tip := Vector2(447,903) if index == 0 else Vector2(712,923)
	var offset := (pixel_tip - Vector2(626,513)) * fangs.fang_diameter() / 566.0
	var tip := fighter.global_position + offset.rotated(fangs.global_rotation + PI)
	var root := fighter.global_position + (tip - fighter.global_position).normalized() * fighter.diameter * 0.40
	return PackedVector2Array([root,tip])

func _clear_weapons() -> void:
	for weapon in weapons:
		if is_instance_valid(weapon["body"]):
			weapon["body"].queue_free()
	weapons.clear()
	_weapons_built = false


func _release_orphan_captures() -> void:
	for id in _captures.keys():
		if not is_instance_valid(instance_from_id(id)):
			if is_instance_valid(_captures[id]):
				_captures[id].queue_free()
			_captures.erase(id)
