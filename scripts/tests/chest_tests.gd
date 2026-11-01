extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Chests = preload("res://scripts/core/chests.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Craft = preload("res://scripts/crafting.gd")
const Bag = preload("res://scripts/inventory.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var table := Craft.new(3)
	for index in range(9):
		if index != 4:
			table.slots[index] = Registry.stack("wood", 1)
	expect(table.recipe().get("kind") == "chest", "Eight logs around empty center must craft chest")
	var model := Data.new(123)
	var a := Vector3i(2, 35, 2)
	model.set_block(a, "chest")
	expect(Chests.can_place(model, a + Vector3i.RIGHT), "Second chest allowed")
	model.set_block(a + Vector3i.RIGHT, "chest")
	expect(Chests.can_place(model, a + Vector3i.RIGHT * 2), "Third chest allowed beside double")
	model.set_block(a + Vector3i.RIGHT * 2, "chest")
	expect(Chests.cells(model, a).size() == 2 and Chests.cells(model, a + Vector3i.RIGHT * 2).size() == 1, "Third chest stays separate")
	model.set_block(a + Vector3i.RIGHT * 3, "chest")
	expect(Chests.cells(model, a + Vector3i.RIGHT * 2).size() == 2 and Chests.cells(model, a)[1] == a + Vector3i.RIGHT, "Adjacent pairs remain independent")
	expect(Chests.combined(model, a).size() == 54, "Double chest has 54 cells")
	Chests.contents(model, a)[18].merge({"kind":"stone", "count":12}, true)
	var loaded := Data.new(0)
	expect(loaded.import_state(model.export_state()) and Chests.contents(loaded, a)[18].count == 12, "Chest contents persist")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.model.set_block(a, "chest")
	world.inventory = Bag.new()
	world.inventory.slots[27] = Registry.stack("wood", 10)
	world.chest_ui.open(a)
	var ui = world.chest_ui
	ui.cursor.quick_move(27)
	expect(ui.storage.slots[18].count == 10 and world.inventory.slots[27].count == 0, "Shift moves into bottom chest row")
	ui.cursor.quick_move(54)
	expect(world.inventory.slots[27].count == 10, "Shift returns to hotbar first")
	ui.cursor.press(27, MOUSE_BUTTON_RIGHT)
	expect(ui.cursor.held.count == 5, "Right click halves stack")
	ui.cursor.press(36, MOUSE_BUTTON_LEFT)
	ui.cursor.finish()
	expect(ui.storage.slots[0].count == 5, "Cursor drag crosses to chest")
	ui.refresh()
	world.update_counter()
	expect(ui.cursor.crafting == ui.storage, "Refreshing world must retain storage binding")
	expect(ui.close(), "Chest closes with contents retained")
	expect(Chests.contents(world.model, a)[0].count == 5, "Closing must not empty chest")
	world.model.set_block(a + Vector3i.RIGHT, "chest")
	ui.open(a)
	ui.cursor.held = Registry.stack("axe", 1, {"durability":29, "max_durability":100})
	ui.cursor.press(89, MOUSE_BUTTON_LEFT)
	ui.cursor.finish()
	expect(ui.storage.slots[53].durability == 29, "Worn tools preserve durability in chest")
	ui.storage.slots[1].merge(Registry.stack("workbench", 1), true)
	ui.storage.slots[2].merge(Registry.stack("chest", 1), true)
	ui.refresh()
	await process_frame
	await process_frame
	expect(is_equal_approx(ui.widgets[0].global_position.x, ui.widgets[54].global_position.x) and is_equal_approx(ui.widgets[0].global_position.x, ui.widgets[81].global_position.x), "Storage, backpack and hotbar columns align")
	print("CHEST RECT ", ui.get_global_rect(), " VIEWPORT ", root.size)
	expect(ui.get_global_rect().position.y >= 0 and ui.get_global_rect().end.y <= root.get_visible_rect().size.y, "Double chest must fit screen")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://chest-preview.png")
	ui.close()
	world.model.set_block(a + Vector3i.RIGHT * 2, "chest")
	expect(Chests.cells(world.model, a + Vector3i.RIGHT * 2).size() == 1, "Placed third chest is single")
	world.streamer.build_now(world.model.key(a))
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position = Vector3(3.8, 35.4, 6.7)
		world.player.camera.look_at(Vector3(3.5, 35.4, 2.5))
		world.update_daylight(0.5)
		world.day_hud.refresh(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://chests-world-preview.png")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved), "Full save reload supports chest")
	expect(Chests.contents(world.model, a + Vector3i.RIGHT)[26].durability == 29, "Full save retains worn tool")
	var loot := Chests.remove(world.model, a + Vector3i.RIGHT)
	expect(loot.size() == 1 and loot[0].durability == 29, "Breaking chest releases contents intact")
	var legacy: Dictionary = world.snapshot()
	legacy.inventory = []
	for index in range(32):
		legacy.inventory.append(Registry.stack("dirt", index + 1))
	legacy.selected = 7
	expect(world.restore_snapshot(legacy), "Old eight-column save must load")
	for index in range(32):
		expect(world.inventory.slots[(index / 8) * 9 + index % 8].count == index + 1, "Old row positions must remain intact")
	for index in [8, 17, 26, 35]:
		expect(world.inventory.slots[index].count == 0, "Added ninth column starts empty on migration")
	world.inventory.slots[35] = Registry.stack("chest", 2)
	world.select_hotbar(8)
	expect(world.selected_kind() == "chest", "Ninth quickbar cell is selectable")
	var expanded: Dictionary = world.snapshot()
	expect(world.restore_snapshot(expanded) and world.inventory.slots.size() == 36 and world.selected_kind() == "chest", "New inventory and ninth selection survive save")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.toggle_inventory(true)
		await process_frame
		await process_frame
		expect(world.inventory_panel.get_global_rect().end.x <= root.get_visible_rect().size.x and world.inventory_panel.get_global_rect().end.y <= root.get_visible_rect().size.y, "Expanded crafting inventory fits screen")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://inventory-nine-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("CHEST TESTS: ", "PASS" if failures == 0 else str(failures) + " FAILURES")
	quit(0 if failures == 0 else 1)
