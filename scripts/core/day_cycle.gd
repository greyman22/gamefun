extends RefCounted
const REAL_DAY_SECONDS: float = 1440.0
const DEBUG_DAY_SECONDS: float = 360.0

static func state(model: RefCounted) -> Dictionary:
	return model.landmarks.get_or_add("day_cycle", {"minute":480.0, "day":0, "paused":false})

static func advance(model: RefCounted, delta: float, debug_mode: bool) -> void:
	var value := state(model)
	if debug_mode and bool(value.paused):
		return
	var minute: float = float(value.minute) + maxf(0, delta) * 1440.0 / (DEBUG_DAY_SECONDS if debug_mode else REAL_DAY_SECONDS)
	value.day = int(value.day) + floori(minute / 1440.0)
	value.minute = fposmod(minute, 1440.0)

static func hour(model: RefCounted) -> float:
	return float(state(model).minute) / 60.0

static func phase(model: RefCounted) -> String:
	var h := hour(model)
	if h < 4 or h >= 22:
		return "Natt"
	if h < 5:
		return "Gryning"
	if h < 21:
		return "Dag"
	return "Skymning"

static func daylight(model: RefCounted) -> float:
	var h := hour(model)
	if h < 4 or h >= 22:
		return 0.0
	if h < 5:
		return smoothstep(4.0, 5.0, h)
	if h >= 21:
		return 1.0 - smoothstep(21.0, 22.0, h)
	return 1.0

static func can_sleep(model: RefCounted) -> bool:
	return hour(model) >= 21 or hour(model) < 4

static func sleep_to_dawn(model: RefCounted) -> bool:
	if not can_sleep(model):
		return false
	var value := state(model)
	if float(value.minute) >= 21 * 60:
		value.day = int(value.day) + 1
	value.minute = 240.0
	return true

static func clock_text(model: RefCounted) -> String:
	var minute := clampi(floori(float(state(model).minute)), 0, 1439)
	return "%02d:%02d" % [minute / 60, minute % 60]
