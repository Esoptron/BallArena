class_name CampaignBall
extends ArenaBall
## Campaign-only state, fixed-point HP, bounded effects and dynamic vampire peak.
var campaign_base_max: int = 20000
var campaign_effective_max: int = 20000
var campaign_bonuses: Dictionary = {}
var campaign_effects: Array[Dictionary] = []
var rotation_multiplier: float = 1.0
var movement_multiplier: float = 1.0
var damage_type: StringName = &"physical"
var resistances: Dictionary = {}
var shield_sector: Dictionary = {}
var wall_burst: Dictionary = {}
var _last_campaign_effects := false

func _ready() -> void:
	super._ready()
	get_node("HealthDisplay").set_script(preload("res://scripts/campaign/combat/health_display.gd"))

func heal(amount: int, source: ArenaBall = null, ability: StringName = &"external") -> int:
	var allowed := maxi(0, amount) if is_vampire else mini(maxi(0, amount), maxi(0, campaign_effective_max - current_health))
	var applied := super.heal(allowed, source, ability)
	if is_vampire:
		campaign_effective_max = maxi(campaign_effective_max, current_health)
	return applied

func take_damage(amount: int, source: ArenaBall = null, ability: StringName = &"external", direct_hit: bool = true) -> int:
	if is_instance_valid(source) and source != self and is_instance_valid(combat_director) and not combat_director.are_enemies(source, self):
		return 0
	var adjusted := maxi(0, amount)
	if direct_hit and not shield_sector.is_empty() and is_instance_valid(source):
		var facing: Vector2 = shield_sector.get("facing", Vector2.RIGHT)
		var incoming := (source.global_position - global_position).normalized()
		if incoming.dot(facing) >= float(shield_sector.get("cos_angle", 0.55)):
			adjusted = roundi(adjusted * (1.0 - float(shield_sector.get("reduction", 0.35))))
			combat_event(&"sector_block", source, &"shield", {"prevented": amount - adjusted})
	return super.take_damage(adjusted, source, ability, direct_hit)

func adjusted_movement_speed() -> float:
	return super.adjusted_movement_speed() * movement_multiplier

func receive_weapon_impact(direction: Vector2, weapon_class: int, strength: float) -> float:
	# A second impulse breaks causal ownership of a pending wall collision.
	wall_burst.clear()
	return super.receive_weapon_impact(direction,weapon_class,strength)

func _physics_process(delta: float) -> void:
	_advance_campaign_effects(delta)
	if not wall_burst.is_empty():
		wall_burst["remaining"] -= delta
		if float(wall_burst["remaining"]) <= 0.0 or is_immobilized() or current_health <= 0:
			wall_burst.clear()
	super._physics_process(delta)

func add_campaign_effect(kind: String, source: ArenaBall, potency: float, duration: float, maximum: int = 1) -> bool:
	if current_health <= 0 or not is_instance_valid(source) or duration <= 0.0 or potency < 0.0:
		return false
	if is_instance_valid(combat_director) and not combat_director.are_enemies(source, self):
		return false
	var same: Array[Dictionary] = []
	var added := false
	for effect in campaign_effects:
		if effect["kind"] == kind:
			same.append(effect)
	if same.size() >= maximum:
		var effect: Dictionary = same[0]
		effect["remaining"] = maxf(effect["remaining"], duration)
		effect["potency"] = maxf(effect["potency"], potency)
		effect["source"] = weakref(source)
	else:
		campaign_effects.append({"kind": kind, "source": weakref(source), "potency": potency, "remaining": duration, "elapsed": 0.0})
		added=true
	if added: combat_event(&"status_applied", source, StringName(kind), {"duration": duration, "potency": potency})
	return true

func _advance_campaign_effects(delta: float) -> void:
	if campaign_effects.is_empty() and not _last_campaign_effects:
		return
	rotation_multiplier = 1.0
	movement_multiplier = 1.0
	for index in range(campaign_effects.size() - 1, -1, -1):
		var effect := campaign_effects[index]
		var active_delta := minf(delta, maxf(0.0, effect["remaining"]))
		effect["remaining"] -= delta
		var source := effect["source"].get_ref() as ArenaBall
		match effect["kind"]:
			"ice":
				if is_vampire:
					movement_multiplier = minf(movement_multiplier, 1.0 - float(effect["potency"]))
				else:
					rotation_multiplier = minf(rotation_multiplier, 1.0 - float(effect["potency"]))
			"slow":
				movement_multiplier = minf(movement_multiplier, 1.0 - float(effect["potency"]))
			"burn", "cut", "acid":
				effect["elapsed"] += active_delta
				while float(effect["elapsed"]) + 0.000001 >= 0.2 and current_health > 0:
					effect["elapsed"] -= 0.2
					take_damage(CampaignUnits.pack(float(effect["potency"]) * 0.2), source, StringName(effect["kind"]), false)
		if float(effect["remaining"]) <= 0.000001 or current_health <= 0:
			campaign_effects.remove_at(index)
	rotation_multiplier = clampf(rotation_multiplier, 0.5, 1.0)
	movement_multiplier = clampf(movement_multiplier, 0.65, 1.0)
	_last_campaign_effects = not campaign_effects.is_empty() or not is_equal_approx(rotation_multiplier, 1.0) or not is_equal_approx(movement_multiplier, 1.0)

func arm_wall_burst(source: ArenaBall, fraction: float, duration: float) -> void:
	if current_health <= 0 or is_immobilized() or linear_velocity.is_zero_approx():
		return
	wall_burst = {"source": weakref(source), "remaining": duration, "direction": linear_velocity.normalized(),
		"amount": roundi(campaign_effective_max * fraction)}

func _update_speed_contacts(state: PhysicsDirectBodyState2D) -> void:
	if not wall_burst.is_empty():
		for contact in state.get_contact_count():
			var collider := state.get_contact_collider_object(contact)
			if not is_instance_valid(collider) or _previous_contacts.has(collider.get_instance_id()):
				continue
			if collider is ArenaBall:
				wall_burst.clear()
				break
			if collider.is_in_group("walls"):
				var burst := wall_burst.duplicate()
				wall_burst.clear()
				if _collision_incoming_velocity.normalized().dot(burst["direction"]) > 0.65:
					var source := burst["source"].get_ref() as ArenaBall
					if is_instance_valid(source):
						take_damage(burst["amount"], source, &"wall_burst", false)
						source.combat_event(&"wall_burst", self, &"club", {"amount": burst["amount"]})
				break
	super._update_speed_contacts(state)
