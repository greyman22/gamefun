extends RefCounted

static var definitions: Dictionary = {}

static func reload_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat.json"))
	if not parsed is Dictionary or not parsed.has_all(["actors", "weapons", "defense_scale", "zombie_respawn"]) or float(parsed.defense_scale) <= 0:
		return false
	if not parsed.actors is Dictionary or not parsed.weapons is Dictionary or not parsed.zombie_respawn is Dictionary:
		return false
	for kind: String in ["player", "zombie"]:
		if not parsed.actors.has(kind):
			return false
	for actor: Dictionary in parsed.actors.values():
		if float(actor.get("health",100))<=0 or not actor.has_all(["name", "defense", "attack", "interval", "reach"]) or float(actor.defense) < 0 or float(actor.attack) < 0 or float(actor.interval) <= 0 or float(actor.reach) <= 0:
			return false
	for weapon: Dictionary in parsed.weapons.values():
		if not weapon.has_all(["name", "attack_bonus", "interval", "reach"]) or float(weapon.attack_bonus) < 0 or float(weapon.interval) <= 0 or float(weapon.reach) <= 0:
			return false
	if float(parsed.zombie_respawn.get("debug", 0)) <= 0 or float(parsed.zombie_respawn.get("play", 0)) <= 0:
		return false
	var knockback: Variant = parsed.get("knockback", {})
	if not knockback is Dictionary or float(knockback.get("meters_per_damage", 0.045)) < 0 or float(knockback.get("duration", 0.18)) <= 0:
		return false
	definitions = parsed
	return true

static func initialize() -> void:
	if definitions.is_empty():
		assert(reload_data(), "Invalid combat definitions")

static func stats(actor: String, weapon: String = "") -> Dictionary:
	initialize()
	var result: Dictionary = definitions.actors[actor].duplicate()
	if definitions.weapons.has(weapon):
		var equipment: Dictionary = definitions.weapons[weapon]
		result.attack += equipment.attack_bonus
		result.interval = equipment.interval
		result.reach = equipment.reach
		result.sweep_degrees = equipment.get("sweep_degrees", 0)
	return result

static func damage(attack: float, defense: float) -> float:
	initialize()
	return maxf(0, attack) * float(definitions.defense_scale) / (float(definitions.defense_scale) + maxf(0, defense))

static func respawn_seconds(mode: String) -> float:
	initialize()
	return float(definitions.zombie_respawn.get(mode, 180))

# Initialize once in the persistent record, never when merely reactivating a node.
static func starting_health(record: Dictionary, kind: String) -> float:
	var state: Dictionary=record.get("state",{})
	if not record.has("health_factor"):
		record.health_factor=1.0 if state.has("health") else randf_range(0.8,1.0)
	if not state.has("health"):
		state.health=float(stats(kind).get("health",100))*float(record.health_factor)
		record.state=state
	return float(state.health)

static func grown_health(record: Dictionary, kind: String) -> float:
	return float(stats(kind).health)*float(record.get("health_factor",1.0))
