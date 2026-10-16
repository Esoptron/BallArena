extends RigidBody2D
## Textured puzzle shard. Lifetime uses wall time, independent of frame rate.
var born_usec: int
var lifetime: float = 3.0

func _ready() -> void:
	born_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var age := float(Time.get_ticks_usec() - born_usec) / 1000000.0
	modulate.a = 1.0 - smoothstep(0.45, lifetime, age)
	if age >= lifetime:
		queue_free()
