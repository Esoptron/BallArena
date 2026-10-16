@tool
extends RefCounted
## Relative gameplay masses, not kilograms. Shared by bodies and weapons.
enum Category { LIGHT, BELOW_AVERAGE, MEDIUM, ABOVE_AVERAGE, HEAVY }
const WALL_BOOSTS := [0.60, 0.45, 0.30, 0.20, 0.12]
const FACTORS := [0.6, 0.8, 1.0, 1.3, 1.6]

static func factor(category: int) -> float:
	return FACTORS[clampi(category, Category.LIGHT, Category.HEAVY)]


static func wall_boost(category: int) -> float:
	return WALL_BOOSTS[clampi(category, Category.LIGHT, Category.HEAVY)]

static func boost_loss(own_category: int, other_category: int, collision_strength: float) -> float:
	# Equal weights cancel a full head-on boost; a heavier body retains more.
	return clampf(collision_strength * 2.0 * factor(other_category) / (factor(own_category) + factor(other_category)),0.0,1.0)
