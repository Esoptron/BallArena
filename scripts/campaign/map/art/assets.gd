extends RefCounted
## Atlas regions reference the untouched generated PNG; no destructive cropping.
const ROOT := "res://assets/campaign/map_painted/"
static var _layout: Dictionary = {}
static var _textures: Dictionary = {}

static func layout() -> Dictionary:
	if _layout.is_empty(): _layout=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
	return _layout

static func texture(key: String) -> Texture2D:
	if _textures.has(key): return _textures[key]
	if layout()["files"].has(key):
		_textures[key]=load(ROOT+layout()["files"][key]) as Texture2D
	else:
		var atlas := AtlasTexture.new(); atlas.atlas=texture("ui")
		var box: Array=layout()["ui_regions"][key]
		# Godot's size_limit may downsample the imported sheet; regions remain
		# expressed in original pixel coordinates so import quality is editable.
		var scale_value := atlas.atlas.get_size().x/float(layout()["atlas_source_size"][0])
		atlas.region=Rect2(float(box[0])*scale_value,float(box[1])*scale_value,float(box[2])*scale_value,float(box[3])*scale_value)
		atlas.filter_clip=true
		_textures[key]=atlas
	return _textures[key]

static func rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])
