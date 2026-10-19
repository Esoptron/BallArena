class_name CampaignProfiles
extends RefCounted
const ADAPTERS := {
	"swordsman": preload("res://scripts/campaign/combat/sword.gd"),
	"knifeman": preload("res://scripts/campaign/combat/knives.gd"),
	"katana": preload("res://scripts/campaign/combat/katana.gd"),
	"vampire": preload("res://scripts/campaign/combat/vampire.gd"),
	"club": preload("res://scripts/campaign/combat/club.gd"),
}

static func hero(id: String, account: Dictionary, bonuses: Dictionary = {}) -> Dictionary:
	var values := CampaignProgression.stats(id, account, bonuses)
	var profile := CharacterCatalog.character(StringName(id))
	profile.reference_health = CampaignUnits.pack(values["max_hp"])
	profile.starting_health = profile.reference_health
	profile.movement_speed = values["speed"]
	var ability: AbilityDefinition = profile.abilities[0]
	ability.implementation = ADAPTERS[id]
	var p := ability.parameters
	if id == "vampire":
		p["campaign_damage"] = CampaignUnits.pack(values["damage"])
		p["campaign_healing"] = CampaignUnits.pack(values["healing"])
		p["campaign_damage_gain"] = CampaignUnits.pack(values["hit_growth"])
		p["campaign_healing_gain"] = CampaignUnits.pack(values["heal_growth"])
		p["health_speed_reference"] = CampaignUnits.pack(values["base_hp"])
		p["health_speed_per_hp"] = 0.5 / CampaignUnits.pack(values["base_hp"])
		p["hunt_health_threshold"] = CampaignUnits.pack(values["base_hp"] * values["chance"])
	else:
		var original := CharacterCatalog.character(StringName(id))
		var speed_factor: float = values["speed"] / original.movement_speed
		p["base_damage"] = CampaignUnits.pack(values["damage"])
		p["damage_gain"] = CampaignUnits.pack(values["hit_growth"])
		p["max_damage"] = int(p["max_damage"]) * CampaignUnits.SCALE
		p["spin_speed"] = values["spin"]
		p["max_speed"] = maxf(values["speed"], float(p["max_speed"]) * speed_factor)
		p["speed_gain"] = float(p["speed_gain"]) * speed_factor
		p["blade_length"] = float(p["blade_length"]) * float(values["length_factor"])
		match id:
			"swordsman": p["berserk_chance"] = values["chance"]
			"knifeman": p["capture_counter_chance"] = values["chance"]
			"katana":
				p["critical_start_chance"] = values["chance"]
				p["critical_chance_gain"] = values["chance_growth"]
				p["bleed_tick_damage"] = CampaignUnits.pack(values["bleed_damage"])
			"club":
				p["wall_burst_chance"] = values["chance"]
				p["wall_burst_fraction"] = CampaignProgression.data()["players"][id]["wall_damage_fraction"]
				p["wall_burst_window"] = CampaignProgression.data()["players"][id]["wall_window"]
	return {"definition": profile, "stats": values, "bonuses": bonuses.duplicate(true)}

static func create_actor(compiled: Dictionary, parent: Node, health: int = -1, peak: int = -1) -> CampaignBall:
	var actor := empty_actor()
	parent.add_child(actor)
	var profile: CharacterDefinition = compiled["definition"]
	CharacterCatalog.apply(actor, profile, 70.0)
	actor.set("campaign_base_max", CampaignUnits.pack(float(compiled["stats"]["base_hp"])))
	actor.set("campaign_effective_max", maxi(profile.reference_health, peak))
	actor.set("campaign_bonuses", compiled.get("bonuses", {}).duplicate(true))
	if health >= 0:
		actor.current_health = health if actor.is_vampire else mini(health, profile.reference_health)
	return actor as CampaignBall

static func empty_actor(_source: ArenaBall = null) -> CampaignBall:
	var actor := preload("res://scenes/ball.tscn").instantiate() as ArenaBall
	actor.set_script(preload("res://scripts/campaign/combat/ball.gd"))
	actor.get_node("Vampire").set_script(ADAPTERS["vampire"])
	actor.get_node("Sword").set_script(ADAPTERS["swordsman"])
	return actor as CampaignBall
