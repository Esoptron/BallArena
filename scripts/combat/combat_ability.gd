@tool
class_name CombatAbility
extends Node2D

var fighter: ArenaBall
var director: CombatDirector
var definition: AbilityDefinition
var ability_id: StringName
var enabled: bool = true
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	fighter = get_parent() as ArenaBall


func configure(settings: AbilityDefinition) -> void:
	definition = settings
	ability_id = settings.ability_id
	for key in settings.parameters:
		assert(key in self, "Unknown ability parameter: %s/%s" % [ability_id,key])
		set(key,settings.parameters[key])


func deactivate() -> void:
	enabled = false
	self_modulate.a = 1.0

func on_match_seed() -> void:
	pass


func reset_runtime() -> void:
	pass


func is_enabled() -> bool:
	return enabled


func combat_step(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and director == null and is_enabled():
		combat_step(delta)


func queue_contact(callback: Callable, fraction: float = 0.0) -> void:
	if director != null:
		director.submit(self,callback,fraction)
	else:
		callback.call()


func emit_event(kind: StringName, victim: ArenaBall = null, extra: Dictionary = {}) -> void:
	if fighter != null:
		fighter.combat_event(kind,victim,ability_id,extra)


func apply_weapon_impact(victim: ArenaBall, direction: Vector2) -> void:
	if definition == null or not is_instance_valid(victim):
		return
	var impulse := victim.receive_weapon_impact(direction, definition.weapon_weight_class, definition.impact_strength)
	if impulse > 0.0:
		emit_event(&"weapon_impact", victim, {"weapon_weight_class": definition.weapon_weight_class,
			"target_weight_class": victim.weight_class, "effective_impulse": impulse,
			"velocity": [victim.linear_velocity.x, victim.linear_velocity.y]})


# Opt-in collision interface for present and future melee weapons. Fangs opt out.
func weapon_segments_at(_fraction: float) -> Array[PackedVector2Array]:
	return []

func weapon_radius() -> float:
	return 0.0

func can_clash() -> bool:
	return is_enabled() and fighter != null and fighter.can_attack() and not weapon_segments_at(1.0).is_empty()

# Shared hit/recharge interfaces for future characters and indicators.
func on_hit_received(_source: ArenaBall, _ability: StringName, _damage: int) -> void:
	pass

func weapon_point_velocity(_position: Vector2) -> Vector2:
	return fighter.linear_velocity

func on_weapon_clash(_other: CombatAbility, _position: Vector2, _relative_velocity: Vector2 = Vector2.ZERO) -> void:
	pass

func cooldown_time_left() -> float:
	return 0.0

func cooldown_full_duration() -> float:
	return 1.0

func cooldown_visual() -> CanvasItem:
	return self

func deflect_weapon(_fraction: float) -> void:
	pass

func emit_weapon_blood(victim: ArenaBall, world_position: Vector2) -> void:
	if is_instance_valid(fighter.blood_effects):
		fighter.blood_effects.call("spawn_hit_blood", world_position)


func can_resolve_clash() -> bool:
	return can_clash()


func on_capture_damage(_source: CombatAbility, _damage: int) -> bool:
	return false

func preferred_movement_direction() -> Vector2:
	return Vector2.ZERO

func movement_speed_multiplier() -> float:
	return 1.0

# Read-only progression interface shared by battle UI and future abilities.
func progression_stats() -> Array[Dictionary]:
	return []

func hostile_targets() -> Array[ArenaBall]:
	if is_instance_valid(director) and director.group_battle:
		return director.opponents_of(fighter)
	var result: Array[ArenaBall] = []
	if is_instance_valid(fighter.opponent): result.append(fighter.opponent)
	return result


func on_relocated() -> void:
	pass


func current_weapon_segments() -> Array[PackedVector2Array]:
	return weapon_segments_at(1.0)


func on_damage_received(_previous_health: int, _damage: int) -> void:
	pass
