extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
var data: RefCounted
var touched: Dictionary = {}

func place(world: RefCounted, debug_mode: bool) -> Dictionary:
	data = world
	touched.clear()
	var distance: float = 40.0 if debug_mode else float(200 + data.generator.hash_at(91, 17) % 201)
	var best := Vector2i.ZERO
	var best_score: float = -INF
	var phase: float = float(data.generator.hash_at(71, 83)) / 2147483647.0 * TAU
	for index in range(48):
		var angle: float = phase + TAU * index / 48.0
		var candidate := Vector2i(roundi(cos(angle) * distance), 12 + roundi(sin(angle) * distance))
		var low: int = 1000
		var high: int = -1000
		for x in [-7, 0, 7]:
			for z in [-6, 0, 6]:
				var height: int = data.generator.height(candidate.x + x, candidate.y + z)
				low = mini(low, height)
				high = maxi(high, height)
		var front_low: int = 1000
		var front_high: int = -1000
		for x in [-6, 0, 6]:
			for z in [8, 12, 18]:
				var height: int = data.generator.height(candidate.x + x, candidate.y + z)
				front_low = mini(front_low, height)
				front_high = maxi(front_high, height)
		# Prefer gentle lower ground and a level approach, while avoiding deep basins.
		var score: float = -(high - low) * 6.0 - (front_high - front_low) * 5.0 - absf((low + high) * 0.5 - (front_low + front_high) * 0.5) * 3.0 - high * 0.8 - maxf(0, 1 - low) * 12.0
		if score > best_score:
			best_score = score
			best = candidate
	var heights: Array[int] = []
	for x in range(-5, 6):
		for z in range(-4, 5):
			heights.append(data.generator.height(best.x + x, best.y + z))
	heights.sort()
	# Match the median ground instead of raising the entire house to the highest corner.
	var floor_y: int = maxi(0, heights[heights.size() / 2] - 1)
	var base := Vector3i(best.x, floor_y, best.y)
	for x in range(-12, 13):
		for z in range(-9, 23):
			var ground: int = data.generator.height(best.x + x, best.y + z)
			var blend: float = maxf(clampf((absf(x) - 6) / 6.0, 0, 1), clampf((-z - 6) / 3.0 if z < 0 else (z - 12) / 10.0, 0, 1))
			var surface: int = roundi(lerpf(floor_y + 1, ground, blend))
			if surface == ground and blend >= 1:
				continue
			for y in range(mini(ground - 1, surface - 1), surface):
				write(Vector3i(best.x + x, y, best.y + z), "stone" if absi(x) <= 5 and absi(z) <= 4 and y < floor_y else "dirt")
			for y in range(surface, maxi(ground + 9, floor_y + 13 if absi(x) <= 7 and absi(z) <= 6 else surface + 3)):
				write(Vector3i(best.x + x, y, best.y + z), "air")
	# Broken plank floor, stone footing and log frame all remain ordinary editable voxels.
	for x in range(-5, 6):
		for z in range(-4, 5):
			write(base + Vector3i(x, 0, z), "stone" if damage(x, z, 0) % 13 == 0 else "planks")
			if absi(x) != 5 and absi(z) != 4:
				continue
			for y in range(1, 5):
				if z == 4 and absi(x) <= 0 and y <= 2:
					continue
				if y in [2, 3] and ((absi(x) == 5 and absi(z) == 2) or (absi(z) == 4 and absi(x) == 3)):
					continue
				var frame: bool = (absi(x) == 5 and absi(z) == 4) or y == 4
				if not frame and damage(x, z, y) % 11 == 0:
					continue
				write(base + Vector3i(x, y, z), "wood" if frame else ("stone" if y == 1 else "planks"))
	# Gable roof with missing sections and exposed log ridge.
	for x in range(-6, 7):
		for z in range(-5, 6):
			var y: int = 5 + (6 - absi(x)) / 2
			if damage(x, z, 19) % 7 < 2:
				continue
			write(base + Vector3i(x, y, z), "wood" if x == 0 else "planks")
	for y in range(1, 11):
		for x in range(2, 5):
			for z in range(-3, 0):
				if x == 3 and z == -2:
					write(base + Vector3i(x, y, z), "air")
				elif y < 10 or damage(x, z, y) % 3 != 0:
					write(base + Vector3i(x, y, z), "stone")
	data.cache.clear()
	for key: Vector3i in touched:
		for offset in [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var adjacent: Vector3i = key + offset
			data.revisions[adjacent] = int(data.revisions.get(adjacent, 0)) + 1
		data.block_changed.emit(key * 16)
	var record: Dictionary = {"base": base, "marker": Vector3(base) + Vector3(0.5, 14, 0.5), "spawn_distance": distance, "wander_radius": 15, "placement_version": 2}
	data.landmarks["zombie_house"] = record
	ensure_zombies(data)
	return record

func ensure_zombies(world: RefCounted) -> void:
	if not world.landmarks.has("zombie_house"):
		return
	var base: Vector3i = world.landmarks.zombie_house.base
	var home := Vector3(base) + Vector3(0.5, 0, 0.5)
	for index in range(5):
		var id: String = "house_zombie_%d" % index
		if world.entities.has(id):
			if not world.entities[id].has("spawn_position"):
				world.entities[id].spawn_position = world.entities[id].position
			continue
		var spawn: Vector3 = home
		for attempt in range(40):
			var angle: float = TAU * (float(index) / 5.0 + float(attempt) / 41.0)
			spawn = home + Vector3(cos(angle) * 11.5, 0, sin(angle) * 11.5)
			spawn.x = floorf(spawn.x) + 0.5
			spawn.z = floorf(spawn.z) + 0.5
			spawn.y = world.generator.height(floori(spawn.x), floori(spawn.z))
			for y in range(base.y + 12, int(spawn.y) - 2, -1):
				if Registry.cube(world.block(Vector3i(floori(spawn.x), y, floori(spawn.z)))):
					spawn.y = y + 1.0
					break
			var clear: bool = not Registry.cube(world.block(Vector3i((spawn + Vector3(0, 0.1, 0)).floor()))) and not Registry.cube(world.block(Vector3i((spawn + Vector3(0, 1.9, 0)).floor())))
			if clear and spawn.y <= maxi(base.y + 1, world.generator.height(floori(spawn.x), floori(spawn.z)) + 1):
				break
		world.entities[id] = {"type": "zombie", "home": home, "position": spawn, "spawn_position": spawn, "state": {"wait": index * 0.3}}

func damage(x: int, z: int, salt: int) -> int:
	return data.generator.hash_at(x, z, salt + 113)

func write(cell: Vector3i, kind: String) -> void:
	var key: Vector3i = data.key(cell)
	if not data.edits.has(key):
		data.edits[key] = {}
	data.edits[key][data.index(cell)] = Registry.id(kind)
	touched[key] = true
