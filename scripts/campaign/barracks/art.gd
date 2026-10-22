extends RefCounted
## Shared, lazily loaded art. Atlas regions leave the generated sources intact.
const ROOT := "res://assets/campaign/barracks/"
const MAP := preload("res://scripts/campaign/map/art/assets.gd")
const REGIONS := {
	"panel": Rect2(22,64,716,300), "steel": Rect2(794,64,718,300),
	"button": Rect2(22,405,728,235), "selected": Rect2(790,405,726,235),
	"inset": Rect2(154,706,486,223), "card": Rect2(838,683,630,273)}
const ICONS := ["hp","damage","speed","spin","hit_growth","healing","xp","evolution","merge","lock","rank","ability"]
static var _cache: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if _cache.has(key): return _cache[key]
	if key in ["forge","pedestal","frames","icons"]:
		_cache[key]=load(ROOT+key+".png") as Texture2D
	elif key in ["coin","diamond","arrow"]:
		_cache[key]=MAP.texture(key)
	else:
		var atlas := AtlasTexture.new()
		if REGIONS.has(key):
			atlas.atlas=texture("frames")
			var region: Rect2=REGIONS[key]
			var ratio := atlas.atlas.get_width()/1536.0
			atlas.region=Rect2(region.position*ratio,region.size*ratio)
		else:
			var index := ICONS.find(key)
			assert(index>=0,"Unknown barracks icon: "+key)
			atlas.atlas=texture("icons")
			var cell := atlas.atlas.get_size()/Vector2(4,3)
			atlas.region=Rect2(Vector2(index%4,index/4)*cell,cell)
		atlas.filter_clip=true
		_cache[key]=atlas
	return _cache[key]

static func frame(key: String = "panel", margin: int = 12) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture=texture(key)
	var border := 22.0 if key in ["panel","steel","card"] else 30.0
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,border)
		box.set_content_margin(side,margin)
	return box
