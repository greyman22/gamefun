extends RefCounted
const Space = preload("res://scripts/core/actor_space.gd")
const Registry = preload("res://scripts/core/registry.gd")
const GROWTH: float = 120
const LOVE_TIME: float = 60
const RADIUS: float = 15

static func interval(mode: String) -> float:
	return 120.0 if mode == "debug" else randf_range(180, 300)

static func adult(record: Dictionary, now: float) -> bool:
	return now >= float(record.get("adult_at", 0))

static func create(model: RefCounted, id: String, point: Vector3, home: Vector3, mode: String, chick: bool = false) -> void:
	model.entities[id] = {"type":"hen", "position":point, "home":home, "adult_at":model.game_time + GROWTH if chick else 0.0, "next_egg":model.game_time + (GROWTH if chick else 0) + interval(mode), "love_until":0.0, "partner":"", "birth_at":0.0, "state":{}}

static func ensure_nearby(model: RefCounted, position: Vector3, mode: String) -> void:
	var spacing: int = 50 if mode == "debug" else 80
	var groups: Dictionary = model.landmarks.get_or_add("hen_groups", {})
	var gx := floori(position.x / spacing)
	var gz := floori(position.z / spacing)
	for x in range(gx - 2, gx + 3):
		for z in range(gz - 2, gz + 3):
			var key := "%s:%d,%d" % [mode, x, z]
			var jitter_x: int = 0 if mode == "debug" else model.generator.hash_at(x, z, 901) % 21 - 10
			var jitter_z: int = 0
			var point := Vector3(x * spacing + 18 + jitter_x, 0, z * spacing + 18 + jitter_z)
			if groups.has(key) or Vector2(point.x - position.x, point.z - position.z).length() > 75 or absf(point.x) > 1000 or absf(point.z) > 1000:
				continue
			point.y = model.generator.height(int(point.x), int(point.z))
			groups[key] = point
			var count: int = 3 + model.generator.hash_at(x, z, 907) % 2
			var spawned: int = 0
			for candidate in range(49):
				var spawn := point + Vector3(candidate % 7 - 3 + 0.5, 0, candidate / 7 - 3 + 0.5)
				spawn.y = model.generator.height(floori(spawn.x), floori(spawn.z))
				var cell := Vector3i(spawn.floor())
				if Registry.cube(model.block(cell + Vector3i.DOWN)) and not Registry.cube(model.block(cell)) and not Registry.cube(model.block(cell + Vector3i.UP)):
					create(model, "hen_%s_%d" % [key, spawned], spawn, point, mode)
					spawned += 1
					if spawned == count:
						break

static func resting(record: Dictionary, now: float) -> bool:
	return now < float(record.get("breed_ready_at", 0))

static func breeding_cooldown(mode: String) -> float:
	return 60.0 if mode == "debug" else 180.0

static func feed(model: RefCounted, id: String) -> bool:
	if not model.entities.has(id):
		return false
	var hen: Dictionary = model.entities[id]
	if hen.type != "hen" or resting(hen, model.game_time) or not adult(hen, model.game_time) or float(hen.love_until) > model.game_time or not str(hen.partner).is_empty():
		return false
	hen.love_until = model.game_time + LOVE_TIME
	hen.hearts_until = model.game_time + 1.5
	return true

static func cancel_pair(model: RefCounted, hen: Dictionary) -> void:
	var partner: String = hen.get("partner", "")
	hen.partner = ""
	hen.birth_at = 0.0
	if model.entities.has(partner):
		model.entities[partner].partner = ""
		model.entities[partner].birth_at = 0.0

static func mating_close(a: Vector3, b: Vector3) -> bool:
	return absf(a.y - b.y) <= 1.05 and Vector2(a.x - b.x, a.z - b.z).length() <= 0.9

static func birth_position(system: Node, center: Vector3, home: Vector3) -> Variant:
	for ring in [0.8, 1.3, 1.9, 2.5]:
		for index in range(12):
			var angle: float = index * TAU / 12
			var point: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) * ring
			if Vector2(point.x - home.x, point.z - home.z).length() > RADIUS:
				continue
			var found_ground: bool = false
			for offset in [0, 1, -1, 2, -2]:
				point.y = floorf(center.y) + offset
				var cell := Vector3i(point.floor())
				if Registry.cube(system.model.block(cell + Vector3i.DOWN)) and Space.clear(system.model, point, 0.16, 0.48):
					found_ground = true
					break
			if not found_ground:
				continue
			var free: bool = true
			for record: Dictionary in system.model.entities.values():
				if record.type in ["hen", "zombie"] and not record.get("state", {}).get("dead", false) and absf(record.position.y - point.y) < 1.5 and Vector2(record.position.x - point.x, record.position.z - point.z).length() < 0.6:
					free = false
					break
			if free:
				return point
	return null

static func tick(system: Node, delta: float) -> void:
	var model: RefCounted = system.model
	var now: float = model.game_time
	for id: String in system.active.keys():
		if not model.entities.has(id) or model.entities[id].type != "hen":
			continue
		var hen: Dictionary = model.entities[id]
		if adult(hen, now) and now >= float(hen.next_egg):
			system.spawn_drop("egg", hen.position + Vector3(0, 0.35, 0))
			hen.next_egg = now + interval(system.game_mode)
		if now >= float(hen.love_until):
			cancel_pair(model, hen)
		elif str(hen.partner).is_empty():
			for other_id: String in system.active:
				if other_id == id or not model.entities.has(other_id):
					continue
				var other: Dictionary = model.entities[other_id]
				if other.type == "hen" and adult(other, now) and float(other.love_until) > now and str(other.partner).is_empty() and hen.position.distance_to(other.position) <= 2.0:
					hen.partner = other_id
					other.partner = id
					break
		if not str(hen.partner).is_empty():
			var partner_id: String = hen.partner
			if not model.entities.has(partner_id) or float(model.entities[partner_id].love_until) <= now:
				cancel_pair(model, hen)
			else:
				var other: Dictionary = model.entities[partner_id]
				if mating_close(hen.position, other.position):
					if float(hen.birth_at) == 0:
						hen.birth_at = now + 3
						other.birth_at = hen.birth_at
					elif now >= float(hen.birth_at):
						var point: Variant = birth_position(system, (hen.position + other.position) * 0.5, hen.home)
						if point != null:
							create(model, "chick_%d_%d" % [Time.get_ticks_usec(), randi()], point, hen.home, system.game_mode, true)
							hen.breed_ready_at = now + breeding_cooldown(system.game_mode)
							other.breed_ready_at = hen.breed_ready_at
							hen.love_until = 0.0
							other.love_until = 0.0
							cancel_pair(model, hen)
							system.elapsed = 1
				else:
					hen.birth_at = 0.0
					other.birth_at = 0.0
		system.active[id].simulate(delta, system.soul_lure)
		hen.position = system.active[id].position
