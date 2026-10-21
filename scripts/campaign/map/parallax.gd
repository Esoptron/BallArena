extends RefCounted
## Explicit project convention, including the intentionally slower foreground.
var upper: Node2D
var middle: Node2D
var lower: Node2D
var ratios: Dictionary

func apply(offset: float, zoom: float, y: float) -> void:
	for pair in [[upper,"upper"],[middle,"middle"],[lower,"lower"]]:
		var layer: Node2D = pair[0]
		layer.scale = Vector2.ONE * zoom
		layer.position = Vector2(-offset * float(ratios[pair[1]]), y)
