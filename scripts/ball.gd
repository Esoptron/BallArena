@tool
class_name ArenaBall
extends RigidBody2D
## A moving circle with health. The collider follows its pulsating body; fangs are non-solid.

signal died(attacker: ArenaBall, ability: StringName)
signal health_changed(value: int, maximum: int)
signal health_delta(amount: int, healing: bool)

const WEIGHTS := preload("res://scripts/combat/weight_classes.gd")
const STATUS_SOURCES := preload("res://scripts/actor/status_sources.gd")
static var _resolved_collision_frame: int = -1
static var _resolved_collision_pairs: Dictionary = {}

const WOUND_LIFETIME := 5.0

@export_range(4.0, 256.0, 1.0) var diameter: float = 70.0:
	set(value):
		diameter = value
		_update_shape()
@export_range(1.0, 2000.0, 1.0) var movement_speed: float = 320.0
@export var ball_color: Color = Color(0.16, 0.48, 1.0):
	set(value):
		ball_color = value
		queue_redraw()
@export var initial_direction: Vector2 = Vector2(1.0, 0.29)
@export var is_vampire: bool = true
@export var is_swordsman: bool = false
## Reference HP for low-health thresholds; healing can exceed this value.
@export_range(1, 10000, 1) var max_health: int = 100
@export_range(1, 10000, 1) var starting_health: int = 100
@export_range(0.0, 1.0, 0.01) var low_health_threshold: float = 0.30
@export_range(0.0, 20.0, 0.1) var pulse_frequency: float = 4.0
@export_range(0.1, 1.0, 0.01) var pulse_minimum_ratio: float = 50.0 / 70.0
@export_range(0.0, 0.15, 0.005) var bite_pulse_amount: float = 0.05
@export_range(0.1, 10.0, 0.1) var bite_pulse_frequency: float = 2.0

var combat_components: Array[CombatAbility] = []
var _shape_node: CollisionShape2D
var actor_id: String = ""
var battle_role: String = ""
var character_id: StringName = &"ordinary"
var character_definition: CharacterDefinition
var combat_director: CombatDirector
var weight_class: int = 2
var movement_scale: float = 1.0
var transport_velocity: Vector2 = Vector2.ZERO
var wall_boost_scale: float = 1.0
var boost_decay_seconds: float = 3.0
var wall_speed_bonus: float = 0.0
var impact_speed_loss: float = 0.0
var impact_speed_bonus: float = 0.0
var _impact_bonus_recovery_rate: float = 0.0
var _impact_recovery_rate: float = 0.0
var _collision_incoming_velocity: Vector2
var _previous_contacts: Dictionary = {}
var capture_immunity_remaining: float = 0.0

var experimental_blood_runoff: bool = true
var current_health: int = 100
var paralysis_remaining: float = 0.0
var team_id: StringName = &""
var opponent: ArenaBall
var blood_effects: Node2D
var combat_effects: Node2D
var _last_direction: Vector2 = Vector2.RIGHT
var _visual_time: float = 0.0
var attack_recovery_remaining: float = 0.0
var _motion_holds: Dictionary = {}
var _status_sources := STATUS_SOURCES.new()
var _relocation_guard_remaining: float = 0.0
var _paralysis_sources: Dictionary = {}
var _protection_sources: Dictionary = {}
var bite_marks: PackedVector2Array = PackedVector2Array()
var bite_marks_remaining: float = 0.0
var wound_bleeding_remaining: float = 0.0
var _wound_drip_elapsed: float = 0.0
var bleeding_stacks: Array[Dictionary] = []
var katana_wound_stage: int = 0
var is_feeding: bool = false
var bite_body_base: float = 70.0
var bite_pulse_elapsed: float = 0.0


func _init() -> void:
	_status_sources.expired.connect(_on_status_source_expired)


func _enter_tree() -> void:
	_status_sources.resume()


func _exit_tree() -> void:
	_status_sources.suspend()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_status_sources.clear()


