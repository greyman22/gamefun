extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Crafting = preload("res://scripts/crafting.gd")
const Cursor = preload("res://scripts/core/stack_cursor.gd")
const Daylight = preload("res://scripts/core/daylight.gd")
const Data = preload("res://scripts/core/world_data.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	Registry.initialize()
	for width in [2, 3]:
		check_cursor(width)
		check_templates(width)
		check_bulk_craft(width)
	check_daylight()
	await check_world_and_ui()
	print("INTERACTION TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)

func check_daylight() -> void:
	var data := Data.new(20261030)
	var light := Daylight.new()
	light.configure(data)
	expect(light.exposure(Vector3(0.5, 2, 10.5)) == 1.0, "Open sky must retain outdoor ambient light")
	for x in range(0, 15):
		for y in [-3, -2]:
			data.set_block(Vector3i(x, y, 10), "air")
	for y in range(-3, 8):
		data.set_block(Vector3i(14, y, 10), "air")
	var entrance: float = light.exposure(Vector3(13.5, -1.5, 10.5))
	var middle: float = light.exposure(Vector3(8.5, -1.5, 10.5))
	var deep: float = light.exposure(Vector3(0.5, -1.5, 10.5))
	expect(entrance > middle and middle > deep and deep == 0, "Ambient daylight must fade progressively along a tunnel")
	data.set_block(Vector3i(14, -1, 10), "stone")
	expect(light.exposure(Vector3(13.5, -1.5, 10.5)) == 0, "Closing the skylight must remove daylight immediately after edit")
	data.set_block(Vector3i(14, -1, 10), "air")
	expect(light.exposure(Vector3(13.5, -1.5, 10.5)) > 0, "Reopening a skylight must restore daylight without reload")

func check_bulk_craft(width: int) -> void:
	var bag := Inventory.new()
	var table := Crafting.new(width)
	table.slots[0] = {"kind": "wood", "count": 64}
	expect(table.craft_all(bag) == 256 and bag.count_item("planks") == 256 and table.slots[0].count == 0, "Bulk craft must convert all logs in either grid")
	bag = Inventory.new()
	bag.add_items("dirt", 2240)
	bag.add_items("planks", 58)
	table.slots[0] = {"kind": "wood", "count": 10}
	expect(table.craft_all(bag) == 4 and table.slots[0].count == 9, "Bulk craft must preserve unused ingredients when only one complete batch fits")
	expect(table.craft_all(bag) == 0 and table.slots[0].count == 9, "Insufficient room must not consume ingredients")
	bag = Inventory.new()
	table = Crafting.new(width)
	for index in [0, 1, width, width + 1]:
		table.slots[index] = {"kind": "planks", "count": 3 if index % width == 0 else 2}
	expect(table.craft_all(bag) == 2 and bag.count_item("workbench") == 2 and bag.count_item("stick") == 0, "Bulk craft must not switch recipes when leftovers form sticks")
	bag = Inventory.new()
	table = Crafting.new(width)
	var cursor := Cursor.new()
	cursor.bind(bag, table)
	table.slots[0] = {"kind": "wood", "count": 3}
	expect(cursor.take_result() == 4 and cursor.held.kind == "planks" and cursor.held.count == 4 and bag.count_item("planks") == 0, "Crafting must create a cursor stack rather than automatically deposit")
	cursor.touch(30)
	cursor.finish()
	expect(bag.slots[30].count == 4 and cursor.held.count == 0 and table.slots[0].count == 2, "Dragging result must place it in selected inventory cell")
	expect(cursor.take_result(true) == 8 and table.slots[0].count == 0, "Shift result must create all remaining batches on cursor")
	cursor.finish()
	expect(cursor.store_held() and bag.count_item("planks") == 12, "Cancelling result drag must keep crafted output and automatically store it")
	bag = Inventory.new()
	bag.add_items("dirt", 2304)
	cursor.bind(bag, table)
	table.slots[0] = {"kind": "wood", "count": 1}
	cursor.take_result()
	expect(not cursor.store_held() and cursor.held.count == 4 and table.slots[0].count == 0, "Full inventory must preserve already crafted result on cursor")

func check_cursor(width: int) -> void:
	var bag := Inventory.new()
	bag.add_items("wood", 10)
	var table := Crafting.new(width)
	var cursor := Cursor.new()
	cursor.bind(bag, table)
	cursor.press(27, MOUSE_BUTTON_LEFT)
	cursor.finish()
	expect(bag.slots[27].count == 0 and cursor.held.count == 10, "Click must lift entire stack from its source")
	cursor.press(36, MOUSE_BUTTON_LEFT)
	for index in [37, 38, 39]:
		cursor.touch(index)
	var preview: Dictionary = cursor.preview()
	for index in range(4):
		expect(preview.slots[36 + index].count == (3 if index < 2 else 2), "Live preview must show fair counts before mouse release")
		expect(table.slots[index].count == 0, "Preview must not mutate committed crafting data")
	expect(cursor.held.count == 10 and preview.held.count == 0, "Preview must reserve items visually without duplicating ownership")
	cursor.finish()
	for index in range(4):
		expect(table.slots[index].count == (3 if index < 2 else 2), "Ten logs over four cells must distribute as 3+3+2+2")
	expect(cursor.held.count == 0, "Successful spread must empty cursor")
	expect(cursor.return_all() and bag.count_item("wood") == 10, "Closing must return every distributed item")
	cursor.press(27, MOUSE_BUTTON_LEFT, true)
	expect(bag.count_item("wood") == 0 and cursor.held.count == 0, "Shift-click must move whole stack to crafting")
	var total: int = 0
	var low: int = 100
	var high: int = 0
	for entry in table.slots:
		total += entry.count
		low = mini(low, entry.count)
		high = maxi(high, entry.count)
	expect(total == 10 and high - low <= 1, "Shift-move must distribute evenly in either grid size")
	cursor.return_all()
	cursor.press(27, MOUSE_BUTTON_RIGHT)
	expect(cursor.held.count == 5 and bag.slots[27].count == 5, "Right-click must lift half from inventory")
	cursor.press(36, MOUSE_BUTTON_LEFT)
	cursor.finish()
	expect(table.slots[0].count == 5 and cursor.held.count == 0, "Clicking another cell must deposit held half")
	cursor.press(36, MOUSE_BUTTON_RIGHT)
	expect(cursor.held.count == 3 and table.slots[0].count == 2, "Odd stack split must lift ceiling half without losing items")
	cursor.press(27, MOUSE_BUTTON_LEFT)
	cursor.finish()
	expect(bag.slots[27].count == 8 and cursor.held.count == 0, "Crafting half must merge back into inventory stack")
	cursor.return_all()
	cursor.press(27, MOUSE_BUTTON_LEFT)
	cursor.finish()
	bag.slots[28] = {"kind": "stone", "count": 2}
	cursor.press(28, MOUSE_BUTTON_LEFT)
	cursor.finish()
	expect(bag.slots[28].kind == "wood" and cursor.held.kind == "stone" and cursor.held.count == 2, "Click on different stack must swap instead of delete")
	cursor.return_all()
	expect(bag.count_item("wood") == 10 and bag.count_item("stone") == 2, "Swap and close must conserve both kinds")
	var full := Inventory.new()
	full.add_items("dirt", 2304)
	cursor.bind(full, Crafting.new(width))
	cursor.held = {"kind": "wood", "count": 1}
	expect(not cursor.return_all() and cursor.held.count == 1, "Full inventory must preserve held stack when close cannot complete")
	# Capacity-constrained distribution keeps excess on cursor.
	bag = Inventory.new()
	table = Crafting.new(width)
	cursor.bind(bag, table)
	cursor.reset()
	cursor.held = {"kind": "wood", "count": 10}
	table.slots[0] = {"kind": "wood", "count": 63}
	cursor.press(36, MOUSE_BUTTON_LEFT)
	cursor.touch(37)
	cursor.finish()
	expect(table.slots[0].count == 64 and table.slots[1].count == 9 and cursor.held.count == 0, "Distribution must respect stack capacity")

func check_templates(width: int) -> void:
	for recipe: Dictionary in Registry.catalog.recipes:
		var bag := Inventory.new()
		var table := Crafting.new(width)
		var cursor := Cursor.new()
		cursor.bind(bag, table)
		var needed := cursor.requirements(recipe)
		for kind: String in needed:
			bag.add_items(kind, needed[kind])
		if int(recipe.width) > width:
			expect(not cursor.can_fill(recipe), "Workbench recipes must be unavailable in personal 2x2")
			continue
		expect(cursor.can_fill(recipe) and cursor.fill_template(recipe), "Available recipe template must fill automatically")
		expect(table.recipe().kind == recipe.kind and table.recipe().count == recipe.count, "Filled template must match the same recipe in either grid")
		expect(table.craft(bag) and bag.count_item(recipe.kind) == recipe.count, "Template must produce exact output")
	var bag := Inventory.new()
	var table := Crafting.new(width)
	var cursor := Cursor.new()
	cursor.bind(bag, table)
	var log_recipe: Dictionary = Registry.catalog.recipes[0]
	expect(not cursor.can_fill(log_recipe) and not cursor.fill_template(log_recipe), "Missing materials must leave grid unchanged")
	bag.add_items("wood", 10)
	cursor.press(27, MOUSE_BUTTON_LEFT)
	cursor.finish()
	expect(cursor.fill_template(log_recipe) and cursor.held.count == 0 and bag.count_item("wood") == 9, "Templates must reuse a held stack and return surplus safely")

func send_mouse(point: Vector2, button: int, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func move_mouse(point: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = Vector2(20, 10)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func check_world_and_ui() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.testing = true
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	# Drops fall on data-defined surfaces and fall again when support is removed.
	var id: String = world.entity_system.spawn_drop("dirt", Vector3(6.5, 2.5, 6.5))
	world.model.entities[id].state.velocity_x = 0.0
	world.model.entities[id].state.velocity_z = 0.0
	world.entity_system.tick(Vector3(6.5, 0, 6.5), 1)
	for frame in range(120):
		world.entity_system.simulate_drops(1.0 / 60.0)
	expect(absf(world.model.entities[id].position.y - world.entity_system.drop_radius(world.model.entities[id])) < 0.001, "Drop must settle on solid terrain")
	for y in [-1, -2, -3]:
		world.model.set_block(Vector3i(6, y, 6), "air")
	for frame in range(120):
		world.entity_system.simulate_drops(1.0 / 60.0)
	expect(absf(world.model.entities[id].position.y - (-3.0 + world.entity_system.drop_radius(world.model.entities[id]))) < 0.001, "Drop must fall into newly excavated holes")
	var imported := Data.new()
	expect(imported.import_state(world.model.export_state()) and imported.entities[id].position == world.model.entities[id].position, "Drop position and velocity must survive save data")
	var outside_bag := Inventory.new()
	world.model.advance(1)
	world.entity_system.collect(world.model.entities[id].position + Vector3(1.6, 0, 0), outside_bag)
	expect(world.model.entities.has(id) and outside_bag.count_item("dirt") == 0, "Drops at 1.6 metres must remain on the ground")
	# Same sideways speed must travel farther from a higher source, including across cells.
	var drop_ids: Array[String] = []
	for source in [Vector3(12.5, 0.5, 12.5), Vector3(16.5, 8.5, 12.5)]:
		var drop_id: String = world.entity_system.spawn_drop("wood", source)
		world.model.entities[drop_id].state.velocity_x = 1.5
		world.model.entities[drop_id].state.velocity_z = 0.0
		drop_ids.append(drop_id)
	# Clear controlled columns above a flat floor so the terrain seed cannot affect this test.
	for x in range(11, 21):
		for z in range(11, 15):
			world.model.set_block(Vector3i(x, -1, z), "stone")
			for y in range(0, 10):
				world.model.set_block(Vector3i(x, y, z), "air")
	world.entity_system.tick(Vector3(15, 0, 12), 1)
	for frame in range(180):
		world.entity_system.simulate_drops(1.0 / 60.0)
	var short_travel: float = world.model.entities[drop_ids[0]].position.x - 12.5
	var long_travel: float = world.model.entities[drop_ids[1]].position.x - 16.5
	expect(long_travel > short_travel + 0.5 and long_travel > 1.0, "Higher drops must spread farther and reach neighbouring cells")
	for y in range(0, 10):
		world.model.set_block(Vector3i(19, y, 12), "stone")
	var wall_drop: String = world.entity_system.spawn_drop("wood", Vector3(18.5, 3.5, 12.5))
	world.model.entities[wall_drop].state.velocity_x = 3.0
	world.model.entities[wall_drop].state.velocity_z = 0.0
	world.entity_system.tick(Vector3(18, 0, 12), 1)
	for frame in range(120):
		world.entity_system.simulate_drops(1.0 / 60.0)
	expect(world.model.entities[wall_drop].position.x < 18.876 and not world.entity_system.drop_overlaps_block(world.model.entities[wall_drop].position), "Scattered drops must stop at walls without entering solid blocks")
	drop_ids.append(wall_drop)
	for drop_id in drop_ids:
		world.model.entities.erase(drop_id)
		world.entity_system.deactivate(drop_id)
	var full := Inventory.new()
	full.add_items("dirt", 2304)
	world.model.advance(1)
	world.entity_system.collect(world.model.entities[id].position, full)
	expect(world.model.entities.has(id), "Full inventory must leave world item in place")
	full.slots[27].count = 63
	world.entity_system.collect(world.model.entities[id].position, full)
	expect(not world.model.entities.has(id) and full.count_item("dirt") == 2304, "Nearby pickup must fill available capacity exactly once")
	# Both dialogs share real pointer and template controls.
	for width in [2, 3]:
		world.inventory = Inventory.new()
		world.inventory.add_items("wood", 10)
		world.crafting = Crafting.new(width)
		world.stack_cursor.reset()
		world.rebuild_crafting_slots()
		world.update_counter()
		world.toggle_inventory(width == 3)
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			var from: Vector2 = world.inventory_slots[27].get_global_rect().get_center()
			await move_mouse(from, false)
			await send_mouse(from, MOUSE_BUTTON_LEFT, true)
			await send_mouse(from, MOUSE_BUTTON_LEFT, false)
			expect(world.stack_cursor.held.count == 10 and world.cursor_visual.visible, "Native click must lift visible cursor stack")
			var first: Vector2 = world.crafting_slots[0].get_global_rect().get_center()
			await move_mouse(first, false)
			await send_mouse(first, MOUSE_BUTTON_LEFT, true)
			for index in [1, 2, 3]:
				await move_mouse(world.crafting_slots[index].get_global_rect().get_center(), true)
			for index in range(4):
				expect(world.crafting_slots[index].count_label.text == str(3 if index < 2 else 2) and world.crafting_slots[index].current_kind == "wood", "Native drag must show items and counts before release")
				expect(world.crafting.slots[index].count == 0, "Live GUI preview must not prematurely consume held stack")
			var mouse: Vector2 = world.get_viewport().get_mouse_position()
			expect(world.cursor_icon.get_global_rect().get_center().distance_to(mouse) < 1, "Held icon must be centred directly under pointer")
			if "--capture-ui" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://inventory-live-preview.png")
			await send_mouse(world.crafting_slots[3].get_global_rect().get_center(), MOUSE_BUTTON_LEFT, false)
			for index in range(4):
				expect(world.crafting.slots[index].count == (3 if index < 2 else 2), "Native mouse painting must distribute evenly")
		else:
			world.inventory_pointer_press(27, MOUSE_BUTTON_LEFT, false)
			world.stack_cursor.finish()
			world.inventory_pointer_press(36, MOUSE_BUTTON_LEFT, false)
			for index in [37, 38, 39]:
				world.stack_cursor.touch(index)
			world.stack_cursor.finish()
			world.refresh_slots()
		var products: Dictionary={}
		for recipe in Registry.catalog.recipes:
			products[recipe.kind]=true
		expect(world.template_buttons.size() == products.size(), "Recipe strip must include all registered products")
		for entry: Dictionary in world.template_buttons:
			expect(entry.button.disabled == not world.stack_cursor.can_fill(entry.recipe), "Missing materials or insufficient grid must dim recipe")
		if "--capture-ui" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://inventory-paint-%d-preview.png" % width)
		if DisplayServer.get_name() != "headless":
			var half_at: Vector2 = world.crafting_slots[0].get_global_rect().get_center()
			await send_mouse(half_at, MOUSE_BUTTON_RIGHT, true)
			await send_mouse(half_at, MOUSE_BUTTON_RIGHT, false)
			expect(world.stack_cursor.held.count == 2 and world.crafting.slots[0].count == 1, "Native right click must lift half from craft")
			var deposit_at: Vector2 = world.inventory_slots[27].get_global_rect().get_center()
			await send_mouse(deposit_at, MOUSE_BUTTON_LEFT, true)
			await send_mouse(deposit_at, MOUSE_BUTTON_LEFT, false)
			expect(world.inventory.slots[27].count == 2 and world.stack_cursor.held.count == 0, "Native left click must return split stack")
			var template_at: Vector2 = world.template_buttons[0].button.get_global_rect().get_center()
			await send_mouse(template_at, MOUSE_BUTTON_LEFT, true)
			await send_mouse(template_at, MOUSE_BUTTON_LEFT, false)
		else:
			world.template_buttons[0].button.pressed.emit()
		expect(world.crafting.recipe().kind == "planks" and world.inventory.count_item("wood") == 9, "Clicking recipe button must auto-fill one log and return surplus")
		world.craft_result()
		expect(world.stack_cursor.held.count == 4 and world.inventory.count_item("planks") == 0, "Clicking result must create an undeposited cursor stack")
		world.stack_cursor.finish()
		world.stack_cursor.store_held()
		if DisplayServer.get_name() != "headless":
			var shift_at: Vector2 = world.inventory_slots[27].get_global_rect().get_center()
			await send_mouse(shift_at, MOUSE_BUTTON_LEFT, true, true)
			await send_mouse(shift_at, MOUSE_BUTTON_LEFT, false, true)
			expect(world.inventory.count_item("wood") == 0 and world.stack_cursor.held.count == 0, "Native shift click must transfer inventory group")
			world.toggle_inventory()
			world.toggle_inventory(width == 3)
		# A held stack is part of a complete save snapshot and must return on close.
		world.inventory_pointer_press(27, MOUSE_BUTTON_RIGHT, false)
		var saved: Dictionary = world.snapshot()
		expect(saved.cursor.count > 0, "Session snapshot must include cursor-held materials")
		world.toggle_inventory()
		expect(world.stack_cursor.held.count == 0 and world.inventory.count_item("wood") == 9, "Closing dialog must restore cursor stack to inventory")
		for entry in world.crafting.slots:
			expect(entry.count == 0, "Closing must empty all 2x2 or 3x3 ingredient cells")
		expect(world.restore_snapshot(saved) and world.stack_cursor.held.count == saved.cursor.count and world.player.inventory_open, "Loading must restore lifted stack and reopen dialog")
		world.toggle_inventory()
		expect(world.inventory.count_item("wood") == 9 and world.stack_cursor.held.count == 0, "Restored lifted stack must return without duplication")
		world.toggle_inventory(width == 3)
		world.crafting.slots[0] = {"kind": "wood", "count": 3}
		world.update_counter()
		await process_frame
		var before_planks: int = world.inventory.count_item("planks")
		if DisplayServer.get_name() != "headless":
			var result_at: Vector2 = world.crafting_output.get_global_rect().get_center()
			await send_mouse(result_at, MOUSE_BUTTON_LEFT, true, true)
			await send_mouse(result_at, MOUSE_BUTTON_LEFT, false, true)
		else:
			world.craft_result(true)
		expect(world.crafting.slots[0].count == 0 and world.stack_cursor.held.count == 12 and world.inventory.count_item("planks") == before_planks, "Shift-clicking actual result must put all batches on cursor in both grid sizes")
		world.toggle_inventory()
		if DisplayServer.get_name() != "headless":
			world.toggle_inventory(width == 3)
			world.crafting.slots[0] = {"kind": "wood", "count": 2}
			world.update_counter()
			await process_frame
			var result_at: Vector2 = world.crafting_output.get_global_rect().get_center()
			var destination: int = 0
			world.inventory.slots[destination] = {"kind": "", "count": 0}
			await send_mouse(result_at, MOUSE_BUTTON_LEFT, true)
			expect(world.stack_cursor.held.count == 4, "Result must visibly follow mouse from initial press")
			var target_at: Vector2 = world.inventory_slots[destination].get_global_rect().get_center()
			await move_mouse(target_at, true)
			await send_mouse(target_at, MOUSE_BUTTON_LEFT, false)
			expect(world.inventory.slots[destination].kind == "planks" and world.inventory.slots[destination].count == 4, "Native result drag must deposit in the chosen slot")
			var before_cancel: int = world.inventory.count_item("planks")
			await send_mouse(result_at, MOUSE_BUTTON_LEFT, true)
			await move_mouse(Vector2(5, 5), true)
			await send_mouse(Vector2(5, 5), MOUSE_BUTTON_LEFT, false)
			expect(world.stack_cursor.held.count == 0 and world.inventory.count_item("planks") == before_cancel + 4 and world.crafting.slots[0].count == 0, "Aborted native drag must store created output without refunding ingredients")
			world.toggle_inventory()
	# Hand and equipped tool share the same reversible mining stroke.
	world.inventory.slots[34] = {"kind": "axe", "count": 1}
	for selected in [7, 6]:
		world.select_hotbar(selected)
		world.reset_held_pose()
		var rest_pose: Transform3D = world.held_item.transform
		var low: float = 100
		var high: float = -100
		for frame in range(60):
			world.update_hand_animation(1.0 / 60.0, true)
			low = minf(low, world.held_item.position.y)
			high = maxf(high, world.held_item.position.y)
		expect(high - low > 0.05, "Mining stroke must visibly move arm and item up and down")
		expect(world.held_item.rotation.distance_to(world.HELD_ROTATION) > 0.01, "Mining stroke must also tilt held arm")
		if selected == 7 and "--capture-ui" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://mining-arm-preview.png")
		for frame in range(120):
			world.update_hand_animation(1.0 / 60.0, false)
		expect(world.held_item.transform.is_equal_approx(rest_pose), "Releasing mining must return smoothly to rest")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
