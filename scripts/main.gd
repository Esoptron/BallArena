extends Node2D
## Fit the fixed world into the window, leaving blank space for future UI.

@export var screen_padding: Vector2 = Vector2(64.0, 120.0)

@onready var arena: BallArena = $Arena
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_arena)
	_fit_arena()


func _fit_arena() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var required_size := arena.arena_size + screen_padding * 2.0
	var fit := minf(viewport_size.x / required_size.x,
		viewport_size.y / required_size.y)
	# Never enlarge the arena on bigger screens; scale down uniformly if needed.
	camera.zoom = Vector2.ONE * minf(1.0, fit)
	camera.position = arena.position + arena.arena_size * 0.5