func _ready() -> void:
	for child in get_children():
		if child is CombatAbility:combat_components.append(child)
	child_entered_tree.connect(_on_component_entered)
	child_exiting_tree.connect(_on_component_exited)
	if actor_id.is_empty():
		actor_id = String(name)
	_update_shape()
	var plain_art := Node2D.new()
	plain_art.name = "OrdinaryBallArt"
	plain_art.show_behind_parent = true
	plain_art.set_script(preload("res://scripts/ordinary_ball_art.gd"))
	add_child(plain_art)
	var art := Node2D.new()
	art.name = "ApprovedVampireArt"
	art.show_behind_parent = true
	art.set_script(preload("res://scripts/approved_vampire_art.gd"))
	add_child(art)
	var runoff := Node2D.new()
	runoff.name = "BloodRunoff"
	runoff.show_behind_parent = true
	runoff.set_script(preload("res://scripts/bite_runoff.gd"))
	add_child(runoff)
	var cut := Node2D.new()
	cut.name = "KatanaWound"
	cut.z_index = 1
	cut.set_script(preload("res://scripts/katana_wound.gd"))
	add_child(cut)
	var rage := Node2D.new()
	rage.name = "BerserkIndicator"
	rage.z_index = 5
	rage.set_script(preload("res://scripts/berserk_indicator.gd"))
	add_child(rage)
	var label := Node2D.new()
	label.name = "HealthDisplay"
	label.z_index = 6
	label.set_script(preload("res://scripts/health_display.gd"))
	add_child(label)
	var recharge := Node2D.new()
	recharge.name = "CooldownIndicator"
	recharge.set_script(preload("res://scripts/cooldown_indicator.gd"))
	add_child(recharge)
	current_health = maxi(starting_health, 1)
	if not Engine.is_editor_hint():
		start_motion()


func configure(new_diameter: float, new_speed: float) -> void:
	diameter = new_diameter
	movement_speed = new_speed
	if not Engine.is_editor_hint():
		start_motion()


func start_motion() -> void:
	impact_speed_loss = 0.0
	impact_speed_bonus = 0.0
	wall_speed_bonus = 0.0
	_previous_contacts.clear()
	_last_direction = initial_direction.normalized()
	if _last_direction.is_zero_approx():
		_last_direction = Vector2.RIGHT
	linear_velocity = _last_direction * effective_movement_speed()
	_collision_incoming_velocity = linear_velocity
	reset_physics_interpolation()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): _visual_time += delta
	# Static body artwork is a sibling canvas item. Only animated statuses need this draw.
	if is_invulnerable() or not bite_marks.is_empty(): queue_redraw()


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_status_sources.prune()
		_advance_bleeding(delta)
		_collision_incoming_velocity = linear_velocity
		advance_wall_boost(delta)
		impact_speed_loss = move_toward(impact_speed_loss,0.0,_impact_recovery_rate*delta)
		impact_speed_bonus = move_toward(impact_speed_bonus,0.0,_impact_bonus_recovery_rate*delta)
		_visual_time += delta
		capture_immunity_remaining = maxf(0.0,capture_immunity_remaining - delta)
		if is_feeding:
			bite_pulse_elapsed += delta
		_sync_pulse_shape()
		_advance_bite_marks(delta)
		attack_recovery_remaining = maxf(0.0, attack_recovery_remaining - delta)
	if Engine.is_editor_hint():
		return
	if paralysis_remaining <= 0.0:
		_paralysis_sources.clear()
		return
	for source in _paralysis_sources.keys():
		_paralysis_sources[source] = maxf(0.0,float(_paralysis_sources[source])-delta)
		if _paralysis_sources[source] <= 0.0:
			_paralysis_sources.erase(source)
			_forget_unused_status_source(source)
	paralysis_remaining = _remaining_paralysis() if not _paralysis_sources.is_empty() else maxf(0.0,paralysis_remaining-delta)
	if paralysis_remaining <= 0.000001:
		paralysis_remaining = 0.0
		_refresh_motion()



