extends Control
## Dense terminal-only mist. CPU animation and drawing stop outside the viewport.
var clock := 0.0
var _elapsed := 0.0
var fog_material: ShaderMaterial

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var noise := FastNoiseLite.new(); noise.seed=87431
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency=0.022; noise.fractal_octaves=3
	var texture := NoiseTexture2D.new()
	texture.width=256; texture.height=256; texture.noise=noise
	texture.seamless=true; texture.generate_mipmaps=true
	fog_material=ShaderMaterial.new()
	fog_material.shader=preload("res://scripts/campaign/map/art/dense_fog.gdshader")
	fog_material.set_shader_parameter("mist_noise",texture)
	fog_material.set_shader_parameter("density",CampaignMapData.config()["painted"]["fog_density"])
	var clouds := ColorRect.new(); clouds.name="DenseMist"
	clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clouds.mouse_filter=Control.MOUSE_FILTER_IGNORE; clouds.material=fog_material
	add_child(clouds)
	var sign := TextureRect.new(); sign.name="Sign"
	sign.texture=preload("res://scripts/campaign/map/art/assets.gd").texture("nav_plate")
	sign.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	sign.position=Vector2(180,215); sign.size=Vector2(600,120)
	sign.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(sign)
	var label := preload("res://scripts/campaign/map/art/hud.gd").label(self,CampaignMapData.config()["terminal"]["label"],46,Color("ffe5b3"))
	label.name="ComingSoon"; label.position=sign.position; label.size=sign.size
	set_animation_visible(false)

func set_animation_visible(value: bool) -> void:
	visible=value; set_process(value)

func _process(delta: float) -> void:
	clock+=delta; _elapsed+=delta
	if _elapsed<1.0/24.0: return
	_elapsed=0; fog_material.set_shader_parameter("drift",clock)
