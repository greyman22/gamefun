extends RefCounted

const VERSION: int = 1
const SIZE: int = 16
const MIN_Y: int = -64
const MAX_Y: int = 63
const HALF_WORLD: int = 1024
var seed_value: int
var noise := FastNoiseLite.new()
var column_cache: Dictionary = {}
var tree_cache: Dictionary = {}

func _init(world_seed: int = 20261030) -> void:
	seed_value = world_seed
	noise.seed = int(world_seed % 2147483647)
	noise.frequency = 0.012
	noise.fractal_octaves = 3

func hash_at(x: int, z: int, salt: int = 0) -> int:
	return absi((x * 73856093) ^ (z * 19349663) ^ (seed_value * 83492791) ^ (salt * 2654435761)) % 2147483647

func height(x: int, z: int) -> int:
	var key := Vector2i(x, z)
	if column_cache.has(key):
		return column_cache[key]
	var distance := Vector2(x, z).length()
	var blend: float = smoothstep(14.0, 36.0, distance)
	var value: int = roundi((noise.get_noise_2d(x, z) * 19.0 + noise.get_noise_2d(x * 0.3, z * 0.3) * 16.0) * blend)
	# A seed-specific hill keeps the familiar starting area recognisable.
	var center := Vector2(-10 + hash_at(1, 2) % 4, 11)
	var radius: float = 5.0 + hash_at(3, 4) % 3
	var hill: float = maxf(0, 1.0 - Vector2(x - center.x, z - center.y).length() / radius)
	value += floori(hill * (3 + hash_at(5, 6) % 3))
	column_cache[key] = value
	return value

func tree_info(gx: int, gz: int) -> Dictionary:
	var key := Vector2i(gx, gz)
	if tree_cache.has(key):
		return tree_cache[key]
	var h: int = hash_at(gx, gz, 21)
	var x: int = gx * 10 + 2 + h % 6
	var z: int = gz * 10 + 2 + (h / 7) % 6
	var result: Dictionary = {}
	if h % 5 != 0 and Vector2(x, z).length() > 15 and absi(x) < HALF_WORLD - 3 and absi(z) < HALF_WORLD - 3:
		result = {"base": Vector3i(x, height(x, z), z), "height": 3 + h % 4}
	tree_cache[key] = result
	return result

func trees_in_chunk(key: Vector3i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var low := key * SIZE
	for gx in range(floori(float(low.x - 2) / 10), floori(float(low.x + SIZE + 2) / 10) + 1):
		for gz in range(floori(float(low.z - 2) / 10), floori(float(low.z + SIZE + 2) / 10) + 1):
			var tree := tree_info(gx, gz)
			if not tree.is_empty():
				result.append(tree)
	return result

func tree_kind(cell: Vector3i, tree: Dictionary) -> int:
	var base: Vector3i = tree.base
	var delta := cell - base
	if delta.x == 0 and delta.z == 0 and delta.y >= 0 and delta.y < tree.height:
		return 3
	if delta.y == tree.height and absi(delta.x) <= 1 and absi(delta.z) <= 1:
		return 4
	if delta.y == tree.height + 1 and absi(delta.x) + absi(delta.z) <= 1:
		return 4
	return 0

func owner(cell: Vector3i) -> Dictionary:
	for tree: Dictionary in trees_in_chunk(Vector3i(floori(float(cell.x) / SIZE), 0, floori(float(cell.z) / SIZE))):
		if tree_kind(cell, tree) != 0 or cell == tree.base + Vector3i.DOWN:
			return tree
	return {}

func ground(cell: Vector3i) -> int:
	if cell.y < MIN_Y or absi(cell.x) >= HALF_WORLD or absi(cell.z) >= HALF_WORLD:
		return 7
	if cell.y > MAX_Y or cell.y >= height(cell.x, cell.z):
		return 0
	var gx: int = floori(float(cell.x) / 2) * 2
	var gz: int = floori(float(cell.z) / 2) * 2
	var gy: int = floori(float(cell.y) / 2) * 2
	var surface: int = mini(mini(height(gx, gz), height(gx + 1, gz)), mini(height(gx, gz + 1), height(gx + 1, gz + 1)))
	if gy + 1 > surface - 4:
		return 2
	return 1 if hash_at(gx + gy * 117, gz, 41) % 100 < (90 if gy < surface - 12 else 65) else 2

func generate(key: Vector3i) -> PackedByteArray:
	if column_cache.size() > 8192:
		column_cache.clear()
	if tree_cache.size() > 2048:
		tree_cache.clear()
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * SIZE * 2)
	var trees := trees_in_chunk(key)
	var origin := key * SIZE
	for z in range(SIZE):
		for x in range(SIZE):
			for y in range(SIZE):
				var cell := origin + Vector3i(x, y, z)
				var block: int = ground(cell)
				if block == 0 and cell.y <= height(cell.x, cell.z) + 8:
					for tree: Dictionary in trees:
						block = tree_kind(cell, tree)
						if block != 0:
							break
				data.encode_u16((x + SIZE * (y + SIZE * z)) * 2, block)
	return data
