class_name CampaignEvolutions
extends RefCounted
## Individual slots, deliberately inert until their abilities receive separate approval.
static func next_definition(account: Dictionary, id: String) -> Dictionary:
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/evolutions.json"))
	return definitions.get(id,{}).get(str(int(account["heroes"][id]["evolution"]["stage"])+1),{}).duplicate(true)

static func progress(account: Dictionary, id: String) -> Dictionary:
	var hero: Dictionary=account["heroes"][id]
	var definition := next_definition(account,id)
	var required := int(CampaignEconomy.data()["evolution_extra_cards"])*int(CampaignEconomy.data()["card_scale"])
	return {"units":int(hero["evolution"]["card_units"]),"required":required,
		"cards_ready":hero["owned"] and int(hero["evolution"]["card_units"])>=required,
		"ability_defined":not definition.get("implementation","").is_empty() and definition.get("enabled",false)}