func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint():
		return
	# Keep ordinary solver contacts unchanged. Recover only excess penetration,
	# including after the short relocation grace period has expired.
	var relocation_guard := _relocation_guard_remaining > 0.0
	_relocation_guard_remaining = maxf(0.0,_relocation_guard_remaining-state.step)
	var parent := get_parent()
	var arena := parent.get_parent() as BallArena if parent != null else null
	if arena != null and current_health > 0 and (collision_mask & 1) != 0:
		var radius := diameter*0.5 + (1.0 if relocation_guard else 0.0)
		var point := arena.to_local(state.transform.origin)
		var safe := point.clamp(Vector2.ONE*radius,arena.arena_size-Vector2.ONE*radius)
		# The solver permits penetration within a single simulation step. Correcting
		# those ordinary contacts would change reflections and tiny/fast body collisions.
		# Crowded solver impulses can exceed the speed that is normalized below.
		# They must not expand the tolerated penetration beyond one actual step.
		var tolerance := 0.0 if relocation_guard else maxf(2.0,effective_movement_speed()*state.step+0.1)
		var penetration := (point-safe).abs()
		if maxf(penetration.x,penetration.y) > tolerance:
			var velocity := state.linear_velocity.rotated(-arena.global_rotation)
			var outward_x := point.x < safe.x and velocity.x < 0 or point.x > safe.x and velocity.x > 0
			var outward_y := point.y < safe.y and velocity.y < 0 or point.y > safe.y and velocity.y > 0
			if outward_x: velocity.x = -velocity.x
			if outward_y: velocity.y = -velocity.y
			var corrected := state.transform
			corrected.origin = arena.to_global(safe)
			state.transform = corrected
			state.linear_velocity = velocity.rotated(arena.global_rotation)
			if not relocation_guard and (outward_x or outward_y): gain_wall_boost()
	if current_health <= 0 or is_immobilized():
		state.linear_velocity = Vector2.ZERO
		return
	_update_speed_contacts(state)
	var preferred := preferred_movement_direction()
	if not preferred.is_zero_approx():
		_last_direction = preferred.normalized()
	elif not state.linear_velocity.is_zero_approx():
		_last_direction = state.linear_velocity.normalized()
	state.linear_velocity = _last_direction * effective_movement_speed()
	state.angular_velocity = 0.0


func respond_to_capture_damage(source: CombatAbility, damage: int) -> bool:
	if damage <= 0 or current_health <= 0:
		return false
	for child in combat_components:
		if child is CombatAbility and child.is_enabled() and child.on_capture_damage(source,damage):
			return true
	return false

func preferred_movement_direction() -> Vector2:
	for child in combat_components:
		if child is CombatAbility and child.is_enabled():
			var direction: Vector2 = child.preferred_movement_direction()
			if not direction.is_zero_approx():
				return direction
	return Vector2.ZERO

func adjusted_movement_speed() -> float:
	var multiplier := 1.0
	for child in combat_components:
		if child is CombatAbility and child.is_enabled():
			multiplier *= child.movement_speed_multiplier()
	return movement_speed * multiplier

func actual_movement_speed() -> float:
	if current_health <= 0:
		return 0.0
	if is_immobilized():
		return transport_velocity.length()
	return linear_velocity.length()

func effective_movement_speed() -> float:
	var base := adjusted_movement_speed()
	return maxf(base*.15,base + wall_speed_bonus + impact_speed_bonus - impact_speed_loss)

func maximum_wall_bonus() -> float:
	var base := adjusted_movement_speed()
	var weighted_bonus := base * WEIGHTS.wall_boost(weight_class) * wall_boost_scale
	# Do not add tunneling risk to extreme tiny/fast parameter combinations.
	var safe_extra := maxf(0.0,diameter * 0.5 * Engine.physics_ticks_per_second - base - impact_speed_bonus)
	return minf(weighted_bonus,safe_extra)

func advance_wall_boost(delta: float) -> void:
	var maximum := maximum_wall_bonus()
	wall_speed_bonus = move_toward(minf(wall_speed_bonus, maximum),0.0,maximum * delta / boost_decay_seconds)

func gain_wall_boost() -> void:
	if wall_boost_scale <= 0.0 or current_health <= 0 or is_immobilized():
		return
	wall_speed_bonus = maxf(wall_speed_bonus,maximum_wall_bonus())
	combat_event(&"wall_boost",self,&"motion",{"bonus":wall_speed_bonus,"speed":effective_movement_speed()})

