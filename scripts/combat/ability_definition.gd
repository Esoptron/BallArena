@tool
class_name AbilityDefinition
extends Resource

@export var ability_id: StringName
@export var node_name: StringName
@export var implementation: Script
@export var tags: PackedStringArray = []
@export_enum("Light", "Below average", "Medium", "Above average", "Heavy") var weapon_weight_class: int = 2
## Directional impact strength at medium weapon/body weight; zero for drain abilities.
@export_range(0.0, 1000.0, 10.0) var impact_strength: float = 0.0
@export var parameters: Dictionary = {}
