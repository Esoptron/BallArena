extends "res://scripts/combat_numbers.gd"
func spawn(world_position: Vector2, amount: int, healing: bool) -> void:
	if amount <= 0:
		return
	super.spawn(world_position, amount, healing)
	numbers[-1]["text"] = ("+" if healing else "-") + CampaignUnits.text(amount)
