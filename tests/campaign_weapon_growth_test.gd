extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a := CampaignProgression.new_account()
	var originals := {}
	for id in CampaignProgression.playable_ids(): originals[id]=BalanceSnapshot.describe(StringName(id),{})
	var world := Node2D.new(); root.add_child(world)
	for id in CampaignProgression.playable_ids():
		var last_reach := 0.0
		for tier in 7:
			a["heroes"][id]["weapon_stage"]=tier
			var profile := CampaignProfiles.hero(id,a)
			var actor := CampaignProfiles.create_actor(profile,world)
			actor.freeze=true
			var ability := actor.get_node("Vampire" if id=="vampire" else {"swordsman":"Sword","knifeman":"Knives","katana":"Katana","club":"Club"}[id]) as CombatAbility
			var reach := 0.0
			if ability is SwordAbility:
				for segment in ability.current_weapon_segments():
					for point: Vector2 in segment: reach=maxf(reach,point.distance_to(actor.global_position))
				assert(reach>last_reach)
				assert(is_equal_approx(ability.get("blade_length"),CharacterCatalog.character(StringName(id)).abilities[0].parameters["blade_length"]*CampaignEconomy.data()["weapon_length_factors"][tier]))
			else:
				reach=float(profile["stats"]["weapon_length"])
				assert(tier==0 or is_equal_approx(reach,last_reach))
			last_reach=reach
			actor.free()
		assert(BalanceSnapshot.describe(StringName(id),{})==originals[id])
	world.free(); await process_frame; await process_frame
	print("campaign_weapon_growth_test: PASS"); quit(0)