func _update_speed_contacts(state: PhysicsDirectBodyState2D) -> void:
	var current_contacts := {}
	for contact in state.get_contact_count():
		var collider := state.get_contact_collider_object(contact)
		if not is_instance_valid(collider):
			continue
		var key := collider.get_instance_id()
		current_contacts[key] = true
		if _previous_contacts.has(key):
			continue
		if collider.is_in_group("walls"):
			gain_wall_boost()
		elif collider is ArenaBall:
			var normal := state.transform.basis_xform(state.get_contact_local_normal(contact)).normalized()
			_resolve_body_speed_collision(collider,normal)
	_previous_contacts = current_contacts

func _resolve_body_speed_collision(other: ArenaBall, normal: Vector2) -> void:
	if current_health <= 0 or other.current_health <= 0 or is_immobilized() or other.is_immobilized():
		return
	var frame := Engine.get_physics_frames()
	if _resolved_collision_frame != frame:
		_resolved_collision_frame = frame
		_resolved_collision_pairs.clear()
	var key := "%s:%s" % [mini(get_instance_id(),other.get_instance_id()),maxi(get_instance_id(),other.get_instance_id())]
	if _resolved_collision_pairs.has(key):
		return
	_resolved_collision_pairs[key] = true
	var incoming := _collision_incoming_velocity
	var other_incoming := other._collision_incoming_velocity
	var total_speed := incoming.length() + other_incoming.length()
	if total_speed <= 0.00001:
		return
	# The normal closing component measures head-on versus glancing contact.
	var strength := clampf(absf((incoming - other_incoming).dot(normal)) / total_speed,0.0,1.0)
	if strength >= 0.999:
		strength = 1.0
	var own_loss := WEIGHTS.boost_loss(weight_class,other.weight_class,strength)
	var other_loss := WEIGHTS.boost_loss(other.weight_class,weight_class,strength)
	var before := wall_speed_bonus
	var other_before := other.wall_speed_bonus
	wall_speed_bonus *= 1.0 - own_loss
	other.wall_speed_bonus *= 1.0 - other_loss
	# Do not write another body during its solver callback: preserve its bounce.
	other._sync_dynamic_speed.call_deferred()
	combat_event(&"collision_slowdown",other,&"motion",{"strength":strength,"loss":own_loss,
		"other_loss":other_loss,"bonus_before":before,"other_bonus_before":other_before,"bonus":wall_speed_bonus,"other_bonus":other.wall_speed_bonus})


func _sync_dynamic_speed() -> void:
	if current_health > 0 and not is_immobilized() and not linear_velocity.is_zero_approx():
		linear_velocity = linear_velocity.normalized() * effective_movement_speed()


func receive_weapon_impact(direction: Vector2, weapon_class: int, strength: float) -> float:
	if current_health <= 0 or is_immobilized() or is_invulnerable() or direction.is_zero_approx() or strength <= 0.0:
		return 0.0
	var effective_impulse := strength * WEIGHTS.factor(weapon_class) / WEIGHTS.factor(weight_class)
	var incoming := linear_velocity if not linear_velocity.is_zero_approx() else _last_direction * effective_movement_speed()
	var redirected := incoming + direction.normalized() * effective_impulse
	if redirected.is_zero_approx():
		redirected = direction
	_last_direction = redirected.normalized()
	# Weapon impacts redirect travel while retaining the current wall-speed bonus.
	linear_velocity = _last_direction * effective_movement_speed()
	return effective_impulse


