extends RefCounted

static var catalog: Dictionary = {}
static var by_id: Dictionary = {}
static var tiles: Dictionary = {}

static func initialize() -> void:
	if not catalog.is_empty():
		return
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	if not definitions is Dictionary:
		push_error("Invalid content catalog")
		return
	var valid: bool = install(definitions)
	assert(valid, "Invalid content catalog")

static func install(definitions: Dictionary) -> bool:
	if not definitions.has_all(["blocks", "items", "recipes", "actors"]):
		return false
	var used: Dictionary = {}
	for name: String in definitions.blocks:
		var definition: Dictionary = definitions.blocks[name]
		var value: int = int(definition.get("id", -1))
		if value < 0 or value > 65535 or used.has(value) or not definition.has_all(["name", "color"]):
			return false
		used[value] = name
	for name: String in definitions.items:
		var item: Dictionary = definitions.items[name]
		if item.has("block") and not definitions.blocks.has(item.block):
			return false
		if item.get("tool", false) and int(item.get("max_uses", 100)) <= 0:
			return false
		if int(item.get("stack", 64)) < 1:
			return false
	# These IDs form generator version 1's stable terrain vocabulary.
	for pair in [["air", 0], ["stone", 1], ["dirt", 2], ["wood", 3], ["foliage", 4], ["bedrock", 7]]:
		if not definitions.blocks.has(pair[0]) or int(definitions.blocks[pair[0]].id) != pair[1]:
			return false
	catalog = definitions.duplicate(true)
	by_id.clear()
	tiles.clear()
	var index: int = 0
	for kind: String in catalog.blocks:
		var definition: Dictionary = catalog.blocks[kind]
		assert(not by_id.has(int(definition.id)), "Duplicate block ID")
		by_id[int(definition.id)] = kind
		tiles[int(definition.id)] = index * 3
		index += 1
	return true

static func id(kind: String) -> int:
	return int(catalog.blocks.get(kind, {}).get("id", 0))

static func kind(value: int) -> String:
	return by_id.get(value, "air")

static func label(kind_name: String) -> String:
	return catalog.items.get(kind_name, catalog.blocks.get(kind_name, {})).get("name", "Hand" if kind_name == "" else kind_name)

static func cube(value: int) -> bool:
	return value != 0 and catalog.blocks.get(kind(value), {}).get("shape", "cube") in ["cube", "door", "fence"]

static func breakable(kind_name: String) -> bool:
	return kind_name != "air" and catalog.blocks.get(kind_name, {}).get("breakable", true)

static func tool(kind_name: String) -> bool:
	return catalog.items.get(kind_name, {}).get("tool", false)

static func stack_limit(kind_name: String) -> int:
	return 1 if tool(kind_name) else int(catalog.items.get(kind_name, {}).get("stack", 64))

static func tool_type(tool_name: String) -> String:
	return str(catalog.items.get(tool_name,{}).get("tool_type",tool_name))

static func seconds(tool_name: String, kind_name: String) -> float:
	if not breakable(kind_name):
		return INF
	var block: Dictionary = catalog.blocks.get(kind_name, {})
	var base: float = float(block.get("seconds", 3.0))
	return float(block.get("tool_seconds",0.7))*float(catalog.items.get(tool_name,{}).get("work_time_multiplier",1.0)) if block.get("tool","")==tool_type(tool_name) else base

static func drops(tool_name: String, kind_name: String) -> bool:
	var block: Dictionary = catalog.blocks.get(kind_name, {})
	return block.get("drop", true) and (not block.get("requires_tool_for_drop", false) or block.get("tool") == tool_type(tool_name))

static func tile(value: int, normal: Vector3i) -> int:
	return int(tiles.get(value, 0)) + (1 if normal.y > 0 else (2 if normal.y < 0 else 0))

static func saved_ids() -> Dictionary:
	return by_id.duplicate()

static func durability_max(kind_name: String) -> int:
	return int(catalog.items.get(kind_name, {}).get("max_uses", 100))

static func remaining_uses(slot: Dictionary) -> int:
	return int(slot.get("durability", slot.get("max_durability", durability_max(slot.kind))))

static func stack(kind_name: String, count: int = 1, source: Dictionary = {}) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result.kind = kind_name
	result.count = count
	if tool(kind_name):
		result.max_durability = int(source.get("max_durability", durability_max(kind_name)))
		result.durability = int(source.get("durability", result.max_durability))
	return result

static func assign_slot(target: Dictionary, source: Dictionary) -> void:
	var copy: Dictionary = source.duplicate(true)
	target.clear()
	target.merge(copy)

static func clear_slot(target: Dictionary) -> void:
	target.clear()
	target.merge({"kind": "", "count": 0})

static func fill_slot(target: Dictionary, source: Dictionary, amount: int) -> void:
	var total: int = int(target.count) + amount
	if target.count == 0:
		assign_slot(target, source)
	target.count = total
