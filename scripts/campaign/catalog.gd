class_name CampaignCatalog
extends RefCounted
## Separate from CharacterCatalog: campaign enemies cannot enter free battle rosters.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/enemies.json"))
	return _data

static func enemy(id: String, overrides: Dictionary = {}) -> Dictionary:
	assert(data().has(id), "Unknown campaign enemy: " + id)
	var p: Dictionary = data()[id].duplicate(true)
	p.merge(overrides, true)
	var profile := CharacterDefinition.new()
	profile.character_id = StringName(id)
	profile.display_name = p["name"]
	profile.tags = PackedStringArray(["campaign_enemy"])
	profile.reference_health = CampaignUnits.pack(p["hp"])
	profile.starting_health = profile.reference_health
	profile.movement_speed = p["speed"]
	profile.weight_class = int(p.get("weight", 2))
	profile.diameter_multiplier = float(p.get("size", 1.0))
	var ability := AbilityDefinition.new()
	ability.ability_id = StringName(p["weapon"])
	ability.node_name = &"CampaignWeapon"
	ability.implementation = preload("res://scripts/campaign/combat/ranged.gd") if p.get("ranged", false) else preload("res://scripts/campaign/combat/melee.gd")
	ability.weapon_weight_class = int(p.get("weapon_weight", 2))
	ability.impact_strength = float(p.get("impact", 90.0))
	ability.parameters = {"weapon_kind": p["weapon"], "boss_kind": p.get("boss", ""), "base_damage": CampaignUnits.pack(p["damage"]),
		"hit_cooldown": p["cooldown"], "blade_length": p.get("length", 40.0), "spin_speed": p.get("spin", 3.5)}
	profile.abilities = [ability]
	return {"definition": profile, "stats": {"base_hp": p["hp"]}, "bonuses": {}, "enemy": p}

static func modified(id: String, modifier: String) -> Dictionary:
	# A QA/future-content helper. Authored encounters never get replaced by this.
	var p: Dictionary = data()[id].duplicate(true)
	match modifier:
		"fast": p["speed"] *= 1.15
		"heavy": p["weight"] = mini(4, int(p.get("weight", 2)) + 1)
		"range": p["length"] = float(p.get("length", 40)) * 1.15
		"berserk": p["spin"] = float(p.get("spin", 3.5)) * 1.2
		"armored": p["hp"] *= 1.2
		"empowered": p["damage"] *= 1.2
		"bleed", "fire", "ice": p["modifier"] = modifier
	return enemy(id, p)
