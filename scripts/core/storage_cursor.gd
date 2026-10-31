extends "res://scripts/core/stack_cursor.gd"

func storage_order() -> Array[int]:
	var result: Array[int] = []
	for row in range(crafting.slots.size() / 9 - 1, -1, -1):
		for column in range(9):
			result.append(36 + row * 9 + column)
	return result

func move_into(origin: Dictionary, order: Array[int]) -> void:
	# Merge first, then fill empty cells, both from the bottom row upwards.
	for empty in [false, true]:
		for index in order:
			if origin.count <= 0:
				Registry.clear_slot(origin)
				return
			var target: Dictionary = slot(index)
			if (target.count == 0) != empty or (target.count > 0 and target.kind != origin.kind):
				continue
			var amount: int = mini(origin.count, Registry.stack_limit(origin.kind) - target.count)
			if amount > 0:
				Registry.fill_slot(target, origin, amount)
				origin.count -= amount
	if origin.count == 0:
		Registry.clear_slot(origin)

func quick_move(index: int) -> void:
	cancel_paint()
	move_into(slot(index), storage_order() if index < 36 else inventory.pickup_order())

func return_all() -> bool:
	cancel_paint()
	if held.count > 0:
		move_into(held, inventory.pickup_order())
	if held.count > 0:
		move_into(held, storage_order())
	return held.count == 0
