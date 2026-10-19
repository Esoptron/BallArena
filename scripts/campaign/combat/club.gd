extends ClubAbility
var wall_burst_chance: float = 0.01
var wall_burst_fraction: float = 0.2
var wall_burst_window: float = 0.85

func _ready() -> void:
	super._ready()
	sword_hit.connect(_after_hit)

func effective_spin_speed() -> float:
	return super.effective_spin_speed() * float(fighter.get("rotation_multiplier"))

func _after_hit(victim: ArenaBall, _damage: int) -> void:
	if not is_instance_valid(victim) or not victim.has_method("arm_wall_burst") or victim.current_health <= 0:
		return
	if rng.randf() < wall_burst_chance:
		victim.call("arm_wall_burst", fighter, wall_burst_fraction, wall_burst_window)
		emit_event(&"wall_burst_armed", victim, {"window": wall_burst_window})
