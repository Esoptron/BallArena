extends RefCounted
## A menu portrait uses real character artwork but never participates in combat.
const BALL := preload("res://scenes/ball.tscn")

static func create(parent: Node, profile: CharacterDefinition, side: int) -> ArenaBall:
	var fighter := BALL.instantiate() as ArenaBall
	fighter.ball_color = Color(0.16, 0.48, 1.0) if side == 0 else Color(1.0, 0.16, 0.20)
	parent.add_child(fighter)
	CharacterCatalog.apply(fighter, profile, 78.0)
	fighter.freeze = true
	fighter.collision_layer = 0
	fighter.collision_mask = 0
	fighter.linear_velocity = Vector2.ZERO
	_disable_combat(fighter)
	for node_name in ["HealthDisplay", "CooldownIndicator", "BerserkIndicator"]:
		var decoration := fighter.get_node_or_null(NodePath(node_name)) as CanvasItem
		if decoration != null:
			decoration.hide()
			decoration.set_process(false)
	return fighter

static func _disable_combat(node: Node) -> void:
	node.set_physics_process(false)
	if node is CombatAbility:
		# Initialize visibility/draw caches once, then retain the static artwork.
		if node.has_method("_process"):
			node.call("_process", 0.0)
		node.set_process(false)
	for child in node.get_children():
		_disable_combat(child)
