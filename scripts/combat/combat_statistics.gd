class_name CombatStatistics
extends RefCounted


static func average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += float(value)
	return sum/values.size()


static func quantile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := (sorted.size()-1)*fraction
	var lower := floori(index)
	return lerpf(float(sorted[lower]),float(sorted[ceili(index)]),index-lower)


static func histogram(durations: Array) -> Dictionary:
	var histogram := {"under10":0,"10to20":0,"20to30":0,"30to45":0,"45to60":0,"60to90":0,"over90":0}
	for value in durations:
		var key := "over90"
		if value < 10: key = "under10"
		elif value < 20: key = "10to20"
		elif value < 30: key = "20to30"
		elif value <= 45: key = "30to45"
		elif value <= 60: key = "45to60"
		elif value <= 90: key = "60to90"
		histogram[key] += 1
	return histogram


static func summarize(rows: Array) -> Dictionary:
	var durations: Array = []
	var all_durations: Array = []
	var wins := {"left":0,"right":0}
	var timeouts := 0
	var draws := 0
	var roles: Dictionary = {}
	var two_hit_wins := 0
	var winning_participants: Dictionary = {}
	for row in rows:
		all_durations.append(row["duration"])
		if row["timeout"]:
			timeouts += 1
		else:
			durations.append(row["duration"])
			var winner_role: String = row.get("winner_role","")
			if wins.has(winner_role):
				wins[winner_role] += 1
			else:
				draws += 1
		for participant in row["participants"].values():
			var role: String = participant.get("role","")
			if not roles.has(role):
				roles[role] = []
			roles[role].append(participant)
			if row.get("winner_role","") == role and not row["timeout"]:
				if not winning_participants.has(role):
					winning_participants[role] = []
				winning_participants[role].append(participant)
			if row.get("winner_role","") == role and participant["hits"] > 0 and participant["hits"] <= 2:
				two_hit_wins += 1
	var actors: Dictionary = {}
	for role in roles:
		var participants: Array = roles[role]
		var stats: Dictionary = {}
		for key in ["hits","damage_dealt","damage_received","healing","capture_seconds","protection_seconds","attack_lock_seconds","recaptures_without_reply"]:
			var values: Array = []
			for participant in participants:
				values.append(participant[key])
			stats[key] = average(values)
		var hit_intervals: Array = []
		for participant in participants:
			var times: Array = participant["hit_times"]
			for index in range(1,times.size()):
				hit_intervals.append(times[index]-times[index-1])
		stats["mean_hit_interval"] = average(hit_intervals) if not hit_intervals.is_empty() else null
		var winning_hits: Array = []
		for participant in winning_participants.get(role,[]):
			winning_hits.append(participant["hits"])
		stats["mean_winning_hits"] = average(winning_hits) if not winning_hits.is_empty() else null
		var ability_ids: Dictionary = {}
		for participant in participants:
			for id in participant["abilities"]:
				ability_ids[id] = true
		stats["abilities"] = {}
		for id in ability_ids:
			var counts := {"starts":[],"successes":[],"completed":[],"hits":[]}
			var intervals: Array = []
			var success_intervals: Array = []
			for participant in participants:
				var ability: Dictionary = participant["abilities"].get(id,{})
				for key in counts:
					counts[key].append(ability.get(key,0))
				var times: Array = ability.get("times",[])
				for index in range(1,times.size()):
					intervals.append(times[index]-times[index-1])
				var success_times: Array = ability.get("success_times",[])
				for index in range(1,success_times.size()):
					success_intervals.append(success_times[index]-success_times[index-1])
			var averages: Dictionary = {}
			for key in counts:
				averages[key] = average(counts[key])
			averages["mean_success_interval"] = average(success_intervals) if not success_intervals.is_empty() else null
			averages["mean_interval"] = average(intervals) if not intervals.is_empty() else null
			averages["median_interval"] = quantile(intervals,0.5) if not intervals.is_empty() else null
			stats["abilities"][id] = averages
		actors[role] = stats
	var decisive: int = wins["left"]+wins["right"]
	var rate := float(wins["left"])/maxi(decisive,1)
	var z := 1.96
	var denominator := 1.0+z*z/maxi(decisive,1)
	var center := (rate+z*z/(2*maxi(decisive,1)))/denominator
	var half := z*sqrt(rate*(1-rate)/maxi(decisive,1)+z*z/(4*pow(maxi(decisive,1),2)))/denominator
	return {"matches":rows.size(),"wins":wins,"timeouts":timeouts,"draws":draws,
		"paired_bootstrap95":paired_interval(rows),"left_win_rate":rate if decisive > 0 else null,"wilson95":[center-half,center+half] if decisive > 0 else null,
		"mean_completed":average(durations) if not durations.is_empty() else null,"restricted_mean":average(all_durations),
		"median_completed":quantile(durations,0.5) if not durations.is_empty() else null,"p10":quantile(durations,0.1) if not durations.is_empty() else null,"p90":quantile(durations,0.9) if not durations.is_empty() else null,
		"histogram":histogram(durations),"two_hit_wins":two_hit_wins,"participants":actors}


static func by_candidate(rows: Array, candidates: Array) -> Dictionary:
	var results: Dictionary = {}
	for candidate in candidates:
		var filtered: Array = []
		for row in rows:
			if row["candidate"] == candidate["id"]:
				filtered.append(row)
		var overall := summarize(filtered)
		overall["groups"] = {}
		for group_kind in ["group","speed"]:
			var groups: Dictionary = {}
			for row in filtered:
				groups[str(row["scenario"][group_kind])] = true
			for group in groups:
				var group_rows: Array = []
				for row in filtered:
					if str(row["scenario"][group_kind]) == group:
						group_rows.append(row)
				overall["groups"][group_kind+"="+group] = summarize(group_rows)
		results[candidate["id"]] = overall
	return results


static func paired_interval(rows: Array) -> Variant:
	# Runs that reuse a scenario are correlated. Resample complete seed groups.
	var clusters: Dictionary = {}
	var decisive := 0
	for index in rows.size():
		var row: Dictionary = rows[index]
		var seed_value: int = row.get("scenario",{}).get("seed",index)
		if not clusters.has(seed_value):
			clusters[seed_value] = Vector2i.ZERO
		if not row["timeout"] and row.get("winner_role","") in ["left","right"]:
			clusters[seed_value].y += 1
			decisive += 1
			if row["winner_role"] == "left":
				clusters[seed_value].x += 1
	if decisive == 0:
		return null
	var values: Array = clusters.values()
	var samples: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	for iteration in 2000:
		var wins := 0
		var count := 0
		for index in values.size():
			var cluster: Vector2i = values[rng.randi_range(0,values.size()-1)]
			wins += cluster.x
			count += cluster.y
		if count > 0:
			samples.append(float(wins)/count)
	return [quantile(samples,0.025),quantile(samples,0.975)]
