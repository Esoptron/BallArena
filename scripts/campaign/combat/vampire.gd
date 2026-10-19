extends VampireFangs
## Preserve the original geometry, 3-second carry, control and cooldown.
## Only campaign damage budgets/progression and inclusive hunt threshold differ.
var campaign_damage: int = 3000
var campaign_healing: int = 2000
var campaign_damage_gain: int = 500
var campaign_healing_gain: int = 300

func on_damage_received(_previous_health: int, damage: int) -> void:
	if not hunt_used and damage > 0 and fighter.current_health > 0 and fighter.current_health <= hunt_health_threshold:
		hunt_used = true
		hunt_pending = true
		hunt_delay_remaining = hunt_delay
		emit_event(&"hunt_armed", fighter.opponent, {"delay": hunt_delay})

func _bite_tick() -> void:
	if not is_instance_valid(bite_target) or ticks_remaining <= 0:
		return
	var victim := bite_target
	var tick := bite_units - ticks_remaining + 1
	var desired := floori(float(campaign_damage) * tick / bite_units) - floori(float(campaign_damage) * (tick - 1) / bite_units)
	var applied := victim.take_damage(desired, fighter, ability_id, tick == 1)
	_damage_this_bite += applied
	var heal_budget := floori(float(_damage_this_bite) * campaign_healing / maxi(1, campaign_damage))
	var healing := fighter.heal(maxi(0, heal_budget - _healed_this_bite), fighter, ability_id)
	_healed_this_bite += healing
	ticks_remaining -= 1
	bite_tick.emit(victim, applied, healing)
	if bite_target != victim:
		return
	if victim.respond_to_capture_damage(self, applied):
		return
	if ticks_remaining == 0 or victim.current_health <= 0 or fighter.current_health <= 0:
		_finish_bite()

func _finish_bite(interrupted: bool = false) -> void:
	var grows := is_instance_valid(bite_target) and ticks_remaining == 0 and not interrupted
	super._finish_bite(interrupted)
	if grows:
		campaign_damage += campaign_damage_gain
		campaign_healing += campaign_healing_gain
		emit_event(&"bite_growth", null, {"damage": campaign_damage, "healing": campaign_healing})
