extends Node2D
## Shared painted textures: mirrored alternation joins identical border pixels.
const ART := preload("res://scripts/campaign/map/art/assets.gd")
var asset := "coliseum"
var tiles: Array[Sprite2D] = []
var tile_width := 1400.0

func set_view(left: float, right: float) -> void:
	var first := floori(left/tile_width)-1
	var count := ceili((right-left)/tile_width)+3
	while tiles.size()<count:
		var tile := Sprite2D.new(); tile.centered = false
		tile.texture = ART.texture(asset)
		tile.scale=Vector2(tile_width/tile.texture.get_width(),700.0/tile.texture.get_height())
		tile.position.y=-40 if asset=="coliseum" else 30
		add_child(tile); tiles.append(tile)
	for index in tiles.size():
		tiles[index].visible = index<count
		if index<count:
			tiles[index].position.x = (first+index)*tile_width
			tiles[index].flip_h=posmod(first+index,2)==1
