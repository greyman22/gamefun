extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
const Inventory = preload("res://scripts/inventory.gd")
var inventory: RefCounted
var crafting: RefCounted
var held: Dictionary = {"kind": "", "count": 0}
var painted: Array[int] = []
var left_down: bool = false
var source: int = -1

func bind(bag: RefCounted, table: RefCounted) -> void:
	inventory = bag
	crafting = table

func slot(index: int) -> Dictionary:
	return inventory.slots[index] if index < 32 else crafting.slots[index - 32]

func reset() -> void:
	held = {"kind": "", "count": 0}
	cancel_paint()

func cancel_paint() -> void:
	painted.clear()
	left_down = false
	source = -1

func press(index: int, button: int, shift: bool = false) -> void:
	if index < 0 or index >= 32 + crafting.slots.size():
		return
	var target := slot(index)
	if button == MOUSE_BUTTON_RIGHT:
		cancel_paint()
		if held.count == 0 and target.count > 0:
			var amount: int = ceili(float(target.count) / 2.0)
			held = {"kind": target.kind, "count": amount}
			target.count -= amount
			if target.count == 0:
				target.kind = ""
		elif held.count > 0 and (target.count == 0 or target.kind == held.kind) and target.count < Registry.stack_limit(held.kind):
			target.kind = held.kind
			target.count += 1
			held.count -= 1
			clear_empty_hand()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if shift and held.count == 0:
		quick_move(index)
		return
	cancel_paint()
	left_down = true
	if held.count == 0:
		if target.count > 0:
			held = target.duplicate()
			target.count = 0
			target.kind = ""
			source = index
	else:
		painted.append(index)

func touch(index: int) -> void:
	if not left_down or held.count == 0 or index == source or index < 0 or index >= 32 + crafting.slots.size():
		return
	var target := slot(index)
	if target.count == 0 or (target.kind == held.kind and target.count < Registry.stack_limit(held.kind)):
		if not painted.has(index):
			painted.append(index)

func finish() -> void:
	if held.count > 0 and painted.size() == 1:
		var target := slot(painted[0])
		if target.count > 0 and target.kind != held.kind:
			var previous := target.duplicate()
			target.kind = held.kind
			target.count = held.count
			held = previous
			cancel_paint()
			return
	distribute(painted)
	cancel_paint()

func distribute(indices: Array[int]) -> void:
	# Round robin gives 10 -> 3,3,2,2 in visit order, respecting stack caps.
	while held.count > 0:
		var placed: bool = false
		for index in indices:
			var target := slot(index)
			if (target.count == 0 or target.kind == held.kind) and target.count < Registry.stack_limit(held.kind):
				target.kind = held.kind
				target.count += 1
				held.count -= 1
				placed = true
				if held.count == 0:
					break
		if not placed:
			break
	clear_empty_hand()

func clear_empty_hand() -> void:
	if held.count == 0:
		held.kind = ""

func quick_move(index: int) -> void:
	var origin := slot(index)
	if origin.count == 0:
		return
	if index < 32:
		held = origin.duplicate()
		origin.count = 0
		origin.kind = ""
		var targets: Array[int] = []
		for cell in range(crafting.slots.size()):
			targets.append(32 + cell)
		distribute(targets)
		origin.kind = held.kind
		origin.count = held.count
		held = {"kind": "", "count": 0}
	else:
		while origin.count > 0 and inventory.add_item(origin.kind):
			origin.count -= 1
		if origin.count == 0:
			origin.kind = ""

func available() -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in inventory.slots + crafting.slots + [held]:
		if entry.count > 0:
			counts[entry.kind] = int(counts.get(entry.kind, 0)) + entry.count
	return counts

func requirements(recipe: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for row in recipe.pattern.split("/"):
		for kind in row.split(","):
			if kind != ".":
				counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

func can_fill(recipe: Dictionary) -> bool:
	if int(recipe.width) > crafting.width:
		return false
	var counts := available()
	var needed := requirements(recipe)
	for kind: String in needed:
		if int(counts.get(kind, 0)) < needed[kind]:
			return false
	return true

func fill_template(recipe: Dictionary) -> bool:
	if not can_fill(recipe):
		return false
	var bag := Inventory.new()
	bag.slots.assign(inventory.slots.duplicate(true))
	var pool: Dictionary = {}
	for entry: Dictionary in crafting.slots + [held]:
		if entry.count > 0:
			pool[entry.kind] = int(pool.get(entry.kind, 0)) + entry.count
	var output: Array[Dictionary] = []
	for index in range(crafting.slots.size()):
		output.append({"kind": "", "count": 0})
	var rows: PackedStringArray = recipe.pattern.split("/")
	for y in range(rows.size()):
		var kinds: PackedStringArray = rows[y].split(",")
		for x in range(kinds.size()):
			var kind: String = kinds[x]
			if kind == ".":
				continue
			if int(pool.get(kind, 0)) > 0:
				pool[kind] -= 1
			elif not bag.take_item(kind):
				return false
			output[y * crafting.width + x] = {"kind": kind, "count": 1}
	for kind: String in pool:
		if pool[kind] > 0 and not bag.add_items(kind, pool[kind]):
			return false
	inventory.slots.assign(bag.slots)
	crafting.slots.assign(output)
	reset()
	return true

func return_all() -> bool:
	var bag := Inventory.new()
	bag.slots.assign(inventory.slots.duplicate(true))
	for entry: Dictionary in crafting.slots + [held]:
		if entry.count > 0 and not bag.add_items(entry.kind, entry.count):
			return false
	inventory.slots.assign(bag.slots)
	for entry in crafting.slots:
		entry.kind = ""
		entry.count = 0
	reset()
	return true
