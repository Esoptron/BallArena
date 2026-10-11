class_name ArenaBlood
extends Node2D
## Blood positions are stored in arena space, independent of fang rotation.

signal drop_landed

@export var floor_y: float = 600.0
@export_range(10.0, 3000.0, 10.0) var gravity: float = 750.0
@export_range(0.1, 10.0, 0.1) var stain_lifetime: float = 1.25
@export_range(4, 512, 1) var max_drops: int = 144

var drops: Array[Dictionary] = []


func spawn_drop(world_position: Vector2, radius: float = 2.8) -> void:
	if drops.size() >= max_drops:
		drops.pop_front()
	var p := to_local(world_position)
	p.y = minf(p.y, floor_y - radius)
	drops.append({
		"position": p,
		"fall_speed": 32.0,
		"radius": radius,
		"landed": false,
		"age": 0.0,
	})
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop := drops[index]
		var radius: float = drop["radius"]
		if drop["landed"]:
			drop["age"] += delta
			if drop["age"] >= stain_lifetime:
				drops.remove_at(index)
		else:
			var p: Vector2 = drop["position"]
			var speed: float = drop["fall_speed"]
			p.y += speed * delta + gravity * delta * delta * 0.5
			drop["fall_speed"] = speed + gravity * delta
			if p.y >= floor_y - radius:
				p.y = floor_y - radius
				drop["landed"] = true
				drop["age"] = 0.0
				drop_landed.emit()
			drop["position"] = p
	queue_redraw()


func _draw() -> void:
	for drop in drops:
		var p: Vector2 = drop["position"]
		var radius: float = drop["radius"]
		var scale_factor := Vector2(1.0, 1.35)
		var alpha := 0.9
		if drop["landed"]:
			var age: float = drop["age"]
			var squash := clampf(age / 0.12, 0.0, 1.0)
			scale_factor = Vector2(lerpf(1.0, 2.8, squash), lerpf(1.0, 0.18, squash))
			p.y = floor_y - radius * scale_factor.y
			alpha *= pow(1.0 - clampf(age / stain_lifetime, 0.0, 1.0), 2.0)
		draw_set_transform(p, 0.0, scale_factor)
		draw_circle(Vector2.ZERO, radius, Color(0.82, 0.025, 0.055, alpha))
		if not drop["landed"]:
			draw_circle(Vector2(-radius * 0.25, -radius * 0.35), radius * 0.2,
				Color(1.0, 0.60, 0.65, alpha))
	draw_set_transform(Vector2.ZERO)
