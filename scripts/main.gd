extends Node2D
## Fit the fixed world into the window, leaving blank space for future UI.

@export var screen_padding: Vector2 = Vector2(64.0, 120.0)

@onready var arena: BallArena = $Arena
@onready var camera: Camera2D = $Camera2D
const LAYOUT := preload("res://scripts/screen_layout.gd")
const PROGRESSION := preload("res://scripts/progression_hud.gd")
var progression: Control
var _layout_viewport: Viewport
var arena_screen_rect := Rect2()


func _ready() -> void:
	_layout_viewport = get_viewport()
	_layout_viewport.size_changed.connect(_fit_arena)
	_fit_arena()
	var layer := CanvasLayer.new()
	layer.name = "ProgressionLayer"
	add_child(layer)
	progression = Control.new()
	progression.set_script(PROGRESSION)
	progression.arena = arena
	progression.camera = camera
	layer.add_child(progression)
	camera.force_update_scroll()
	progression.layout()


func _fit_arena() -> void:
	if not is_inside_tree(): return
	var viewport_size := get_viewport().get_visible_rect().size
	if LAYOUT.landscape(viewport_size):
		arena_screen_rect = LAYOUT.battle_rect(viewport_size, arena.arena_size)
		var landscape_zoom := arena_screen_rect.size.x / arena.arena_size.x
		camera.zoom = Vector2.ONE * landscape_zoom
		camera.position = arena.position + arena.arena_size * 0.5 + (viewport_size * 0.5 - arena_screen_rect.get_center()) / landscape_zoom
		return
	var required_size := arena.arena_size + screen_padding * 2.0
	var fit := minf(viewport_size.x / required_size.x,
		viewport_size.y / required_size.y)
	# Never enlarge the arena on bigger screens; scale down uniformly if needed.
	var zoom := minf(1.0, fit)
	var bottom_reserved := PROGRESSION.required_height(viewport_size.x) + maxf(26.0, 36.0 * zoom + 8.0) + 12.0
	var top_reserved := 72.0
	zoom = minf(zoom, maxf(40.0, viewport_size.y - top_reserved - bottom_reserved) / arena.arena_size.y)
	var arena_height := arena.arena_size.y * zoom
	var center_y := clampf(viewport_size.y * 0.5, top_reserved + arena_height * 0.5,
		viewport_size.y - bottom_reserved - arena_height * 0.5)
	camera.zoom = Vector2.ONE * zoom
	camera.position = arena.position + arena.arena_size * 0.5 + Vector2(0, (viewport_size.y * 0.5 - center_y) / zoom)
	arena_screen_rect = Rect2(Vector2((viewport_size.x - arena.arena_size.x * zoom) * 0.5, center_y - arena_height * 0.5), arena.arena_size * zoom)


func _exit_tree() -> void:
	if is_instance_valid(_layout_viewport) and _layout_viewport.size_changed.is_connected(_fit_arena):
		_layout_viewport.size_changed.disconnect(_fit_arena)
