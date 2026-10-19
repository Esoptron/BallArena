extends SwordAbility
func effective_spin_speed() -> float:
	return super.effective_spin_speed() * float(fighter.get("rotation_multiplier"))
