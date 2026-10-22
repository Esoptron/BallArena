extends Control
## Actual campaign actor rendered once in an isolated world. Only its cached
## portrait is animated by the UI, never combat/physics or six live viewports.
var actor: CampaignBall
var viewport: SubViewport
var image: TextureRect
var _signature := ""
var weapon_only := false
var hero_id := ""
var render_size := Vector2i(480,480)
var compact := false
var _account: Dictionary = {}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new(); viewport.size=render_size
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
	_account=account
	var signature := id+str(CampaignProgression.stats(id,account))+str(just_weapon)+str(compact)
	if signature==_signature: return
	_signature=signature; hero_id=id; weapon_only=just_weapon
	if is_instance_valid(actor): viewport.remove_child(actor); actor.free()
	var profile := CampaignProfiles.hero(id,account)
	actor=CampaignProfiles.create_actor(profile,viewport)
	actor.freeze=true; actor.collision_layer=0; actor.collision_mask=0
	actor.linear_velocity=Vector2.ZERO
	# Keep real proportions and the exact compiled weapon. Presentation scale is
	# uniform; no body, reach, rank, colour or model data is edited.
	actor.position=Vector2.ZERO
	for child in actor.get_children():
		if child is CombatAbility:
			if child.has_method("_process"): child.call("_process",0.0)
			child.rotation=PI if id=="vampire" else (0.0 if compact else -PI*0.27)
	_freeze_tree(actor)
	for node_name in ["HealthDisplay","CooldownIndicator","BerserkIndicator"]:
		var indicator := actor.get_node_or_null(NodePath(node_name)) as CanvasItem
		if indicator: indicator.hide()
	if just_weapon:
		actor.self_modulate=Color(1,1,1,0)
		actor.get_node("OrdinaryBallArt").hide()
		actor.get_node("ApprovedVampireArt/BodyAndFur").hide()
	_fit_portrait(just_weapon)
	actor.queue_redraw()
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func set_compact(value: bool) -> void:
	if compact==value: return
	compact=value
	render_size=Vector2i(720,300) if compact else Vector2i(480,480)
	if is_instance_valid(viewport):
		viewport.size=render_size
		if not _account.is_empty(): display(hero_id,_account,weapon_only)

func _fit_portrait(just_weapon: bool) -> void:
	# Fit the actual collision segments, not a hand-picked scale per hero. The
	# body remains proportionate and long/dual weapons stay inside the portrait.
	var r := actor.diameter*0.5
	var bounds := Rect2(Vector2(-r,-r),Vector2.ONE*r*2)
	var has_weapon := false
	for child in actor.get_children():
		if child is SwordAbility and child.is_enabled():
			for segment in child.current_weapon_segments():
				for point in segment:
					if just_weapon and not has_weapon: bounds=Rect2(point,Vector2.ONE)
					else: bounds=bounds.expand(point)
					has_weapon=true
	if hero_id=="vampire":
		bounds=Rect2(Vector2(-r,-r if not just_weapon else r*0.4),Vector2(r*2,r*(2.55 if not just_weapon else 1.15)))
	bounds=bounds.grow((4.0 if compact else 12.0) if has_weapon else 3.0)
	var area := Vector2(render_size)*0.88
	var zoom := minf(area.x/bounds.size.x,area.y/bounds.size.y)
	actor.scale=Vector2.ONE*zoom
	actor.position=Vector2(render_size)*0.5-bounds.get_center()*zoom

func _freeze_tree(node: Node) -> void:
	# _ready ran before CharacterCatalog.apply. Refresh every visual once with
	# the final profile, including nested body-art visibility and materials.
	if node.has_method("_process"): node.call("_process",0.0)
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): _freeze_tree(child)
