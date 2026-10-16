extends RefCounted
## Shared screen-space reservations; never changes world geometry or physics.
const EDGE := 16.0
const GAP := 12.0
const BATTLE_TOP := 64.0
const BATTLE_BOTTOM := 30.0

static func landscape(screen: Vector2) -> bool:
	return screen.x >= 600.0 and screen.x > screen.y

static func side_width(screen: Vector2) -> float:
	return clampf(screen.x * 0.17, 128.0, 170.0)

static func battle_rect(screen: Vector2, world: Vector2) -> Rect2:
	var rail := side_width(screen) + EDGE + GAP
	var available := Vector2(maxf(40.0, screen.x - rail * 2.0), maxf(40.0, screen.y - BATTLE_TOP - BATTLE_BOTTOM))
	var zoom := minf(1.0, minf(available.x / world.x, available.y / world.y))
	var projected := world * zoom
	return Rect2(Vector2((screen.x - projected.x) * 0.5, BATTLE_TOP + (available.y - projected.y) * 0.5), projected)
