extends Node2D
## Small retained vector icon; optional TextureRect provides a future art slot.
var kind := "bronze"
var tint := Color("cb8850")
var faded := false
var texture_slot: TextureRect

func configure(value: String, skin: Dictionary, unavailable: bool) -> void:
	kind = value; tint = Color(skin["colour"]); faded = unavailable
	if texture_slot == null:
		texture_slot = TextureRect.new()
		texture_slot.position = Vector2(-23, -21); texture_slot.size = Vector2(46, 42)
		texture_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(texture_slot)
	var path: String = skin.get("texture", "")
	texture_slot.texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	texture_slot.modulate = Color("6c7380") if faded else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if texture_slot != null and texture_slot.texture != null: return
	var colour := Color("606775") if faded else tint
	draw_circle(Vector2(0, 3), 25, Color(0.02, 0.03, 0.05, 0.65))
	draw_polygon(PackedVector2Array([Vector2(-20,-12),Vector2(-13,-20),Vector2(14,-20),Vector2(21,-12),Vector2(20,17),Vector2(-20,17)]), PackedColorArray([colour.darkened(0.72)]))
	draw_polygon(PackedVector2Array([Vector2(-17,-10),Vector2(-11,-17),Vector2(12,-17),Vector2(17,-10)]), PackedColorArray([colour.lightened(0.25)]))
	draw_rect(Rect2(-17,-7,34,20), colour.darkened(0.23))
	draw_line(Vector2(-17,-6),Vector2(17,-6),colour.lightened(0.46),2,true)
	for x in [-12,10]: draw_rect(Rect2(x,-16,3,31),colour.darkened(0.48))
	draw_rect(Rect2(-4,-7,8,13),colour.lightened(0.4))
	draw_circle(Vector2(0,-1),2,colour.darkened(0.8))
	if kind == "diamond":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(6,-9),Vector2(0,-3),Vector2(-6,-9)]),colour.lightened(0.65))
