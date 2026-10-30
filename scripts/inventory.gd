extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

const SLOT_COUNT: int = 32
const HOTBAR_START: int = 24
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
	Registry.initialize()
	if not Registry.catalog.items.has(kind):
		return false
	for index in pickup_order():
		var slot: Dictionary = slots[index]
		if slot.kind == kind and slot.count < Registry.stack_limit(kind):
			slot.count += 1
			return true
	for index in pickup_order():
		var slot: Dictionary = slots[index]
		if slot.kind == "":
			slot.kind = kind
			slot.count = 1
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
	if not can_add(kind, amount):
		return false
	for index in range(amount):
		add_item(kind)
	return true

func pickup_order() -> Array[int]:
	var order: Array[int] = []
	for row in range(3, -1, -1):
		for column in range(8):
			order.append(row * 8 + column)
	return order

func take_item(kind: String) -> bool:
	for slot in slots:
		if slot.kind == kind and slot.count > 0:
			slot.count -= 1
			if slot.count == 0:
				slot.kind = ""
			return true
	return false

func take_from_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or slots[index].count == 0:
		return false
	slots[index].count -= 1
	if slots[index].count == 0:
		slots[index].kind = ""
	return true

func move_stack(source: int, destination: int) -> bool:
	if source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT or source == destination:
		return false
	var origin: Dictionary = slots[source]
	var target: Dictionary = slots[destination]
	if origin.count == 0:
		return false
	if target.kind == origin.kind:
		var moved: int = mini(origin.count, Registry.stack_limit(origin.kind) - target.count)
		if moved == 0:
			return false
		target.count += moved
		origin.count -= moved
		if origin.count == 0:
			origin.kind = ""
	else:
		slots[source] = target
		slots[destination] = origin
	return true
