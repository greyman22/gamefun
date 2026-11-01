extends RefCounted

const SPACING: int = 36
const GROWTH_SECONDS: float = 120

static func centre(model: RefCounted, gx: int, gz: int) -> Vector2i:
	return Vector2i(gx * SPACING + 10 + model.generator.hash_at(gx, gz, 201) % 2, gz * SPACING + 10 + model.generator.hash_at(gx, gz, 203) % 2)

static func ensure_nearby(model: RefCounted, position: Vector3) -> void:
	if int(model.landmarks.get("berry_group_version", 0)) != 2:
		for id: String in model.entities.keys():
			if id.begins_with("wild_berry_"):
				model.entities.erase(id)
		model.landmarks.berry_groups = {}
		model.landmarks.berry_group_version = 2
	if not model.landmarks.has("berry_groups"):
		model.landmarks.berry_groups = {}
	var groups: Dictionary = model.landmarks.berry_groups
	var gx: int = floori(position.x / SPACING)
	var gz: int = floori(position.z / SPACING)
	var radius: int = ceili(80.0 / SPACING)
	for x in range(gx - radius, gx + radius + 1):
		for z in range(gz - radius, gz + radius + 1):
			var key: String = "%d,%d" % [x, z]
			var point: Vector2i = centre(model, x, z)
			if groups.has(key) or Vector2(point.x - position.x, point.y - position.z).length() > 80:
				continue
			if absi(point.x) > 1016 or absi(point.y) > 1016:
				continue
			var candidates: Array[Dictionary] = []
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var cell := Vector3i(point.x + dx, model.generator.height(point.x + dx, point.y + dz), point.y + dz)
					if model.kind_at(cell + Vector3i.DOWN) == "dirt" and model.kind_at(cell) == "air" and at_cell(model, cell).is_empty():
						candidates.append({"cell": cell, "rank": model.generator.hash_at(cell.x, cell.z, 211)})
			candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank < b.rank)
			if candidates.size() < 5:
				groups[key] = {"centre": point, "count": 0}
				continue
			var count: int = mini(candidates.size(), 5 + model.generator.hash_at(x, z, 217) % 6)
			groups[key] = {"centre": point, "count": count}
			for index in range(count):
				var id: String = "wild_berry_v2_%s_%d" % [key, index]
				var cell: Vector3i = candidates[index].cell
				model.entities[id] = {"type": "berry_bush", "position": Vector3(cell) + Vector3(0.5, 0, 0.5), "cell": cell, "planted_at": model.game_time - GROWTH_SECONDS, "ripe_at": model.game_time}

static func stage(record: Dictionary, time: float) -> int:
	return clampi(floori((time - float(record.planted_at)) / 30.0), 0, 3)

static func ripe(record: Dictionary, time: float) -> bool:
	return time >= float(record.ripe_at) and time - float(record.planted_at) >= GROWTH_SECONDS

static func at_cell(model: RefCounted, cell: Vector3i) -> String:
	for id: String in model.entities:
		var record: Dictionary = model.entities[id]
		if record.type == "berry_bush" and record.cell == cell:
			return id
	return ""

static func plant(model: RefCounted, cell: Vector3i) -> String:
	if model.kind_at(cell + Vector3i.DOWN) != "dirt" or model.kind_at(cell) != "air" or not at_cell(model, cell).is_empty():
		return ""
	var id: String = "planted_berry_%d_%d" % [Time.get_ticks_usec(), randi()]
	model.entities[id] = {"type": "berry_bush", "position": Vector3(cell) + Vector3(0.5, 0, 0.5), "cell": cell, "planted_at": model.game_time, "ripe_at": model.game_time + GROWTH_SECONDS}
	return id

static func harvest(model: RefCounted, id: String) -> int:
	if not model.entities.has(id) or not ripe(model.entities[id], model.game_time):
		return 0
	model.entities.erase(id)
	return randi_range(1, 4)

static func harvest_seconds(tool: String) -> float:
	return 0.8 if tool == "axe" else 3.0