func receive_weapon_clash_impact(direction: Vector2, weapon_class: int, strength: float, recovery: float, bonus_limit: float = 2.0, minimum_speed_ratio: float = 0.0) -> float:
	if current_health <= 0 or is_immobilized() or is_invulnerable() or direction.is_zero_approx() or strength <= 0: return 0.0
	var impulse := strength*WEIGHTS.factor(weapon_class)/WEIGHTS.factor(weight_class)
	var redirected := linear_velocity+direction.normalized()*impulse
	var base := adjusted_movement_speed()
	var budget := base+wall_speed_bonus
	var extra := minf(base*maxf(0.0,bonus_limit),maxf(0.0,diameter*.5*Engine.physics_ticks_per_second-budget))
	if redirected.is_zero_approx(): redirected = direction.normalized()*base*.15
	var speed := clampf(maxf(redirected.length(),base*minimum_speed_ratio),base*.15,budget+extra)
	impact_speed_bonus = maxf(0.0,speed-budget)
	impact_speed_loss = maxf(0.0,budget-speed)
	_impact_bonus_recovery_rate = impact_speed_bonus/maxf(.01,recovery)
	_impact_recovery_rate = impact_speed_loss/maxf(.01,recovery)
	_last_direction = redirected.normalized()
	linear_velocity = _last_direction*effective_movement_speed()
	return impulse

func receive_heavy_weapon_impact(normal: Vector2, surface_velocity: Vector2, weapon_class: int, restitution: float, recovery: float, max_impulse: float = INF) -> float:
	if current_health <= 0 or is_immobilized() or is_invulnerable() or normal.is_zero_approx(): return 0.0
	var incoming := linear_velocity
	var closing := (incoming-surface_velocity).dot(normal)
	if closing >= 0.0: return 0.0 # No extra impulse when separating or moving tangentially.
	var weapon_mass := WEIGHTS.factor(weapon_class)
	var own_mass := WEIGHTS.factor(weight_class)
	var impulse := -(1.0+restitution)*closing*weapon_mass/(own_mass+weapon_mass)
	impulse = minf(impulse,maxf(0.0,max_impulse)*weapon_mass/own_mass)
	if impulse <= 0: return 0.0
	var redirected := incoming+normal*impulse
	var budget := adjusted_movement_speed()+wall_speed_bonus
	if redirected.is_zero_approx(): redirected = normal*budget*.15
	var speed := clampf(redirected.length(),adjusted_movement_speed()*.15,budget)
	impact_speed_bonus = 0.0
	impact_speed_loss = maxf(0.0,budget-speed)
	_impact_recovery_rate = impact_speed_loss/maxf(.01,recovery)
	_last_direction = redirected.normalized()
	linear_velocity = _last_direction*effective_movement_speed()
	return impulse

func is_paralyzed() -> bool:
	return paralysis_remaining > 0.0


func can_attack() -> bool:
	return current_health > 0 and not is_immobilized() and attack_recovery_remaining <= 0.0


func can_start_bite() -> bool:
	return is_vampire and can_attack()


func prevent_attacks(duration: float) -> void:
	attack_recovery_remaining = maxf(attack_recovery_remaining, duration)


func paralyze(duration: float, source: Node = null) -> void:
	if current_health <= 0 or duration <= 0.0:
		return
	if not linear_velocity.is_zero_approx():
		_last_direction = linear_velocity.normalized()
	var source_id := source.get_instance_id() if is_instance_valid(source) else 0
	_status_sources.track(source)
	_paralysis_sources[source_id] = maxf(float(_paralysis_sources.get(source_id,0.0)),duration)
	paralysis_remaining = maxf(paralysis_remaining, duration)
	freeze = true
	linear_velocity = Vector2.ZERO


func _remaining_paralysis() -> float:
	var remaining := 0.0
	for value in _paralysis_sources.values():
		remaining = maxf(remaining,float(value))
	return remaining


func cancel_paralysis(source: Node) -> void:
	if not is_instance_valid(source):
		return
	var source_id := source.get_instance_id()
	_paralysis_sources.erase(source_id)
	_forget_unused_status_source(source_id)
	paralysis_remaining = _remaining_paralysis()
	_refresh_motion()


func combat_event(kind: StringName, target: ArenaBall = null, ability: StringName = &"external", extra: Dictionary = {}) -> void:
	if is_instance_valid(combat_director):
		combat_director.record(kind,self,target,ability,extra)


func grant_capture_immunity(duration: float) -> void:
	capture_immunity_remaining = maxf(capture_immunity_remaining,duration)
	combat_event(&"capture_immunity",self,&"state",{"duration":duration})


