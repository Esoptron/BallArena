@tool
class_name BallArena
extends Node2D
## Playable space is [0, arena_size.x] x [0, arena_size.y], in world units.

@export var arena_size: Vector2 = Vector2(960.0, 600.0):
	set(value):
		arena_size = value
		queue_redraw()
@export_range(4.0, 256.0, 1.0) var ball_diameter: float = 70.0
@export_range(0.0, 2000.0, 1.0) var ball_speed: float = 0.0
@export_range(2.0, 64.0, 1.0) var wall_thickness: float = 12.0
@export var experimental_blood_runoff: bool = true
@export_enum("Ordinary", "Vampire", "Swordsman", "Knifeman", "Katana", "Club") var blue_character: int = 2
@export_enum("Ordinary", "Vampire", "Swordsman", "Knifeman", "Katana", "Club") var red_character: int = 1
## Empty IDs use the legacy editor choices above.
@export var blue_character_id: StringName = &""
@export var red_character_id: StringName = &""
var character_overrides: Dictionary = {}
var battle_roster: Array[Dictionary] = []
var battle_format: StringName = &"teams"
var fighters: Array[ArenaBall] = []
static var _physics_requests: Dictionary = {}
const BALL_SCENE := preload("res://scenes/ball.tscn")
var death_fragments: ArenaDeathFragments
var director: CombatDirector
var resolved_seed: int = 1
@export var randomize_spawns: bool = true
## Zero selects a fresh seed; a nonzero seed reproduces a match start.
@export var spawn_seed: int = 0
@export var floor_color: Color = Color(0.075, 0.095, 0.13)
@export var wall_color: Color = Color(0.32, 0.38, 0.48)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var errors := validation_errors()
	if not errors.is_empty():
		for child in $Balls.get_children():
			if child is ArenaBall:
				child.freeze = true
		process_mode = Node.PROCESS_MODE_DISABLED
		push_error("Cannot start arena: " + "; ".join(errors))
		return
	_create_walls()
	if not battle_roster.is_empty():
		_ready_roster()
		_configure_physics_rate()
		return
	var blue := $Balls/BlueBall as ArenaBall
	var red := $Balls/RedBall as ArenaBall
	blue.position = arena_size * Vector2(0.28, 0.38)
	red.position = arena_size * Vector2(0.72, 0.62)
	blue.experimental_blood_runoff = experimental_blood_runoff
	red.experimental_blood_runoff = experimental_blood_runoff
	blue.actor_id = "blue"
	blue.battle_role = "left"
	blue.team_id = &"blue"
	red.team_id = &"red"
	fighters = [blue,red]
	red.actor_id = "red"
	red.battle_role = "right"
	var legacy := ["ordinary","vampire","swordsman","knifeman","katana","club"]
	_set_character(blue,blue_character_id if not blue_character_id.is_empty() else legacy[blue_character])
	_set_character(red,red_character_id if not red_character_id.is_empty() else legacy[red_character])
	director = CombatDirector.new()
	director.name = "CombatDirector"
	add_child(director)
	director.register(blue)
	director.register(red)
	if randomize_spawns:
		_randomize_start(blue, red)
	else:
		resolved_seed = spawn_seed if spawn_seed != 0 else 1
	director.set_match_seed(resolved_seed)
	blue.opponent = red
	red.opponent = blue
	blue.blood_effects = $BloodEffects
	red.blood_effects = $BloodEffects
	$BloodEffects.floor_y = arena_size.y
	$BloodEffects.arena_width = arena_size.x
	blue.combat_effects = $CombatEffects
	red.combat_effects = $CombatEffects
	blue.health_delta.connect(_show_combat_number.bind(blue))
	red.health_delta.connect(_show_combat_number.bind(red))
	death_fragments = ArenaDeathFragments.new()
	death_fragments.name = "DeathFragments"
	add_child(death_fragments)
	death_fragments.watch(blue)
	death_fragments.watch(red)
	_configure_physics_rate()


func _set_character(fighter: ArenaBall, id: StringName) -> void:
	CharacterCatalog.apply(fighter,CharacterCatalog.character(id,character_overrides.get(String(id),{})),
		ball_diameter,ball_speed)


