extends SceneTree

const ARENA := preload("res://scenes/arena.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	var arena := ARENA.instantiate() as BallArena
	root.add_child(arena)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.opponent = null
	red.opponent = null
	blue.freeze = true
	red.freeze = true
	blue.set_physics_process(false)
	red.set_physics_process(false)
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	blue.apply_bite_marks(blue.global_position + Vector2(-100, 20), 34.0)
	var runoff := blue.get_node("BloodRunoff")
	runoff.set_process(false)
	var paths: Array = runoff.get("paths")
	check(paths.size() == 2, "Experiment must allocate only two bounded paths.")
	for path in paths:
		var previous_y := -INF
		for index in 25:
			var point: Vector2 = runoff.call("sample_point", path, float(index) / 24.0)
			check(point.y >= previous_y, "Surface flow must always descend under gravity.")
			check(point.length() <= 35.001, "Runoff path must remain on the circular body.")
			previous_y = point.y
	var upper_arrival := 0.0
	var lower_arrival := 0.0
	for path in paths:
		var points: PackedVector2Array = path["points"]
		if points[0].y < 0:
			upper_arrival = path["arrival"]
		else:
			lower_arrival = path["arrival"]
	check(lower_arrival < upper_arrival, "Lower wounds must reach the bottom faster.")
	var first: float = runoff.get("first_arrival")
	runoff.call("advance", first + 0.69)
	check(blood.drops.is_empty(), "Growing connected drop must not detach prematurely.")
	runoff.call("advance", 0.02)
	check(blood.drops.size() == 1, "Connected drop must detach once its neck finishes thinning.")
	var p: Vector2 = blood.drops[0]["position"]
	check(absf(p.x - blue.position.x) < 0.01 and p.y > blue.position.y + 35.0,
		"Detached blood must originate below the middle of the ball.")
	blood.advance(0.1)
	check(is_equal_approx(blood.drops[0]["position"].x, p.x)
		and blood.drops[0]["position"].y > p.y, "Detached drop must fall vertically down.")
	blue.call("_advance_bite_marks", 3.01)
	var age: float = runoff.get("age")
	runoff.call("advance", 3.01 - age)
	check(blue.bite_marks.size() == 2 and blue.wound_opacity() < 0.4 and bool(runoff.get("active")),
		"Wounds must fade gradually over 5s while runoff remains until 4s.")
	runoff.call("advance", 1.0)
	check(not bool(runoff.get("active")) and (runoff.get("paths") as Array).is_empty(),
		"Experiment must remove its paths at 4s.")
	blue.call("_advance_bite_marks", 1.0)
	check(blue.bite_marks.size() == 2 and blue.wound_opacity() < 0.2,
		"Faint wounds must remain after the 4-second runoff ends.")
	blue.call("_advance_bite_marks", 1.0)
	check(blue.bite_marks.is_empty() and blue.wound_opacity() == 0.0,
		"Wounds must disappear completely at five seconds.")
	check(blood.drops.size() <= 6, "A runoff event must emit a bounded small number of drops.")
	blue.apply_bite_marks(blue.global_position + Vector2.LEFT * 100, 34.0)
	runoff.set_process(false)
	blue.experimental_blood_runoff = false
	runoff.call("_process", 0.0)
	check(not bool(runoff.get("active")) and blue.bite_marks.size() == 2,
		"Disabling the experiment must remove runoff while preserving the bite wounds.")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: 2 surface paths; downward flow; lower wounds drain sooner; connected drop then detach; 5s fading wounds/4s runoff; bounded drops; toggle")
		quit(0)
	else:
		quit(1)