func take_damage(amount: int, source: ArenaBall = null, ability: StringName = &"external", direct_hit: bool = true) -> int:
	if current_health <= 0:
		return 0
	var actor := source if is_instance_valid(source) else self
	if is_invulnerable():
		actor.combat_event(&"blocked",self,ability,{"reason":"invulnerable","requested":amount})
		return 0
	var applied := mini(maxi(amount, 0), current_health)
	current_health -= applied
	if applied > 0:
		for child in combat_components:
			if child is CombatAbility and child.is_enabled():
				child.on_damage_received(current_health+applied,applied)
		if direct_hit and actor != self and (combat_director == null or combat_director.are_enemies(actor,self)):
			for child in combat_components:
				if child.is_enabled(): child.on_hit_received(actor,ability,applied)
		_sync_dynamic_speed()
		health_changed.emit(current_health, max_health)
		health_delta.emit(applied, false)
		actor.combat_event(&"damage",self,ability,{"amount":applied,"requested":amount})
	if current_health == 0 and applied > 0:
		clear_bleeding()
		freeze = true
		linear_velocity = Vector2.ZERO
		died.emit(actor, ability)
	return applied


# Shared status API: any future ability can hold motion or grant protection.
func is_immobilized() -> bool:
	return is_paralyzed() or not _motion_holds.is_empty()


func is_invulnerable() -> bool:
	return not _protection_sources.is_empty()


func hold_motion(source: Node) -> void:
	if not is_instance_valid(source):
		return
	_status_sources.track(source)
	_motion_holds[source.get_instance_id()] = true
	freeze = true
	linear_velocity = Vector2.ZERO


func release_motion(source: Node, departure: Vector2) -> void:
	if not is_instance_valid(source):
		return
	var source_id := source.get_instance_id()
	_motion_holds.erase(source_id)
	_forget_unused_status_source(source_id)
	if not departure.is_zero_approx():
		_last_direction = departure.normalized()
	_refresh_motion()


func set_invulnerable(source: Node, enabled: bool) -> void:
	if not is_instance_valid(source):
		return
	var source_id := source.get_instance_id()
	if enabled:
		_status_sources.track(source)
		_protection_sources[source_id] = true
	else:
		_protection_sources.erase(source_id)
		_forget_unused_status_source(source_id)
	queue_redraw()


func _forget_unused_status_source(source_id: int) -> void:
	if not _motion_holds.has(source_id) and not _protection_sources.has(source_id) and not _paralysis_sources.has(source_id):
		_status_sources.forget(source_id)


func _on_status_source_expired(source_id: int) -> void:
	var released_motion := _motion_holds.erase(source_id)
	var released_paralysis := _paralysis_sources.erase(source_id)
	var released_protection := _protection_sources.erase(source_id)
	if released_paralysis:
		paralysis_remaining = _remaining_paralysis()
	if is_inside_tree() and (released_motion or released_paralysis):
		_refresh_motion()
	if released_protection:
		queue_redraw()


func _refresh_motion() -> void:
	freeze = current_health <= 0 or is_immobilized()
	if not freeze:
		linear_velocity = _last_direction * effective_movement_speed()
		reset_physics_interpolation()


func body_color() -> Color:
	if current_health <= 0 and not Engine.is_editor_hint():
		return ball_color.darkened(0.65)
	if is_paralyzed():
		return ball_color.darkened(0.55)
	return ball_color


func apply_bite_marks(attacker_position: Vector2, fang_spacing: float) -> void:
	var facing := (attacker_position - global_position).normalized()
	if facing.is_zero_approx():
		facing = Vector2.LEFT
	var tangent := facing.orthogonal()
	var half_spacing := fang_spacing * 0.5
	var radius := visual_diameter() * 0.5 - 6.0
	var depth := sqrt(maxf(0.0, radius * radius - half_spacing * half_spacing))
	bite_marks = PackedVector2Array([
		to_local(global_position + facing * depth + tangent * half_spacing),
		to_local(global_position + facing * depth - tangent * half_spacing),
	])
	bite_marks_remaining = WOUND_LIFETIME
	wound_bleeding_remaining = 2.0
	_wound_drip_elapsed = 0.0
	var runoff := get_node_or_null("BloodRunoff")
	if experimental_blood_runoff and runoff != null:
		runoff.call("start", bite_marks, visual_diameter() * 0.5)
	queue_redraw()


