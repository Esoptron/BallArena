extends DaggerAbility
func effective_spin_speed() -> float:
	return super.effective_spin_speed() * float(fighter.get("rotation_multiplier"))

func on_capture_damage(source: CombatAbility, damage: int) -> bool:
	# Existing bite counter stays intact. Future eligible control components can
	# provide a compatible request without making every movement effect a capture.
	if source is VampireFangs:
		return super.on_capture_damage(source, damage)
	if damage <= 0 or not is_instance_valid(source) or not source.has_method("request_capture_counter"):
		return false
	return bool(source.call("request_capture_counter", self, capture_counter_chance, capture_counter_hp_fraction))
