extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
const Generator = preload("res://scripts/core/generator.gd")
const REACH: int = 8
const NEIGHBOURS = [Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.DOWN]
var model: RefCounted
var columns: Dictionary = {}

func configure(data: RefCounted) -> void:
	if model != null and model.block_changed.is_connected(changed):
		model.block_changed.disconnect(changed)
	model = data
	columns.clear()
	model.block_changed.connect(changed)

func changed(_cell: Vector3i) -> void:
	columns.clear()

func blocks_daylight(value: int) -> bool:
	# Door windows pass daylight while the closed leaf still blocks bodies
	# and navigation. Keep the lower wooden panel opaque.
	return Registry.cube(value) and Registry.kind(value) not in ["door_top","foliage"]

func roof(x: int, z: int) -> int:
	var column := Vector2i(x, z)
	if columns.has(column):
		return columns[column]
	# Query the generator and sparse edits without generating remote chunks above us.
	var top: int = mini(model.generator.max_y(), model.generator.height(x, z) + 8)
	var column_key := Vector3i(floori(float(x) / 16), 0, floori(float(z) / 16))
	for chunk_key: Vector3i in model.edits:
		if chunk_key.x == column_key.x and chunk_key.z == column_key.z:
			top = maxi(top, mini(model.generator.max_y(), chunk_key.y * 16 + 15))
	var trees: Array = model.generator.trees_in_chunk(column_key)
	var highest: int = Generator.MIN_Y - 1
	for y in range(top, Generator.MIN_Y - 1, -1):
		var cell := Vector3i(x, y, z)
		var edits: Dictionary = model.edits.get(model.key(cell), {})
		var value: int
		if edits.has(model.index(cell)):
			value = edits[model.index(cell)]
		else:
			value = model.generator.ground(cell)
			if value == 0:
				for tree: Dictionary in trees:
					value = model.generator.tree_kind(cell, tree)
					if value != 0:
						break
		if blocks_daylight(value):
			highest = y
			break
	if columns.size() > 2048:
		columns.clear()
	columns[column] = highest
	return highest

func exposure(position: Vector3) -> float:
	var origin := Vector3i(position.floor())
	if origin.y > roof(origin.x, origin.z):
		return 1.0
	var queue: Array[Vector3i] = [origin]
	var distances: Dictionary = {origin: 0}
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector3i = queue[cursor]
		cursor += 1
		var distance: int = distances[cell]
		if cell.y > roof(cell.x, cell.z):
			# Open edges remain fully lit; attenuation begins inside a passage.
			return pow(clampf(float(REACH-distance)/float(REACH-2),0,1), 3)
		if distance >= REACH - 1:
			continue
		for direction: Vector3i in NEIGHBOURS:
			var next: Vector3i = cell + direction
			if not distances.has(next) and not blocks_daylight(model.block(next)):
				distances[next] = distance + 1
				queue.append(next)
	return 0.0
