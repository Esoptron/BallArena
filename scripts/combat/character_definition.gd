@tool
class_name CharacterDefinition
extends Resource

@export var character_id: StringName
@export var display_name: String
@export var tags: PackedStringArray = []
@export var reference_health: int = 100
@export var starting_health: int = 100
@export var movement_speed: float = 320.0
@export_enum("Light", "Below average", "Medium", "Above average", "Heavy") var weight_class: int = 2
@export_range(0.25, 3.0, 0.05) var diameter_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.05) var wall_boost_scale: float = 1.0
@export_range(0.1, 10.0, 0.05) var boost_decay_seconds: float = 3.0
@export var abilities: Array[AbilityDefinition] = []
