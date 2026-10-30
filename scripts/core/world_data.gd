extends RefCounted

signal block_changed(cell: Vector3i)
const Registry = preload("res://scripts/core/registry.gd")
const Generator = preload("res://scripts/core/generator.gd")
const SIZE: int = 16
const CACHE_LIMIT: int = 384
var seed_value: int
var generator: RefCounted
var world_id: String
var edits: Dictionary = {}
var revisions: Dictionary = {}
var cache: Dictionary = {}
var entities: Dictionary = {}
var decay: Dictionary = {}
var game_time: float = 0
var decay_tick: float = 0

func _init(value: int = 20261030) -> void:
	Registry.initialize()
	seed_value = value
	generator = Generator.new(value)
	world_id = "world_%d_%d" % [value, Time.get_unix_time_from_system()]

static func key(cell: Vector3i) -> Vector3i:
	return Vector3i(floori(float(cell.x) / SIZE), floori(float(cell.y) / SIZE), floori(float(cell.z) / SIZE))

static func index(cell: Vector3i) -> int:
	return posmod(cell.x, SIZE) + SIZE * (posmod(cell.y, SIZE) + SIZE * posmod(cell.z, SIZE))

static func text_key(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]

static func parse_key(value: String) -> Vector3i:
	var parts := value.split(",")
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))

func chunk(chunk_key: Vector3i) -> PackedByteArray:
	if cache.has(chunk_key):
		return cache[chunk_key]
	var data: PackedByteArray = generator.generate(chunk_key)
	for offset: int in edits.get(chunk_key, {}):
		data.encode_u16(offset * 2, edits[chunk_key][offset])
	if cache.size() >= CACHE_LIMIT:
		cache.erase(cache.keys()[0])
	cache[chunk_key] = data
	return data

func block(cell: Vector3i) -> int:
	return chunk(key(cell)).decode_u16(index(cell) * 2)

func kind_at(cell: Vector3i) -> String:
	return Registry.kind(block(cell))

func set_block(cell: Vector3i, kind_name: String) -> bool:
	if not Registry.catalog.blocks.has(kind_name) or kind_at(cell) == "bedrock":
		return false
	var chunk_key := key(cell)
	var value: int = Registry.id(kind_name)
	if not edits.has(chunk_key):
		edits[chunk_key] = {}
	edits[chunk_key][index(cell)] = value
	cache.erase(chunk_key)
	for offset in [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
		var adjacent := key(cell + offset)
		revisions[adjacent] = int(revisions.get(adjacent, 0)) + 1
	block_changed.emit(cell)
	if kind_name == "air":
		schedule_decay(cell)
	return true

func worker_edits(chunk_key: Vector3i) -> Dictionary:
	var result: Dictionary = {}
	for offset in [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
		var adjacent: Vector3i = chunk_key + offset
		if edits.has(adjacent):
			result[adjacent] = edits[adjacent].duplicate()
	return result

func supported(tree: Dictionary) -> bool:
	for y in range(tree.height):
		if kind_at(tree.base + Vector3i(0, y, 0)) != "wood":
			return false
	return Registry.cube(block(tree.base + Vector3i.DOWN))

func schedule_decay(cell: Vector3i) -> void:
	var tree: Dictionary = generator.owner(cell)
	if tree.is_empty() or supported(tree):
		return
	var top: Vector3i = tree.base + Vector3i(0, tree.height, 0)
	for x in range(-1, 2):
		for z in range(-1, 2):
			queue_leaf(top + Vector3i(x, 0, z), tree)
	for offset in [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		queue_leaf(top + Vector3i.UP + offset, tree)

func queue_leaf(cell: Vector3i, tree: Dictionary) -> void:
	if not decay.has(cell) and kind_at(cell) == "foliage":
		var seconds: float = 30.0 + generator.hash_at(cell.x + cell.y * 43, cell.z, 91) % 60001 / 1000.0
		decay[cell] = {"deadline": game_time + seconds, "tree": tree.duplicate()}

func advance(delta: float) -> void:
	game_time += delta
	decay_tick += delta
	if decay_tick < 1.0:
		return
	decay_tick = 0
	for cell: Vector3i in decay.keys():
		var record: Dictionary = decay[cell]
		if supported(record.tree) or kind_at(cell) != "foliage":
			decay.erase(cell)
		elif record.deadline <= game_time:
			set_block(cell, "air")
			decay.erase(cell)

func export_state() -> Dictionary:
	var saved_edits: Dictionary = {}
	for chunk_key: Vector3i in edits:
		var pairs := PackedInt32Array()
		for offset: int in edits[chunk_key]:
			pairs.append(offset)
			pairs.append(edits[chunk_key][offset])
		saved_edits[text_key(chunk_key)] = pairs
	return {"seed": seed_value, "generator_version": Generator.VERSION, "world_id": world_id, "time": game_time, "ids": Registry.saved_ids(), "edits": saved_edits, "entities": entities.duplicate(true), "decay": decay.duplicate(true)}

func import_state(state: Dictionary) -> bool:
	if not state.has_all(["seed", "generator_version", "world_id", "time", "ids", "edits", "entities", "decay"]):
		return false
	if not state.ids is Dictionary or not state.edits is Dictionary or not state.entities is Dictionary or not state.decay is Dictionary:
		return false
	if state.get("generator_version", -1) != Generator.VERSION:
		return false
	for record: Variant in state.entities.values():
		if not record is Dictionary or not record.has_all(["type", "position"]) or not record.position is Vector3:
			return false
		if record.type in ["pickup", "torch"] and not Registry.catalog.items.has(record.get("kind", "")):
			return false
	var mapping: Dictionary = {}
	for value: int in state.ids:
		var name: String = state.ids[value]
		if not Registry.catalog.blocks.has(name):
			return false
		mapping[value] = Registry.id(name)
	var imported: Dictionary = {}
	for encoded: String in state.edits:
		var pairs: PackedInt32Array = state.edits[encoded]
		if pairs.size() % 2 != 0:
			return false
		var changes: Dictionary = {}
		for cursor in range(0, pairs.size(), 2):
			if pairs[cursor] < 0 or pairs[cursor] >= 4096 or not mapping.has(pairs[cursor + 1]):
				return false
			changes[pairs[cursor]] = mapping[pairs[cursor + 1]]
		imported[parse_key(encoded)] = changes
	seed_value = state.seed
	generator = Generator.new(seed_value)
	world_id = state.world_id
	game_time = state.time
	edits = imported
	entities = state.entities.duplicate(true)
	decay = state.decay.duplicate(true)
	cache.clear()
	revisions.clear()
	return true
