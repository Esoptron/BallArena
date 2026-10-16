class_name BattleLevel
extends Resource
@export var title: String = ""
@export_multiline var description: String = ""
@export var player_character: StringName = &"swordsman"
@export var opponent_character: StringName = &"ordinary"
@export var opponent_count: int = 3

func roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"character":String(player_character),"team":"blue"}]
	for index in opponent_count: result.append({"character":String(opponent_character),"team":"red"})
	return result
