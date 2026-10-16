extends Node2D
## Shared damage/healing numbers. They rise in world-up, dim and fade.

@export_range(8, 96, 1) var font_size: int = 30
@export var lifetime: float = 1.1
@export var max_numbers: int = 64
var numbers: Array[Dictionary] = []
var serial: int = 0
const GRIZZLY := preload("res://scripts/grizzly_icon.gd")


func spawn(world_position: Vector2, amount: int, healing: bool) -> void:
	if amount <= 0:
		return
	if numbers.size() >= max_numbers:
		numbers.pop_front()
	var offset := Vector2(-8.0 if serial % 2 == 0 else 8.0, -28.0)
	serial += 1
	numbers.append({"position": to_local(world_position) + offset,
		"text": ("+" if healing else "-") + str(amount),
		"healing": healing, "age": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if numbers.is_empty(): return
	for index in range(numbers.size() - 1, -1, -1):
		var number := numbers[index]
		number["age"] += delta
		number["position"] += Vector2.UP * 31.0 * delta
		if number["age"] >= lifetime:
			numbers.remove_at(index)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for number in numbers:
		var progress: float = number["age"] / lifetime
		var alpha := 1.0 - smoothstep(0.2, 1.0, progress)
		var color: Color = number.get("tint",Color(0.29, 1.0, 0.45) if number["healing"] else Color(1.0, 0.24, 0.29))
		color = color.darkened(progress * 0.40)
		color.a = alpha
		var text: String = number["text"]
		var size: int = number.get("size",font_size)
		var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var baseline: Vector2 = number["position"] + Vector2(-bounds.x * 0.5, 0.0)
		if number.get("grizzly",false):
			baseline.x += 16.0
			GRIZZLY.draw_icon(self,number["position"] + Vector2(-bounds.x*0.5-4.0,-8.0),12.0,alpha)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3,
			Color(0.025, 0.035, 0.055, alpha * 0.9))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func spawn_notice(world_position: Vector2, text: String, tint: Color) -> void:
	if numbers.size() >= max_numbers:
		numbers.pop_front()
	numbers.append({"position":to_local(world_position)+Vector2(0,-48),"text":text,
		"healing":false,"age":0.0,"tint":tint,"size":18})
	queue_redraw()

func spawn_berserk(world_position: Vector2) -> void:
	spawn_notice(world_position,"БЕРСЕРК",Color(1.0,0.49,0.18))
	numbers[-1]["grizzly"] = true
	numbers[-1]["position"] += Vector2.UP * 24.0
