extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

var slots: Array[Dictionary] = []
var width: int = 2

func _init(grid_width: int = 2) -> void:
	width = grid_width
	for index in range(width * width):
		slots.append({"kind": "", "count": 0})

func recipe() -> Dictionary:
	var filled: Array[int] = []
	for index in range(slots.size()):
		if slots[index].count > 0:
			filled.append(index)
	if filled.is_empty():
		return {}
	var min_x: int = width
	var min_y: int = width
	var max_x: int = 0
	var max_y: int = 0
	for index in filled:
		min_x = mini(min_x, index % width)
		max_x = maxi(max_x, index % width)
		min_y = mini(min_y, index / width)
		max_y = maxi(max_y, index / width)
	var rows: PackedStringArray = []
	for y in range(min_y, max_y + 1):
		var row: String = ""
		for x in range(min_x, max_x + 1):
			var slot: Dictionary = slots[y * width + x]
			if x > min_x:
				row += ","
			row += slot.kind if slot.count > 0 else "."
		rows.append(row)
	var pattern: String = "/".join(rows)
	Registry.initialize()
	for result: Dictionary in Registry.catalog.recipes:
		if int(result.width) <= width and result.pattern == pattern:
			return {"kind": result.kind, "count": int(result.count), "inputs": filled}
	return {}

func craft(inventory: RefCounted) -> bool:
	var result := recipe()
	if result.is_empty() or not inventory.add_items(result.kind, result.count):
		return false
	for index in result.inputs:
		slots[index].count -= 1
		if slots[index].count == 0:
			slots[index].kind = ""
	return true

func craft_all(inventory: RefCounted) -> int:
	# Lock this recipe before consuming anything; leftovers may form another recipe.
	var result := recipe()
	if result.is_empty():
		return 0
	var batches: int = 2147483647
	for index in result.inputs:
		batches = mini(batches, slots[index].count)
	while batches > 0 and not inventory.can_add(result.kind, batches * result.count):
		batches -= 1
	if batches == 0 or not inventory.add_items(result.kind, batches * result.count):
		return 0
	for index in result.inputs:
		slots[index].count -= batches
		if slots[index].count == 0:
			slots[index].kind = ""
	return batches * result.count

func return_ingredients(inventory: RefCounted) -> bool:
	# Preflight every cell together so a full bag cannot lose ingredients.
	var restored = inventory.get_script().new()
	restored.slots.assign(inventory.slots.duplicate(true))
	for slot in slots:
		if slot.count > 0 and not restored.add_items(slot.kind, slot.count):
			return false
	inventory.slots.assign(restored.slots)
	for slot in slots:
		slot.kind = ""
		slot.count = 0
	return true

func transfer(inventory: RefCounted, source: int, destination: int) -> bool:
	if source < 0 or source >= 32 + slots.size() or destination < 0 or destination >= 32 + slots.size() or source == destination:
		return false
	if source < 32 and destination < 32:
		return inventory.move_stack(source, destination)
	var origin: Dictionary = inventory.slots[source] if source < 32 else slots[source - 32]
	var target: Dictionary = inventory.slots[destination] if destination < 32 else slots[destination - 32]
	if origin.count == 0:
		return false
	if target.count > 0 and target.kind != origin.kind:
		if source >= 32 and destination >= 32:
			slots[source - 32] = target
			slots[destination - 32] = origin
			return true
		return false
	var amount: int = mini(origin.count, Registry.stack_limit(origin.kind) - target.count)
	# Deposit one ingredient per drop, making multi-slot recipes easy to lay out.
	if source < 32 and destination >= 32:
		amount = mini(amount, 1)
	if amount <= 0:
		return false
	target.kind = origin.kind
	target.count += amount
	origin.count -= amount
	if origin.count == 0:
		origin.kind = ""
	return true
