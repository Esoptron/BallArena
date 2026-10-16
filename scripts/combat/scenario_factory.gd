class_name CombatScenarioFactory
extends RefCounted


static func make(seed_value: int, mixed: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var groups := ["random","head_on","glancing","parallel","wall","corner"]
	var group: String = groups[seed_value % groups.size()] if mixed else "random"
	var a := Vector2(rng.randf_range(40,920),rng.randf_range(40,560))
	var b := Vector2(rng.randf_range(40,920),rng.randf_range(40,560))
	while a.distance_to(b) < 155:
		b = Vector2(rng.randf_range(40,920),rng.randf_range(40,560))
	var da := Vector2.from_angle(rng.randf_range(-PI,PI))
	var db := Vector2.from_angle(rng.randf_range(-PI,PI))
	match group:
		"head_on":
			a = Vector2(320,300); b = Vector2(640,300)
			da = Vector2.RIGHT; db = Vector2.LEFT
		"glancing":
			a = Vector2(300,220); b = Vector2(660,380)
			da = (b-a).normalized().rotated(0.18)
			db = (a-b).normalized().rotated(0.18)
		"parallel":
			a = Vector2(330,240); b = Vector2(480,340)
			da = Vector2.RIGHT; db = Vector2.RIGHT
		"wall":
			a = Vector2(45,200); b = Vector2(220,290)
			da = Vector2(-1,0.2).normalized(); db = (a-b).normalized()
		"corner":
			a = Vector2(45,45); b = Vector2(210,150)
			da = Vector2(-1,-1).normalized(); db = (a-b).normalized()
	var speed: float = [240.0,320.0,400.0][(seed_value/6)%3] if mixed else 320.0
	return {"seed":seed_value,"group":group,"a":[a.x,a.y],"b":[b.x,b.y],
		"direction_a":[da.x,da.y],"direction_b":[db.x,db.y],"speed":speed,
		"ratio_a":rng.randf_range(0.85,1.15) if mixed else 1.0,
		"ratio_b":rng.randf_range(0.85,1.15) if mixed else 1.0}
