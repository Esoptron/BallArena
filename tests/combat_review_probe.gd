extends CombatAbility
var steps: int = 0
var seeded: int = 0
var payload: Dictionary = {}

func combat_step(_delta: float) -> void:
	steps += 1

func on_match_seed() -> void:
	seeded += 1