func _randomize_start(blue: ArenaBall, red: ArenaBall) -> void:
	var rng := RandomNumberGenerator.new()
	if spawn_seed == 0:
		rng.randomize()
	else:
		rng.seed = spawn_seed
	resolved_seed = rng.seed
	var margin := maxf(blue.diameter, red.diameter) * 0.5 + 2.0
	blue.position = Vector2(rng.randf_range(margin, arena_size.x - margin),
		rng.randf_range(margin, arena_size.y - margin))
	# A distant fallback keeps characters separate even if all samples fail.
	red.position = Vector2(arena_size.x - margin if blue.position.x < arena_size.x * 0.5 else margin,
		arena_size.y - margin if blue.position.y < arena_size.y * 0.5 else margin)
	for attempt in 64:
		var candidate := Vector2(rng.randf_range(margin, arena_size.x - margin),
			rng.randf_range(margin, arena_size.y - margin))
		if candidate.distance_to(blue.position) >= maxf(blue.diameter, red.diameter) * 2.2:
			red.position = candidate
			break
	for fighter in [blue, red]:
		fighter.initial_direction = Vector2.from_angle(rng.randf_range(-PI, PI))
		fighter.start_motion()
		(fighter.get_node("Sword") as SwordAbility).rotation = rng.randf_range(-PI, PI)


func _create_walls() -> void:
	var w := arena_size.x
	var h := arena_size.y
	var t := wall_thickness
	# Inner faces coincide exactly with the edges of the playable rectangle.
	_add_wall("Top", Vector2(w * 0.5, -t * 0.5), Vector2(w + t * 2.0, t))
	_add_wall("Bottom", Vector2(w * 0.5, h + t * 0.5), Vector2(w + t * 2.0, t))
	_add_wall("Left", Vector2(-t * 0.5, h * 0.5), Vector2(t, h))
	_add_wall("Right", Vector2(w + t * 0.5, h * 0.5), Vector2(t, h))


