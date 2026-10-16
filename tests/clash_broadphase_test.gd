extends SceneTree
class Probe:
	extends CombatDirector
	var skip_filter: bool = false
	var checks: int = 0
	func _weapon_sweep_bounds(ability: CombatAbility) -> Rect2:
		return Rect2(-Vector2.ONE*10000,Vector2.ONE*20000) if skip_filter else super._weapon_sweep_bounds(ability)
	func _weapon_contact(a: CombatAbility,b: CombatAbility,fraction: float) -> Dictionary:
		checks += 1
		return super._weapon_contact(a,b,fraction)
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character_id = &"katana"
	arena.red_character_id = &"katana"
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	var probe := Probe.new()
	arena.add_child(probe)
	probe.set_physics_process(false)
	probe.register(a)
	probe.register(b)
	a.position = Vector2(190,300)
	b.position = Vector2(790,300)
	for fighter in [a,b]:
		fighter.freeze = true
		fighter.get_node("Katana").combat_step(0.01)
	var timings: Array[int] = []
	var counts: Array[int] = []
	for disabled in [true,false]:
		probe.skip_filter = disabled
		probe.checks = 0
		var start := Time.get_ticks_usec()
		for sample in 500:
			probe._queue_weapon_clashes()
		counts.append(probe.checks)
		timings.append(Time.get_ticks_usec()-start)
	check(counts[0] > 0 and counts[1] == 0,"Separated weapons must skip all detailed collision checks.")
	a.position = Vector2(400,300)
	b.position = Vector2(600,300)
	var x := a.get_node("Katana") as KatanaAbility
	var y := b.get_node("Katana") as KatanaAbility
	x.rotation = 0.0
	y.rotation = PI
	for weapon in [x,y]:
		weapon.on_relocated()
		weapon._clashed_this_step = false
	var collisions: Array[float] = []
	for disabled in [true,false]:
		probe.skip_filter = disabled
		probe.pending.clear()
		probe._queue_weapon_clashes()
		check(probe.pending.size() == 1,"Filter must retain a genuine overlapping weapon clash.")
		if not probe.pending.is_empty(): collisions.append(probe.pending[0]["fraction"])
	check(collisions.size() == 2 and collisions[0] == collisions[1],"Filter must preserve genuine clash timing.")
	print("500 distant weapon scans: detailed checks ",counts[0]," -> ",counts[1],"; usec ",timings[0]," -> ",timings[1])
	arena.queue_free()
	await process_frame
	print("Weapon broadphase: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
