extends Control
## Actual campaign actor rendered once in an isolated world. Only its cached
## portrait is animated by the UI, never combat/physics or six live viewports.
var actor: CampaignBall
var viewport: SubViewport
var image: TextureRect
var _signature := ""
var weapon_only := false
var hero_id := ""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new(); viewport.size=Vector2i(480,480)
	viewport.transparent_bg=true; viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input=true; viewport.disable_3d=true
	add_child(viewport)
	image=TextureRect.new(); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.texture=viewport.get_texture(); add_child(image)

func display(id: String, account: Dictionary, just_weapon: bool = false) -> void:
	var signature := id+str(CampaignProgression.stats(id,account))+str(just_weapon)
	if signature==_signature: return
	_signature=signature; hero_id=id; weapon_only=just_weapon
	if is_instance_valid(actor): viewport.remove_child(actor); actor.free()
	var profile := CampaignProfiles.hero(id,account)
	actor=CampaignProfiles.create_actor(profile,viewport)
	actor.freeze=true; actor.collision_layer=0; actor.collision_mask=0
	actor.linear_velocity=Vector2.ZERO
	# Keep real proportions and the exact compiled weapon. Presentation scale is
	# uniform; no body, reach, rank, colour or model data is edited.
	var s: Dictionary=profile["stats"]
	var extent := float(s["diameter"])+float(s["weapon_length"])
	var zoom := minf(3.8,350.0/maxf(extent,70))
	actor.scale=Vector2.ONE*zoom; actor.position=Vector2(212,286)
	for child in actor.get_children():
		if child is CombatAbility:
			if child.has_method("_process"): child.call("_process",0.0)
			child.rotation=PI if id=="vampire" else -PI*0.27
	_freeze_tree(actor)
	for node_name in ["HealthDisplay","CooldownIndicator","BerserkIndicator"]:
		var indicator := actor.get_node_or_null(NodePath(node_name)) as CanvasItem
		if indicator: indicator.hide()
	if just_weapon: actor.self_modulate=Color(1,1,1,0)
	actor.queue_redraw()
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func _freeze_tree(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): _freeze_tree(child)
