extends Node2D
## Imported SVGs are shared textures, repeated by visible tile rather than by level.
var asset := "coliseum"
var tiles: Array[Sprite2D] = []
var tile_width := 1280.0

func set_view(left: float, right: float) -> void:
	var first := floori(left/tile_width)-1
	var count := ceili((right-left)/tile_width)+3
	while tiles.size()<count:
		var tile := Sprite2D.new(); tile.centered = false
		tile.texture = load("res://assets/campaign/map_art/"+asset+".svg")
		add_child(tile); tiles.append(tile)
	for index in tiles.size():
		tiles[index].visible = index<count
		if index<count: tiles[index].position.x = (first+index)*tile_width
