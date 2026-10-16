class_name CombatMetrics
extends RefCounted

var participants: Dictionary = {}
var events: int = 0
var active_success: Dictionary = {}
var previous_capture: Dictionary = {}


func attach(actors: Array[ArenaBall], director: CombatDirector) -> void:
	for actor in actors:
		participants[actor.actor_id] = {"character_id":String(actor.character_id),"role":actor.battle_role,
			"damage_dealt":0,"damage_received":0,"healing":0,"hits":0,
			"capture_seconds":0.0,"protection_seconds":0.0,"attack_lock_seconds":0.0,"recaptures_without_reply":0,
			"blocked":{},"abilities":{},"hit_times":[]}
	director.event_recorded.connect(observe)


func observe(event: Dictionary) -> void:
	events += 1
	var id: String = event["actor_id"]
	if not participants.has(id):
		return
	var actor: Dictionary = participants[id]
	var ability_id: String = event["ability_id"]
	if not actor["abilities"].has(ability_id):
		actor["abilities"][ability_id] = {"starts":0,"successes":0,"completed":0,"hits":0,"times":[],"success_times":[]}
	var ability: Dictionary = actor["abilities"][ability_id]
	var key := id+"/"+ability_id+"/"+str(event.get("cast_id","default"))
	match event["kind"]:
		"damage":
			actor["damage_dealt"] += event["amount"]
			if participants.has(event["target_id"]):
				participants[event["target_id"]]["damage_received"] += event["amount"]
		"heal":
			if participants.has(event["target_id"]):
				participants[event["target_id"]]["healing"] += event["amount"]
		"hit":
			actor["hits"] += 1
			ability["hits"] += 1
			actor["hit_times"].append(event["time"])
			if not active_success.get(key,false):
				ability["successes"] += 1
				ability["success_times"].append(event["time"])
				active_success[key] = true
		"cast_started":
			ability["starts"] += 1
			ability["times"].append(event["time"])
			if "capture" in event.get("tags",[]) and event.get("successful",false):
				var target_id: String = event["target_id"]
				if participants.has(target_id):
					var previous: Dictionary = previous_capture.get(target_id,{})
					var reply_hits: int = participants[target_id]["hits"]
					if previous.get("source","") == id and previous.get("reply_hits",-1) == reply_hits:
						actor["recaptures_without_reply"] += 1
					previous_capture[target_id] = {"source":id,"reply_hits":reply_hits}
			active_success[key] = event.get("successful",false)
			if active_success[key]:
				ability["successes"] += 1
				ability["success_times"].append(event["time"])
		"cast_finished":
			if event.get("completed",false):
				ability["completed"] += 1
			if event.get("successful",false) and not active_success.get(key,false):
				ability["successes"] += 1
				ability["success_times"].append(event["time"])
			active_success.erase(key)
		"blocked":
			var reason: String = event.get("reason","unknown")
			actor["blocked"][reason] = actor["blocked"].get(reason,0)+1


func sample(actors: Array[ArenaBall], delta: float) -> void:
	for actor in actors:
		var row: Dictionary = participants[actor.actor_id]
		if actor.is_paralyzed():
			row["capture_seconds"] += delta
		if actor.is_invulnerable():
			row["protection_seconds"] += delta
		if actor.attack_recovery_remaining > 0 and not actor.is_immobilized():
			row["attack_lock_seconds"] += delta


func finish(actors: Array[ArenaBall], duration: float, timeout: bool) -> Dictionary:
	var winner := ""
	var winner_role := ""
	var winner_slot := ""
	for actor in actors:
		participants[actor.actor_id]["final_hp"] = actor.current_health
		if actor.current_health > 0:
			winner = String(actor.character_id)
			winner_role = actor.battle_role
			winner_slot = actor.actor_id
	return {"duration":duration,"winner":"" if timeout else winner,"timeout":timeout,
		"participants":participants,"event_count":events,"winner_actor_id":"" if timeout else winner_slot,"winner_role":"" if timeout else winner_role}
