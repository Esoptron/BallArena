extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func event(id: String, amount: int) -> Dictionary:
	return {"actor_id": id, "target_id": id, "ability_id": "probe", "kind": "heal", "time": 1.0, "amount": amount}

func run() -> void:
	var a := ArenaBall.new()
	a.actor_id = "a"
	a.character_id = &"ordinary"
	var b := ArenaBall.new()
	b.actor_id = "b"
	b.character_id = &"ordinary"
	var first := CombatDirector.new()
	var second := CombatDirector.new()
	var metrics := CombatMetrics.new()
	var actors: Array[ArenaBall] = [a]
	metrics.attach(actors, first)
	first.event_recorded.emit(event("a", 3))
	var snapshot := metrics.finish(actors, 1.0, false)
	first.event_recorded.emit(event("a", 2))
	check(snapshot["participants"]["a"]["healing"] == 3, "Completed reports must not share live participant dictionaries.")
	check(metrics.participants["a"]["healing"] == 5, "Snapshot isolation must not stop live collection.")
	actors = [b]
	metrics.attach(actors, second)
	check(metrics.events == 0 and not metrics.participants.has("a"), "Attaching a new match must clear prior counters and participants.")
	first.event_recorded.emit(event("a", 9))
	check(metrics.events == 0, "A previous director must stop sending events after collector reuse.")
	metrics.attach(actors, second)
	second.event_recorded.emit(event("b", 4))
	check(metrics.events == 1 and metrics.participants["b"]["healing"] == 4, "Reattaching the same director must not duplicate signal delivery.")
	metrics.detach()
	second.event_recorded.emit(event("b", 4))
	check(metrics.events == 1, "Explicit detach must end observation.")
	first.free()
	second.free()
	a.free()
	b.free()
	print("PASS: independent immutable battle reports and reusable metric collectors" if failures.is_empty() else "FAIL: combat metrics")
	quit(0 if failures.is_empty() else 1)
