extends Node2D
## Settled blood has its own retained canvas; moving drops do not rebuild it.
func _draw() -> void:
	(get_parent() as ArenaBlood).draw_pools(self)
