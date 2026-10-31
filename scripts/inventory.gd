extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

const COLUMNS: int = 9
const SLOT_COUNT: int = 36
const HOTBAR_START: int = 27
const STACK_LIMIT: int = 64
var slots: Array[Dictionary] = []

func _init() -> void:
	Registry.initialize()
	for index in range(SLOT_COUNT):
		slots.append({"kind": "", "count": 0})

func count_item(kind: String) -> int:
	var total: int = 0
	for slot in slots:
		if slot.kind == kind:
			total += slot.count
	return total

func add_item(kind: String) -> bool:
	return add_stack({"kind": kind, "count": 1})

func add_stack(source: Dictionary) -> bool:
	var kind: String = source.kind
	var amount: int = int(source.count)
	if not Registry.catalog.items.has(kind) or not can_add(kind, amount):
		return false
	var remaining: int = amount
	for index in pickup_order():
		var slot: Dictionary = slots[index]
		if slot.kind == kind and slot.count < Registry.stack_limit(kind):
			var count: int = mini(remaining, Registry.stack_limit(kind) - slot.count)
			slot.count += count
			remaining -= count
	for index in pickup_order():
		if remaining <= 0:
			break
		var slot: Dictionary = slots[index]
		if slot.count == 0:
			var count: int = mini(remaining, Registry.stack_limit(kind))
			Registry.assign_slot(slot, Registry.stack(kind, count, source))
			remaining -= count
	return true

func take_stack(kind: String) -> Dictionary:
	for slot in slots:
		if slot.kind == kind and slot.count > 0:
			var result: Dictionary = Registry.stack(kind, 1, slot)
			take_from_slot(slots.find(slot))
			return result
	return {}

func wear(index: int) -> bool:
	var slot: Dictionary = slots[index]
	if slot.count == 0 or not Registry.tool(slot.kind):
		return false
	Registry.assign_slot(slot, Registry.stack(slot.kind, 1, slot))
	slot.durability -= 1
	if slot.durability <= 0:
		Registry.clear_slot(slot)
		return true
	return false

func can_add(kind: String, amount: int) -> bool:
	var capacity: int = 0
	for slot in slots:
		if slot.kind == "":
			capacity += Registry.stack_limit(kind)
		elif slot.kind == kind:
			capacity += Registry.stack_limit(kind) - slot.count
	return amount > 0 and capacity >= amount

func add_items(kind: String, amount: int) -> bool:
	return add_stack({"kind": kind, "count": amount})

func pickup_order() -> Array[int]:
	var order: Array[int] = []
	for row in range(3, -1, -1):
		for column in range(COLUMNS):
			order.append(row * COLUMNS + column)
	return order

func take_item(kind: String) -> bool:
	for slot in slots:
		if slot.kind == kind and slot.count > 0:
			slot.count -= 1
			if slot.count == 0:
				Registry.clear_slot(slot)
			return true
	return false

func take_from_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or slots[index].count == 0:
		return false
	slots[index].count -= 1
	if slots[index].count == 0:
		Registry.clear_slot(slots[index])
	return true

func move_stack(source: int, destination: int) -> bool:
	if source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT or source == destination:
		return false
	var origin: Dictionary = slots[source]
	var target: Dictionary = slots[destination]
	if origin.count == 0:
		return false
	if target.kind == origin.kind and Registry.tool(origin.kind) and target != origin:
		slots[source] = target
		slots[destination] = origin
		return true
	if target.kind == origin.kind:
		var moved: int = mini(origin.count, Registry.stack_limit(origin.kind) - target.count)
		if moved == 0:
			return false
		target.count += moved
		origin.count -= moved
		if origin.count == 0:
			Registry.clear_slot(origin)
	else:
		slots[source] = target
		slots[destination] = origin
	return true
