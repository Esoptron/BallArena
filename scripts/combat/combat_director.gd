class_name CombatDirector
extends Node

signal event_recorded(event: Dictionary)
signal match_finished(winning_team: StringName)
var group_battle: bool = false
var match_over: bool = false
var fighters: Array[ArenaBall] = []
var time_seconds: float = 0.0
var abilities: Array[CombatAbility] = []
var pending: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var priorities: Dictionary = {}
var _clash_pairs: Dictionary = {}
var _slots: Array[String] = []
var _sweep_data: Dictionary = {}
var _scanning_clashes := false
var _contact_gap := INF
var _match_seed: int = 0
var _has_match_seed: bool = false


func _ready() -> void:
	process_physics_priority = 100


func set_match_seed(value: int) -> void:
	_match_seed = value
	_has_match_seed = true
	rng.seed = value
	for ability in abilities:
		if is_instance_valid(ability) and is_instance_valid(ability.fighter):
			_seed_ability(ability)


func _seed_ability(ability: CombatAbility) -> void:
	var fighter := ability.fighter
	var identity := String(fighter.character_id) + fighter.battle_role
	if group_battle:
		identity += fighter.actor_id
	ability.rng.seed = _match_seed ^ (identity + String(ability.ability_id)).hash()
	ability.on_match_seed()


## Idempotent registration also discovers components added by a new profile.
func register(fighter: ArenaBall) -> void:
	if not is_instance_valid(fighter):
		return
	if is_instance_valid(fighter.combat_director) and fighter.combat_director != self:
		fighter.combat_director.unregister(fighter)
	if not fighters.has(fighter):
		fighters.append(fighter)
	if not _slots.has(fighter.actor_id):
		_slots.append(fighter.actor_id)
		_slots.sort()
	if not fighter.died.is_connected(_on_match_death):
		fighter.died.connect(_on_match_death)
	var exiting := _on_fighter_exiting.bind(fighter)
	if not fighter.tree_exiting.is_connected(exiting):
		fighter.tree_exiting.connect(exiting)
	fighter.combat_director = self
	for child in fighter.get_children():
		if child is CombatAbility:
			child.director = self
			if not abilities.has(child):
				abilities.append(child)
				child.tree_exiting.connect(_on_ability_exiting.bind(child))
				if _has_match_seed:
					_seed_ability(child)


func unregister(fighter: ArenaBall) -> void:
	fighters.erase(fighter)
	for ability in abilities.duplicate():
		if not is_instance_valid(ability):
			abilities.erase(ability)
		elif ability.fighter == fighter:
			_unregister_ability(ability)
	if not is_instance_valid(fighter):
		return
	if fighter.died.is_connected(_on_match_death):
		fighter.died.disconnect(_on_match_death)
	var exiting := _on_fighter_exiting.bind(fighter)
	if fighter.tree_exiting.is_connected(exiting):
		fighter.tree_exiting.disconnect(exiting)
	if fighter.combat_director == self:
		fighter.combat_director = null
	if not fighters.any(func(other: ArenaBall) -> bool:
		return is_instance_valid(other) and other.actor_id == fighter.actor_id):
		_slots.erase(fighter.actor_id)
	priorities.erase(fighter.actor_id)


func _unregister_ability(ability: CombatAbility) -> void:
	abilities.erase(ability)
	var id := ability.get_instance_id()
	if ability.director == self:
		ability.director = null
	var exiting := _on_ability_exiting.bind(ability)
	if ability.tree_exiting.is_connected(exiting):
		ability.tree_exiting.disconnect(exiting)
	for index in range(pending.size() - 1, -1, -1):
		var queued = pending[index]["ability"]
		if not is_instance_valid(queued) or queued == ability:
			pending.remove_at(index)
	for key in _clash_pairs.keys():
		var pair := String(key).split(":")
		if int(pair[0]) == id or int(pair[1]) == id:
			_clash_pairs.erase(key)
	_sweep_data.erase(id)


func _on_ability_exiting(ability: CombatAbility) -> void:
	_unregister_ability(ability)


func _on_fighter_exiting(fighter: ArenaBall) -> void:
	unregister(fighter)


func _exit_tree() -> void:
	for fighter in fighters.duplicate():
		unregister(fighter)


func submit(ability: CombatAbility, callback: Callable, fraction: float) -> void:
	if not is_instance_valid(ability) or not is_instance_valid(ability.fighter) \
			or not callback.is_valid() or not is_finite(fraction):
		return
	pending.append({"ability":ability,"callback":callback,
		"fraction":clampf(fraction,0.0,1.0),"tie":priorities.get(ability.fighter.actor_id,0.5)})


