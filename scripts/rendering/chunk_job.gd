extends RefCounted

const Generator = preload("res://scripts/core/generator.gd")
const Registry = preload("res://scripts/core/registry.gd")
const SIZE: int = 16
var seed_value: int
var chunk_key: Vector3i
var edits: Dictionary
var result: Dictionary = {}
var generated: Dictionary = {}
var generator: RefCounted
var shared_cache: RefCounted

func _init(world_seed: int, key: Vector3i, changes: Dictionary, base_cache: RefCounted = null) -> void:
	seed_value = world_seed
	chunk_key = key
	edits = changes
	shared_cache = base_cache

func block(cell: Vector3i) -> int:
	var key := Vector3i(floori(float(cell.x) / SIZE), floori(float(cell.y) / SIZE), floori(float(cell.z) / SIZE))
	if not generated.has(key):
		var data: PackedByteArray = generator.generate(key) if shared_cache == null else shared_cache.get_base(seed_value, key, generator)
		for index: int in edits.get(key, {}):
			data.encode_u16(index * 2, edits[key][index])
		generated[key] = data
	var offset: int = posmod(cell.x, SIZE) + SIZE * (posmod(cell.y, SIZE) + SIZE * posmod(cell.z, SIZE))
	return generated[key].decode_u16(offset * 2)

func run() -> void:
	generator = Generator.new(seed_value)
	var padded := PackedInt32Array()
	padded.resize(18 * 18 * 18)
	var origin := chunk_key * SIZE
	for z in range(SIZE):
		for y in range(SIZE):
			for x in range(SIZE):
				padded[x + 1 + 18 * (y + 1 + 18 * (z + 1))] = block(origin + Vector3i(x, y, z))
	for axis in range(3):
		for side in [-1, SIZE]:
			for a in range(SIZE):
				for b in range(SIZE):
					var local := Vector3i.ZERO
					local[axis] = side
					local[(axis + 1) % 3] = a
					local[(axis + 2) % 3] = b
					padded[local.x + 1 + 18 * (local.y + 1 + 18 * (local.z + 1))] = block(origin + local)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Greedy rectangles merge coplanar equal-material faces. UVs repeat per metre.
	for axis in range(3):
		var u_axis: int = (axis + 1) % 3
		var v_axis: int = (axis + 2) % 3
		for direction in [-1, 1]:
			var normal := Vector3i.ZERO
			normal[axis] = direction
			for layer in range(SIZE):
				var mask := PackedInt32Array()
				mask.resize(SIZE * SIZE)
				for v in range(SIZE):
					for u in range(SIZE):
						var cell := Vector3i.ZERO
						cell[axis] = layer
						cell[u_axis] = u
						cell[v_axis] = v
						var slot: int = cell.x + 1 + 18 * (cell.y + 1 + 18 * (cell.z + 1))
						var value: int = padded[slot]
						if Registry.cube(value) and not Registry.cube(padded[slot + direction * [1, 18, 324][axis]]):
							mask[u + v * SIZE] = value
				for v in range(SIZE):
					var u: int = 0
					while u < SIZE:
						var value: int = mask[u + v * SIZE]
						if value == 0:
							u += 1
							continue
						var width: int = 1
						while u + width < SIZE and mask[u + width + v * SIZE] == value:
							width += 1
						var height: int = 1
						var extend: bool = true
						while v + height < SIZE and extend:
							for du in range(width):
								if mask[u + du + (v + height) * SIZE] != value:
									extend = false
									break
							if extend:
								height += 1
						for dv in range(height):
							for du in range(width):
								mask[u + du + (v + dv) * SIZE] = 0
						var start := Vector3.ZERO
						start[axis] = layer + (1 if direction > 0 else 0)
						start[u_axis] = u
						start[v_axis] = v
						var du := Vector3.ZERO
						var dv := Vector3.ZERO
						du[u_axis] = width
						dv[v_axis] = height
						var first: int = vertices.size()
						vertices.append_array(PackedVector3Array([start, start + du, start + du + dv, start + dv]))
						var tile: int = Registry.tile(value, normal)
						var encoded := Color(float(tile % 256) / 255.0, float(tile / 256) / 255.0, 0, 1)
						for index in range(4):
							normals.append(Vector3(normal))
							colors.append(encoded)
						for corner: Vector3 in [start, start + du, start + du + dv, start + dv]:
							uvs.append(Vector2(corner.x, corner.z) if axis == 1 else (Vector2(corner.z, -corner.y) if axis == 0 else Vector2(corner.x, -corner.y)))
						for index in ([0, 2, 1, 0, 3, 2] if direction > 0 else [0, 1, 2, 0, 2, 3]):
							indices.append(first + index)
						u += width
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	result = {"arrays": arrays, "vertices": vertices.size(), "data": generated.get(chunk_key, PackedByteArray())}
