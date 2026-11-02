extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
const Inventory = preload("res://scripts/inventory.gd")
var inventory: RefCounted
var crafting: RefCounted
var held: Dictionary = {"kind": "", "count": 0}
var painted: Array[int] = []
var left_down: bool = false
var source: int = -1
var result_drag: bool = false

func bind(bag: RefCounted, table: RefCounted) -> void:
	inventory = bag
	crafting = table

func slot(index: int) -> Dictionary:
	return inventory.slots[index] if index < 36 else crafting.slots[index - 36]

func reset() -> void:
	held = {"kind": "", "count": 0}
	cancel_paint()

func cancel_paint() -> void:
	painted.clear()
	left_down = false
	source = -1
	result_drag = false

func take_result(all_batches: bool = false) -> int:
	if held.count > 0:
		return 0
	var result: Dictionary = crafting.recipe()
	if result.is_empty():
		return 0
	var output := Inventory.new()
	var amount: int = crafting.craft_all(output) if all_batches else (int(result.count) if crafting.craft(output) else 0)
	if amount > 0:
		cancel_paint()
		held = Registry.stack(result.kind, amount)
		left_down = true
		result_drag = true
	return amount

func store_held() -> bool:
	if held.count == 0:
		return true
	if not inventory.add_stack(held):
		return false
	held = {"kind": "", "count": 0}
	return true

func press(index: int, button: int, shift: bool = false) -> void:
	if index < 0 or index >= 36 + crafting.slots.size():
		return
	var target := slot(index)
	if button == MOUSE_BUTTON_RIGHT:
		cancel_paint()
		if held.count == 0 and target.count > 0:
			var amount: int = ceili(float(target.count) / 2.0)
			held = Registry.stack(target.kind, amount, target)
			target.count -= amount
			if target.count == 0:
				Registry.clear_slot(target)
		elif held.count > 0 and (target.count == 0 or target.kind == held.kind) and target.count < Registry.stack_limit(held.kind):
			Registry.fill_slot(target, held, 1)
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
			Registry.clear_slot(target)
			source = index
	else:
		painted.append(index)

func touch(index: int) -> void:
	if not left_down or held.count == 0 or index == source or index < 0 or index >= 36 + crafting.slots.size():
		return
	var target := slot(index)
	if target.count == 0 or (target.kind == held.kind and target.count < Registry.stack_limit(held.kind)):
		if not painted.has(index):
			painted.append(index)

func finish() -> void:
	apply_distribution(distribution_plan(painted, true))
	cancel_paint()

func distribute(indices: Array[int]) -> void:
	apply_distribution(distribution_plan(indices, false))

func preview() -> Dictionary:
	return distribution_plan(painted, true) if left_down else {"slots": {}, "held": held.duplicate()}

func distribution_plan(indices: Array[int], allow_swap: bool) -> Dictionary:
	var targets: Dictionary = {}
	for index in indices:
		targets[index] = slot(index).duplicate()
	var hand := held.duplicate()
	if allow_swap and hand.count > 0 and indices.size() == 1:
		var target: Dictionary = targets[indices[0]]
		if target.count > 0 and (target.kind != hand.kind or (Registry.tool(hand.kind) and target != hand)):
			targets[indices[0]] = hand
			return {"slots": targets, "held": target}
	# Round robin gives 10 -> 3,3,2,2 in visit order, respecting stack caps.
	while hand.count > 0:
		var placed: bool = false
		for index in indices:
			var target: Dictionary = targets[index]
			if (target.count == 0 or target.kind == hand.kind) and target.count < Registry.stack_limit(hand.kind):
				Registry.fill_slot(target, hand, 1)
				hand.count -= 1
				placed = true
				if hand.count == 0:
					break
		if not placed:
			break
	if hand.count == 0:
		hand.kind = ""
	return {"slots": targets, "held": hand}

func apply_distribution(plan: Dictionary) -> void:
	for index: int in plan.slots:
		var target := slot(index)
		Registry.assign_slot(target, plan.slots[index])
	held = plan.held
	clear_empty_hand()

func clear_empty_hand() -> void:
	if held.count == 0:
		Registry.clear_slot(held)

func quick_move(index: int) -> void:
	var origin := slot(index)
	if origin.count == 0:
		return
	if index < 36:
		held = origin.duplicate()
		Registry.clear_slot(origin)
		var targets: Array[int] = []
		for cell in range(crafting.slots.size()):
			targets.append(36 + cell)
		distribute(targets)
		Registry.assign_slot(origin, held)
		held = {"kind": "", "count": 0}
	else:
		while origin.count > 0 and inventory.add_stack(Registry.stack(origin.kind, 1, origin)):
			origin.count -= 1
		if origin.count == 0:
			Registry.clear_slot(origin)

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
	var pool: Array[Dictionary] = []
	for entry: Dictionary in crafting.slots + [held]:
		if entry.count > 0:
			pool.append(entry.duplicate(true))
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
			var ingredient: Dictionary = {}
			for entry in pool:
				if entry.kind == kind and entry.count > 0:
					ingredient = Registry.stack(kind, 1, entry)
					entry.count -= 1
					break
			if ingredient.is_empty():
				ingredient = bag.take_stack(kind)
			if ingredient.is_empty():
				return false
			var target_x: int = x+int(recipe.get("offset_x_by_width",{}).get(str(crafting.width),recipe.get("offset_x",0)))
			if target_x<0 or target_x>=crafting.width:
				return false
			output[y * crafting.width + target_x] = ingredient
	for entry in pool:
		if entry.count > 0 and not bag.add_stack(entry):
			return false
	inventory.slots.assign(bag.slots)
	crafting.slots.assign(output)
	reset()
	return true

func return_all() -> bool:
	var bag := Inventory.new()
	bag.slots.assign(inventory.slots.duplicate(true))
	for entry: Dictionary in crafting.slots + [held]:
		if entry.count > 0 and not bag.add_stack(entry):
			return false
	inventory.slots.assign(bag.slots)
	for entry in crafting.slots:
		Registry.clear_slot(entry)
	reset()
	return true