func _add_wall(wall_name: String, center: Vector2, wall_size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = center
	wall.add_to_group("walls")
	# The balls supply restitution; walls add no extra bounce or friction.
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	wall.physics_material_override = material
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	collision.shape = rectangle
	wall.add_child(collision)
	$Walls.add_child(wall)


func _draw() -> void:
	var border := Rect2(Vector2.ONE * -wall_thickness,
		arena_size + Vector2.ONE * wall_thickness * 2.0)
	draw_rect(border, wall_color)
	draw_rect(Rect2(Vector2.ZERO, arena_size), floor_color)


func _show_combat_number(amount: int, healing: bool, fighter: ArenaBall) -> void:
	var effects := fighter.combat_effects as ArenaCombatEffects
	if is_instance_valid(effects):
		effects.spawn_number(fighter.global_position,amount,healing)


func _ready_roster() -> void:
	assert(battle_roster.size() >= 2 and battle_roster.size() <= 20,"Battle requires two to twenty fighters.")
	director = CombatDirector.new()
	director.name = "CombatDirector"
	director.group_battle = true
	add_child(director)
	death_fragments = ArenaDeathFragments.new()
	death_fragments.name = "DeathFragments"
	add_child(death_fragments)
	var lineup := battle_roster.duplicate(true)
	# Keep the first two legacy nodes as representatives of opposing teams.
	if battle_format == &"teams":
		for index in range(1,lineup.size()):
			if lineup[index].get("team",&"red") != lineup[0].get("team",&"blue"):
				var other: Dictionary = lineup[index]
				lineup.remove_at(index)
				lineup.insert(1,other)
				break
	for index in lineup.size():
		var entry: Dictionary = lineup[index]
		var fighter: ArenaBall
		if index < 2:
			fighter = $Balls/BlueBall if index == 0 else $Balls/RedBall
		else:
			fighter = BALL_SCENE.instantiate() as ArenaBall
			fighter.name = "Fighter%d" % (index+1)
			$Balls.add_child(fighter)
		fighter.actor_id = "blue" if index == 0 else ("red" if index == 1 else "fighter_%d" % index)
		fighter.team_id = StringName(entry.get("team","blue")) if battle_format == &"teams" else StringName(fighter.actor_id)
		fighter.battle_role = String(fighter.team_id)
		fighter.ball_color = Color(0.16,0.48,1.0) if entry.get("team","blue") == "blue" else Color(1.0,0.16,0.20)
		if battle_format == &"ffa": fighter.ball_color = Color.from_hsv(float(index)/lineup.size(),0.78,1.0)
		fighter.experimental_blood_runoff = experimental_blood_runoff
		_set_character(fighter,StringName(entry.get("character","ordinary")))
		fighter.blood_effects = $BloodEffects
		fighter.combat_effects = $CombatEffects
		fighter.health_delta.connect(_show_combat_number.bind(fighter))
		fighters.append(fighter)
		director.register(fighter)
		death_fragments.watch(fighter)
	$BloodEffects.floor_y = arena_size.y
	$BloodEffects.arena_width = arena_size.x
	var random := RandomNumberGenerator.new()
	if spawn_seed == 0: random.randomize()
	else: random.seed = spawn_seed
	resolved_seed = random.seed
	var columns := ceili(sqrt(fighters.size()*arena_size.x/arena_size.y))
	var rows := ceili(float(fighters.size())/columns)
	var cells: Array[Vector2] = []
	for y in rows:
		for x in columns: cells.append(Vector2((x+0.5)*arena_size.x/columns,(y+0.5)*arena_size.y/rows))
	for index in range(cells.size()-1,0,-1):
		var swap := random.randi_range(0,index)
		var point := cells[index]
		cells[index] = cells[swap]
		cells[swap] = point
	for index in fighters.size():
		var fighter := fighters[index]
		fighter.position = cells[index]+Vector2(random.randf_range(-10,10),random.randf_range(-10,10))
		fighter.initial_direction = Vector2.from_angle(random.randf_range(-PI,PI))
		fighter.start_motion()
	director.set_match_seed(resolved_seed)
	director.refresh_targets()

func _configure_physics_rate() -> void:
	var rate := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second",120))
	for fighter in fighters:
		# Tiny fast custom balls need a smaller step than ordinary playable heroes.
		var required := 240 if fighter.adjusted_movement_speed()/rate > fighter.diameter*.5 else rate
		rate=maxi(rate,required)
	_physics_requests[get_instance_id()]=rate
	_update_global_physics_rate()

static func _update_global_physics_rate() -> void:
	var rate := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second",120))
	for requested in _physics_requests.values():rate=maxi(rate,int(requested))
	Engine.physics_ticks_per_second=rate

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_physics_requests.erase(get_instance_id())
	_update_global_physics_rate()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in character_overrides:
		if not character_overrides[id] is Dictionary:
			errors.append("Character overrides must be dictionaries: %s" % id)
	if not arena_size.is_finite() or not is_finite(ball_diameter) or ball_diameter <= 0.0 \
			or arena_size.x < ball_diameter * 4.0 or arena_size.y < ball_diameter * 4.0:
		errors.append("Each arena dimension must be at least four positive ball diameters.")
	if not is_finite(ball_speed) or ball_speed < 0.0:
		errors.append("Arena speed override must be finite and nonnegative.")
	if not is_finite(wall_thickness) or wall_thickness <= 0.0:
		errors.append("Arena wall thickness must be finite and positive.")
	if not battle_roster.is_empty():
		errors.append_array(BattleRoster.validation_errors(battle_roster, battle_format))
	else:
		var available := CharacterCatalog.ids()
		for id in [blue_character_id, red_character_id]:
			if not id.is_empty() and not available.has(String(id)):
				errors.append("Unknown arena character: %s" % id)
		if (blue_character_id.is_empty() and (blue_character < 0 or blue_character > 5)) \
				or (red_character_id.is_empty() and (red_character < 0 or red_character > 5)):
			errors.append("Legacy arena character index is invalid.")
	if not errors.is_empty():
		return errors
	# A rejected apply() must never leave a running match using scene defaults.
	# Validate each used final profile once, before _ready creates walls/director.
	var used: Dictionary = {}
	if battle_roster.is_empty():
		var legacy := ["ordinary", "vampire", "swordsman", "knifeman", "katana", "club"]
		used[String(blue_character_id) if not blue_character_id.is_empty() else legacy[blue_character]] = true
		used[String(red_character_id) if not red_character_id.is_empty() else legacy[red_character]] = true
	else:
		for entry in battle_roster:
			used[String(entry.get("character", "ordinary"))] = true
	for id in used:
		var template := CharacterCatalog.character(StringName(id))
		var overrides: Dictionary = character_overrides.get(id, {})
		var override_errors := CharacterCatalog.override_validation_errors(template, overrides)
		if not override_errors.is_empty():
			for issue in override_errors:
				errors.append("%s: %s" % [id, issue])
			continue
		var profile := CharacterCatalog.character(StringName(id), overrides)
		for issue in CharacterCatalog.validation_errors(profile, $Balls/BlueBall as ArenaBall):
			errors.append("%s: %s" % [id, issue])
	return errors
