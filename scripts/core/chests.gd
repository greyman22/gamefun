extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
const SLOTS: int = 27
const SIDES = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]

static func neighbours(model: RefCounted, cell: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for side: Vector3i in SIDES:
		if model.kind_at(cell + side) == "chest":
			result.append(cell + side)
	return result

static func can_place(_model: RefCounted, _cell: Vector3i) -> bool:
	return true

static func pair(model: RefCounted, cell: Vector3i) -> void:
	var links: Dictionary = model.landmarks.get_or_add("chest_pairs", {})
	if links.has(cell):
		return
	for other in neighbours(model, cell):
		if not links.has(other):
			links[cell] = other
			links[other] = cell
			return

static func unpair(model: RefCounted, cell: Vector3i) -> void:
	var links: Dictionary = model.landmarks.get_or_add("chest_pairs", {})
	if links.has(cell):
		links.erase(links[cell])
		links.erase(cell)

static func cells(model: RefCounted, cell: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = [cell]
	var links: Dictionary = model.landmarks.get("chest_pairs", {})
	if links.has(cell) and model.kind_at(links[cell]) == "chest":
		result.append(links[cell])
	result.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x < b.x if a.x != b.x else a.z < b.z)
	return result

static func contents(model: RefCounted, cell: Vector3i) -> Array:
	if not model.containers.has(cell):
		var slots: Array[Dictionary] = []
		for index in range(SLOTS):
			slots.append({"kind": "", "count": 0})
		model.containers[cell] = slots
	return model.containers[cell]

static func combined(model: RefCounted, cell: Vector3i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part in cells(model, cell):
		for slot: Dictionary in contents(model, part):
			result.append(slot)
	return result

static func remove(model: RefCounted, cell: Vector3i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in model.containers.get(cell, []):
		if slot.count > 0:
			result.append(slot.duplicate(true))
	model.containers.erase(cell)
	return result
