class_name CampaignUnits
extends RefCounted
## Campaign fractions stay isolated from the integer combat contract of free play.
const SCALE: int = 1000

static func pack(value: float) -> int:
	assert(is_finite(value), "Campaign value must be finite.")
	return roundi(value * SCALE)

static func unpack(value: int) -> float:
	return float(value) / SCALE

static func text(value: int) -> String:
	var number := unpack(value)
	return str(roundi(number)) if is_equal_approx(number, roundf(number)) else ("%.2f" % number).rstrip("0").rstrip(".")
