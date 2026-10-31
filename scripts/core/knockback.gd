extends RefCounted

const Combat = preload("res://scripts/core/combat.gd")
var remaining := Vector3.ZERO
var time_left: float = 0

func active() -> bool:
	return time_left > 0 and remaining.length_squared() > 0.00000001

func start(from: Vector3, target: Vector3, damage: float) -> void:
	var direction: Vector3 = target - from
	direction.y = 0
	if direction.length_squared() < 0.000001 or damage <= 0:
		return
	Combat.initialize()
	var settings: Dictionary = Combat.definitions.get("knockback", {})
	remaining += direction.normalized() * damage * float(settings.get("meters_per_damage", 0.045))
	time_left = float(settings.get("duration", 0.18))

func start_distance(from: Vector3, target: Vector3, distance: float) -> void:
	var direction: Vector3 = target - from
	direction.y = 0
	if direction.length_squared() < 0.000001:
		return
	remaining += direction.normalized() * distance
	time_left = 0.18

func step(delta: float) -> Vector3:
	if not active() or delta <= 0:
		return Vector3.ZERO
	var portion: float = minf(1, delta / time_left)
	var movement: Vector3 = remaining * portion
	remaining -= movement
	time_left = maxf(0, time_left - delta)
	return movement

func stop() -> void:
	remaining = Vector3.ZERO
	time_left = 0

func snapshot() -> Dictionary:
	return {"remaining": remaining, "time_left": time_left}

func restore(state: Dictionary) -> void:
	remaining = state.get("remaining", Vector3.ZERO)
	time_left = maxf(0, float(state.get("time_left", 0)))