func _advance_bite_marks(delta: float) -> void:
	bite_marks_remaining = maxf(0.0, bite_marks_remaining - delta)
	var bleeding_step := minf(delta, wound_bleeding_remaining)
	wound_bleeding_remaining = maxf(0.0, wound_bleeding_remaining - delta)
	_wound_drip_elapsed += bleeding_step
	while _wound_drip_elapsed + 0.000001 >= 0.4:
		_wound_drip_elapsed -= 0.4
		if not experimental_blood_runoff and is_instance_valid(blood_effects):
			for point in bite_marks:
				blood_effects.call("spawn_drop", to_global(point), 4.2)
	if bite_marks_remaining <= 0.0:
		bite_marks.clear()


func heal(amount: int, source: ArenaBall = null, ability: StringName = &"external") -> int:
	if current_health <= 0:
		return 0
	var applied := maxi(amount, 0)
	current_health += applied
	if applied > 0:
		_sync_dynamic_speed()
		health_changed.emit(current_health, max_health)
		health_delta.emit(applied, true)
		var actor := source if is_instance_valid(source) else self
		actor.combat_event(&"heal",self,ability,{"amount":applied})
	return applied


func has_low_health() -> bool:
	var health := starting_health if Engine.is_editor_hint() else current_health
	return health > 0 and float(health) / max_health < low_health_threshold


func begin_feeding(base_diameter: float) -> void:
	bite_body_base = base_diameter
	bite_pulse_elapsed = 0.0
	is_feeding = true


func end_feeding() -> void:
	is_feeding = false


func visual_diameter() -> float:
	if is_feeding:
		var breath := (1.0 - cos(bite_pulse_elapsed * TAU * bite_pulse_frequency)) * 0.5
		return bite_body_base * (1.0 - bite_pulse_amount * breath)
	if not is_vampire or not has_low_health():
		return diameter
	var wave := (1.0 - cos(_visual_time * TAU * pulse_frequency)) * 0.5
	return diameter * lerpf(1.0, pulse_minimum_ratio, wave)


func _sync_pulse_shape() -> void:
	var collision := _cached_shape()
	if collision != null:
		var circle := collision.shape as CircleShape2D
		var desired_radius := visual_diameter() * 0.5
		if circle != null and not is_equal_approx(circle.radius, desired_radius):
			circle.radius = desired_radius


func _update_shape() -> void:
	var collision := _cached_shape()
	if collision != null:
		var circle := CircleShape2D.new()
		circle.radius = diameter * 0.5
		collision.shape = circle
	queue_redraw()


func _draw() -> void:
	var radius := visual_diameter() * 0.5

	for point in bite_marks:
		_draw_puncture(point, maxf(2.5, diameter * 0.073))
	if is_invulnerable():
		_draw_protection(radius)


func _draw_protection(radius: float) -> void:
	# A breathing luminous seal, with three orbiting segments: shared by all characters.
	var pulse := 0.5 + 0.5 * sin(_visual_time * TAU * 2.5)
	var shield_radius := radius + 6.0 + 2.0 * pulse
	draw_arc(Vector2.ZERO, shield_radius, 0.0, TAU, 96,
		Color(0.32, 0.94, 1.0, 0.10 + 0.10 * pulse), 9.0, true)
	draw_arc(Vector2.ZERO, shield_radius, 0.0, TAU, 96,
		Color(0.65, 1.0, 1.0, 0.6 + 0.3 * pulse), 1.7, true)
	for index in 3:
		var angle := _visual_time * 2.4 + float(index) * TAU / 3.0
		draw_arc(Vector2.ZERO, shield_radius + 3.0, angle, angle + TAU * 0.19,
			24, Color(0.56, 0.98, 1.0, 0.9), 3.3, true)
		var tip := Vector2.from_angle(angle + TAU * 0.19) * (shield_radius + 3.0)
		draw_circle(tip, 2.4, Color(0.90, 1.0, 1.0))


func wound_opacity() -> float:
	return clampf(bite_marks_remaining / WOUND_LIFETIME, 0.0, 1.0)