func _physics_process(delta: float) -> void:
	time_seconds += delta
	if group_battle: refresh_targets()
	priorities.clear()
	# Slot IDs have a seeded random initiative; scene traversal never decides a tie.
	for slot in _slots:
		priorities[slot] = rng.randf()
	for ability in abilities:
		if is_instance_valid(ability) and ability.is_enabled() and ability.is_physics_processing():
			ability.combat_step(delta)
	_queue_weapon_clashes()
	pending.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a["fraction"] != b["fraction"]:
			return a["fraction"] < b["fraction"]
		return a["tie"] < b["tie"])
	var batch := pending
	pending = []
	for action in batch:
		if is_instance_valid(action["ability"]) and action["ability"].director == self \
				and action["ability"].is_enabled() and action["callback"].is_valid():
			action["callback"].call()


func record(kind: StringName, source: ArenaBall, target: ArenaBall, ability: StringName, extra: Dictionary) -> void:
	if not is_instance_valid(source):
		return
	var event := {"time":time_seconds,"kind":String(kind),"actor_id":source.actor_id,
		"character_id":String(source.character_id),"target_id":target.actor_id if is_instance_valid(target) else "",
		"ability_id":String(ability)}
	event.merge(extra,true)
	event_recorded.emit(event)


func _queue_weapon_clashes() -> void:
	var candidates: Array[CombatAbility] = []
	for ability in abilities:
		if is_instance_valid(ability) and ability.is_physics_processing() and ability.can_clash():
			candidates.append(ability)
	_sweep_data.clear()
	if candidates.size() < 2:
		_clash_pairs.clear()
		return
	_scanning_clashes = true
	var bounds: Dictionary = {}
	for ability in candidates:
		var first := ability.weapon_segments_at(0.0)
		var last := ability.weapon_segments_at(1.0)
		var center := ability.fighter.global_position
		var motion := ability.weapon_sweep_motion()
		var start_center: Vector2 = motion.get("start_position", center)
		var reach := 0.0
		for segment in last:
			for point in segment: reach = maxf(reach,point.distance_to(center))
		var travel := start_center.distance_to(center)
		if not motion.is_empty():
			travel += float(motion["angle"]) * reach
		else:
			for index in mini(first.size(),last.size()):
				travel += maxf(first[index][0].distance_to(last[index][0]),first[index][1].distance_to(last[index][1]))
		_sweep_data[ability.get_instance_id()] = {"first":first,"last":last,"travel":travel}
		bounds[ability.get_instance_id()] = _weapon_sweep_bounds(ability)
	var live_pairs := {}
	for first in candidates.size():
		for second in range(first + 1, candidates.size()):
			var a := candidates[first]
			var b := candidates[second]
			if not are_enemies(a.fighter,b.fighter) or not bounds[a.get_instance_id()].intersects(bounds[b.get_instance_id()]):
				continue
			var key := "%s:%s" % [mini(a.get_instance_id(),b.get_instance_id()),maxi(a.get_instance_id(),b.get_instance_id())]
			live_pairs[key] = true
			if _clash_pairs.has(key):
				if not _weapon_contact(a,b,0.0).is_empty():
					continue
				_clash_pairs.erase(key)
			var travel: float = _sweep_data[a.get_instance_id()]["travel"] + _sweep_data[b.get_instance_id()]["travel"]
			var fraction := 0.0
			for iteration in 96:
				var contact := _weapon_contact(a,b,fraction)
				if not contact.is_empty():
					pending.append({"ability":a,"fraction":fraction,"tie":-1.0,
						"callback":_resolve_weapon_clash.bind(a,b,fraction,contact["position"],key)})
					break
				if travel < 0.00001 or fraction >= 1.0: break
				fraction += maxf(0.000001,_contact_gap/travel*0.95)
				if fraction > 1.0: break
	_scanning_clashes = false
	for key in _clash_pairs.keys():
		if not live_pairs.has(key):
			_clash_pairs.erase(key)

