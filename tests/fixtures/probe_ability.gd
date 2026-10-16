extends CombatAbility
var pulse_heal: int = 1
var initialized_heal: int = 0
var healing_observed: int = 0
var spent: bool = false

func _ready() -> void:
	super._ready()
	initialized_heal = pulse_heal
	fighter.health_delta.connect(_observe_health)

func _observe_health(amount: int, healing: bool) -> void:
	if healing:
		healing_observed += amount

func reset_runtime() -> void:
	spent = false

func combat_step(_delta: float) -> void:
	if not spent:
		spent = true
		fighter.heal(pulse_heal,fighter,ability_id)