func _draw_puncture(point: Vector2, radius: float) -> void:
	var alpha := wound_opacity()
	var rim := PackedVector2Array()
	for index in 18:
		var angle := float(index) * TAU / 18.0
		var irregular := 1.0 + 0.07 * sin(float(index) * 2.3)
		rim.append(point + Vector2(cos(angle), sin(angle) * 0.85) * radius * irregular)
	draw_colored_polygon(rim, Color(0.18, 0.004, 0.022, alpha))
	draw_circle(point + Vector2(0.0, radius * 0.09), radius * 0.76, Color(0.035, 0.001, 0.006, alpha))
	draw_arc(point + Vector2(0.0, radius * 0.04), radius * 0.78,
		0.1, PI - 0.1, 16, Color(0.56, 0.018, 0.045, alpha), radius * 0.24, true)
	draw_arc(point, radius * 0.88, -PI + 0.3, -PI * 0.4,
		12, Color(0.92, 0.18, 0.21, alpha), radius * 0.09, true)


func emit_katana_wound_blood(count: int = 1) -> void:
	if not is_instance_valid(blood_effects):
		return
	var cut := get_node_or_null("KatanaWound")
	if cut == null:
		return
	var segment: PackedVector2Array = cut.call("emission_segment")
	blood_effects.call("spawn_wound_blood", segment[0], segment[1], count)

func deepen_katana_wound() -> void:
	katana_wound_stage = mini(4, katana_wound_stage + 1)
	var cut := get_node_or_null("KatanaWound")
	if cut != null:
		cut.call("_process", 0.0)


# Shared lasting status. Each critical adds an independent one-second clock.
func add_bleeding(source: ArenaBall, tick_damage: int = 1, interval: float = 1.0, source_ability: StringName = &"bleed") -> void:
	if current_health <= 0 or not is_instance_valid(source) or (is_instance_valid(combat_director) and combat_director.match_over):
		return
	bleeding_stacks.append({"source":weakref(source),"damage":tick_damage,"interval":maxf(0.01,interval),
		"elapsed":0.0,"ability":source_ability})
	source.combat_event(&"bleeding_added",self,source_ability,{"stacks":bleeding_stacks.size(),"tick_damage":tick_damage,"interval":interval})
	queue_redraw()

func clear_bleeding() -> void:
	bleeding_stacks.clear()
	queue_redraw()

func _advance_bleeding(delta: float) -> void:
	if bleeding_stacks.is_empty():
		return
	if current_health <= 0:
		clear_bleeding()
		return
	for stack in bleeding_stacks.duplicate():
		stack["elapsed"] += delta
		while stack["elapsed"] + 0.000001 >= stack["interval"]:
			stack["elapsed"] = maxf(0.0,float(stack["elapsed"]) - float(stack["interval"]))
			var source := stack["source"].get_ref() as ArenaBall
			var applied := take_damage(stack["damage"],source,stack["ability"],false)
			if applied > 0 and is_instance_valid(blood_effects):
				if stack["ability"] == &"katana":
					emit_katana_wound_blood()
				else:
					blood_effects.call("spawn_drop",global_position + Vector2.DOWN * visual_diameter() * 0.48,4.2)
			if current_health <= 0 or bleeding_stacks.is_empty():
				return


func protect_relocation() -> void:
	# Only special relocations need this brief guard against stale broadphase contacts.
	_relocation_guard_remaining = 0.25
	_previous_contacts.clear()
	_collision_incoming_velocity = linear_velocity
	for child in combat_components:
		if child is CombatAbility and child.is_enabled():
			child.on_relocated()
	PhysicsServer2D.body_set_state(get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,global_transform)
	reset_physics_interpolation()

func _cached_shape() -> CollisionShape2D:
	if not is_instance_valid(_shape_node):_shape_node=get_node_or_null("CollisionShape2D") as CollisionShape2D
	return _shape_node

func _on_component_entered(child: Node) -> void:
	if child is CombatAbility and not combat_components.has(child):combat_components.append(child)

func _on_component_exited(child: Node) -> void:
	if child is CombatAbility:combat_components.erase(child)