func _weapon_sweep_bounds(ability: CombatAbility) -> Rect2:
	var position := ability.fighter.global_position
	var reach := 0.0
	var result := Rect2(position,Vector2.ZERO)
	for fraction in [0.0,1.0]:
		for segment in _sweep_segments(ability,fraction):
			for point in segment:
				result=result.expand(point)
				if fraction == 1.0:reach=maxf(reach,point.distance_to(position))
	var motion := ability.weapon_sweep_motion()
	if not motion.is_empty():
		var angle: float = motion["angle"]
		if angle <= PI:
			# Linear interpolation error is bounded by max(|p''|)/8.
			# Translation is linear; rotation contributes radius * angle^2 / 8.
			return result.grow(reach*angle*angle/8.0+ability.weapon_radius()+0.025)
		return Rect2(motion["start_position"],Vector2.ZERO).expand(position).grow(reach+ability.weapon_radius()+0.025)
	return result.grow(reach+ability.weapon_radius()+0.025)

func _sweep_segments(ability: CombatAbility,fraction: float) -> Array[PackedVector2Array]:
	if _scanning_clashes and _sweep_data.has(ability.get_instance_id()):
		if fraction == 0.0: return _sweep_data[ability.get_instance_id()]["first"]
		if fraction == 1.0: return _sweep_data[ability.get_instance_id()]["last"]
	return ability.weapon_segments_at(fraction)

func _weapon_contact(a: CombatAbility, b: CombatAbility, fraction: float) -> Dictionary:
	var radius := a.weapon_radius() + b.weapon_radius() + 0.025
	var first := _sweep_segments(a,fraction)
	var second := _sweep_segments(b,fraction)
	var nearest := INF
	var middle := Vector2.ZERO
	for sa in first:
		for sb in second:
			var intersection = Geometry2D.segment_intersects_segment(sa[0],sa[1],sb[0],sb[1])
			if intersection != null:
				_contact_gap = 0.0
				return {"position":intersection}
			for index in 4:
				var endpoint: Vector2 = sa[index] if index < 2 else sb[index-2]
				var point := Geometry2D.get_closest_point_to_segment(endpoint,sb[0] if index < 2 else sa[0],sb[1] if index < 2 else sa[1])
				var distance := point.distance_squared_to(endpoint)
				if distance < nearest:
					nearest = distance
					middle = (point+endpoint)*0.5
	_contact_gap = sqrt(nearest)-radius
	return {"position":middle} if _contact_gap <= 0.00001 else {}

func _resolve_weapon_clash(a: CombatAbility, b: CombatAbility, fraction: float, position: Vector2, key: String) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b) or not a.can_resolve_clash() or not b.can_resolve_clash():
		return
	if _clash_pairs.has(key):
		return
	_clash_pairs[key] = true
	# Snapshot both velocities before either hook changes a body (symmetric club duels).
	var relative_velocity := a.weapon_point_velocity(position)-b.weapon_point_velocity(position)
	a.on_weapon_clash(b,position,relative_velocity)
	b.on_weapon_clash(a,position,-relative_velocity)
	a.deflect_weapon(fraction)
	b.deflect_weapon(fraction)
	a.emit_event(&"weapon_clash",b.fighter,{"other_ability":String(b.ability_id)})
	var effects := a.fighter.combat_effects
	if is_instance_valid(effects):
		effects.call("spawn_sparks",position)


func are_enemies(a: ArenaBall,b: ArenaBall) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and a != b and (not group_battle or a.team_id != b.team_id)

func opponents_of(fighter: ArenaBall) -> Array[ArenaBall]:
	var targets: Array[ArenaBall] = []
	for other in fighters:
		if is_instance_valid(other) and other.current_health > 0 and are_enemies(fighter,other):
			targets.append(other)
	return targets

func refresh_targets() -> void:
	var living: Array[ArenaBall] = []
	var positions := PackedVector2Array()
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.current_health > 0:
			living.append(fighter)
			positions.append(fighter.global_position)
	for index in living.size():
		var fighter := living[index]
		var nearest: ArenaBall
		var distance := INF
		for other in living.size():
			if not are_enemies(fighter,living[other]):continue
			var current := positions[index].distance_squared_to(positions[other])
			if current < distance:
				distance=current
				nearest=living[other]
		fighter.opponent=nearest

func _on_match_death(_attacker: ArenaBall, _ability: StringName) -> void:
	if match_over: return
	var alive_teams: Dictionary = {}
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.current_health > 0:
			alive_teams[fighter.team_id] = true
	if group_battle and alive_teams.size() > 1: return
	match_over = true
	for fighter in fighters:
		if is_instance_valid(fighter): fighter.clear_bleeding()
	var winner: StringName = &""
	if alive_teams.size() == 1: winner = alive_teams.keys()[0]
	match_finished.emit(winner)
