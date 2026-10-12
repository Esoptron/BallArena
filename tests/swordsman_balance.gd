extends SceneTree
## Actual Godot physics + production ability scripts; no separate combat model.
const ARENA := preload("res://scenes/arena.tscn")
var results: Array[Dictionary] = []
var active: Array[Dictionary] = []
var completed: int = 0
var elapsed_ticks: int = 0


func _initialize() -> void:
	run.call_deferred()


func disable_visuals(node: Node) -> void:
	node.set_process(false)
	for child in node.get_children():
		disable_visuals(child)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "pilot"
	var samples := int(args[1]) if args.size() > 1 else 48
	var seed_base := int(args[2]) if args.size() > 2 else 61000
	var output := args[3] if args.size() > 3 else "user://balance.json"
	var candidates: Array[Dictionary] = []
	if mode == "pilot":
		candidates = [
			{"name":"D8_S320_G1_8", "damage":8, "speed":320.0, "damage_gain":1, "speed_gain":8.0},
			{"name":"D12_S320_G1_8", "damage":12, "speed":320.0, "damage_gain":1, "speed_gain":8.0},
			{"name":"D16_S320_G1_8", "damage":16, "speed":320.0, "damage_gain":1, "speed_gain":8.0},
			{"name":"D20_S320_G1_8", "damage":20, "speed":320.0, "damage_gain":1, "speed_gain":8.0},
			{"name":"D12_S280_G1_8", "damage":12, "speed":280.0, "damage_gain":1, "speed_gain":8.0},
			{"name":"D12_S360_G1_8", "damage":12, "speed":360.0, "damage_gain":1, "speed_gain":8.0},
			{"name":"D12_S320_G2_12", "damage":12, "speed":320.0, "damage_gain":2, "speed_gain":12.0},
			{"name":"D12_S320_G1_4", "damage":12, "speed":320.0, "damage_gain":1, "speed_gain":4.0},
		]
	elif mode == "validation":
		var template := ARENA.instantiate() as BallArena
		var sword := template.get_node("Balls/BlueBall/Sword") as SwordAbility
		candidates = [{"name":"selected", "damage":sword.base_damage,
			"speed":template.ball_speed*sword.starting_speed_ratio,
			"damage_gain":sword.damage_gain, "speed_gain":sword.speed_gain}]
		template.free()
	else:
		candidates.assign(JSON.parse_string(FileAccess.get_file_as_string(mode)))
	# Even/odd trials exchange character colors and physics insertion order.
	# Each candidate uses identical seeds, uniform positions, directions and sword phases.
	for candidate in candidates:
		results.append({"parameters":candidate, "sword_wins":0, "vampire_wins":0,
			"timeouts":0, "duration_sum":0.0, "trials":[]})
	for trial in samples:
		for index in candidates.size():
			var candidate := candidates[index]
			var arena := ARENA.instantiate() as BallArena
			var slot := active.size()
			arena.position = Vector2((slot % 16) * 1400.0, (slot / 16) * 1000.0)
			arena.spawn_seed = seed_base + trial
			arena.blue_character = 2 if trial % 2 == 0 else 1
			arena.red_character = 1 if trial % 2 == 0 else 2
			var sword_ball := arena.get_node("Balls/BlueBall" if trial % 2 == 0 else "Balls/RedBall") as ArenaBall
			var vampire := arena.get_node("Balls/RedBall" if trial % 2 == 0 else "Balls/BlueBall") as ArenaBall
			var sword := sword_ball.get_node("Sword") as SwordAbility
			sword.base_damage = candidate["damage"]
			sword.starting_speed_ratio = float(candidate["speed"]) / arena.ball_speed
			sword.damage_gain = candidate["damage_gain"]
			sword.speed_gain = candidate["speed_gain"]
			root.add_child(arena)
			disable_visuals(arena)
			for ball in [sword_ball, vampire]:
				ball.combat_effects = null
				ball.blood_effects = null
				ball.experimental_blood_runoff = false
				for connection in ball.health_delta.get_connections():
					ball.health_delta.disconnect(connection["callable"])
			active.append({"arena":arena, "sword":sword_ball, "vampire":vampire,
				"candidate":index, "seed":seed_base+trial, "sword_blue":trial%2==0})
	var total := active.size()
	print("BALANCE START: %d actual matches, %d candidates, %dHz" % [total,candidates.size(),Engine.physics_ticks_per_second])
	var limit := Engine.physics_ticks_per_second * 600
	while not active.is_empty() and elapsed_ticks < limit:
		await physics_frame
		elapsed_ticks += 1
		for i in range(active.size()-1,-1,-1):
			var match_data := active[i]
			var sword_ball: ArenaBall = match_data["sword"]
			var vampire: ArenaBall = match_data["vampire"]
			if sword_ball.current_health > 0 and vampire.current_health > 0:
				continue
			finish_match(match_data, false)
			active.remove_at(i)
		if elapsed_ticks % (Engine.physics_ticks_per_second*60) == 0:
			print("BALANCE progress: %d/%d complete after %ds simulated" % [completed,total,elapsed_ticks/Engine.physics_ticks_per_second])
	for match_data in active:
		finish_match(match_data, true)
	active.clear()
	for result in results:
		var decisive: int = result["sword_wins"] + result["vampire_wins"]
		result["sword_win_rate"] = float(result["sword_wins"]) / maxi(decisive,1)
		result["average_seconds"] = result["duration_sum"] / samples
		print("RESULT %s: sword=%d vampire=%d timeout=%d rate=%.3f avg=%.1fs" %
			[result["parameters"]["name"],result["sword_wins"],result["vampire_wins"],
			result["timeouts"],result["sword_win_rate"],result["average_seconds"]])
	var report := {"mode":mode,"seed_base":seed_base,"samples_per_candidate":samples,
		"physics_hz":Engine.physics_ticks_per_second,"time_limit_seconds":600,"results":results}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not save balance report.")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"  "))
	quit(0)


func finish_match(match_data: Dictionary, timeout: bool) -> void:
	var sword_ball: ArenaBall = match_data["sword"]
	var vampire: ArenaBall = match_data["vampire"]
	var result := results[match_data["candidate"]]
	var seconds := float(elapsed_ticks) / Engine.physics_ticks_per_second
	var winner := "timeout"
	if timeout:
		result["timeouts"] += 1
	elif vampire.current_health == 0 and sword_ball.current_health > 0:
		result["sword_wins"] += 1
		winner = "sword"
	else:
		result["vampire_wins"] += 1
		winner = "vampire"
	result["duration_sum"] += seconds
	result["trials"].append({"seed":match_data["seed"],"sword_blue":match_data["sword_blue"],
		"winner":winner,"seconds":seconds,"sword_hp":sword_ball.current_health,
		"vampire_hp":vampire.current_health,
		"sword_hits":(sword_ball.get_node("Sword") as SwordAbility).successful_hits})
	match_data["arena"].queue_free()
	completed += 1
