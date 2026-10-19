extends Node
## Optional run enchantments observe actual successful hits / genuine clash events.
var actor: CampaignBall
var director: CombatDirector
var clash_cd := 0.0
func _ready() -> void:
	director.event_recorded.connect(_event)
func _physics_process(delta: float) -> void: clash_cd=maxf(0,clash_cd-delta)
func _event(event: Dictionary) -> void:
	if not is_instance_valid(actor) or actor.current_health <= 0: return
	var kind: String = event["kind"]
	var involved: bool = event["actor_id"]==actor.actor_id
	if kind == "weapon_clash": involved = involved or event["target_id"]==actor.actor_id
	if not involved or not kind in ["hit","bite_tick","weapon_clash"]: return
	var id: String = event["target_id"] if event["actor_id"]==actor.actor_id else event["actor_id"]
	var target: CampaignBall
	for fighter in director.fighters:
		if fighter.actor_id==id: target=fighter as CampaignBall; break
	if target==null or target.current_health<=0 or not director.are_enemies(actor,target): return
	var bonuses := actor.campaign_bonuses
	if kind=="weapon_clash":
		if bonuses.get("shatter",0)>0 and clash_cd<=0:
			var damage := 0
			for ability in director.abilities:
				if ability.fighter==actor and ability.is_enabled() and ability is SwordAbility: damage=ability.current_damage
			clash_cd=0.6
			target.take_damage(roundi(damage*0.1),actor,&"shatter",false)
		return
	if kind=="bite_tick" and event.get("amount",0)<=0: return
	if bonuses.get("ice",0)>0: target.add_campaign_effect("ice",actor,0.1,2.0)
	if bonuses.get("fire",0)>0: target.add_campaign_effect("burn",actor,CampaignUnits.unpack(target.campaign_effective_max)*0.05/3.0,3.0)
