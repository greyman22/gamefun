extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Crafting = preload("res://scripts/crafting.gd")
const Cursor = preload("res://scripts/core/stack_cursor.gd")
const Berries = preload("res://scripts/core/berries.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func mouse_right(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	Registry.initialize()
	var data := Data.new(42)
	var centres: Array[Vector2i] = []
	for x in range(-2, 3):
		for z in range(-2, 3):
			centres.append(Berries.centre(data, x, z))
	for a in centres:
		for b in centres:
			if a != b:
				expect(Vector2(maxi(0, absi(a.x - b.x) - 5), maxi(0, absi(a.y - b.y) - 5)).length() >= 30, "Bush group edges must remain at least thirty metres apart")
	var centre: Vector2i = centres[12]
	Berries.ensure_nearby(data, Vector3(centre.x, 0, centre.y))
	var count: int = data.entities.size()
	for group: Dictionary in data.landmarks.berry_groups.values():
		expect(group.count == 0 or (group.count >= 5 and group.count <= 10), "Each natural group must contain five to ten bushes with gaps")
	Berries.ensure_nearby(data, Vector3(centre.x, 0, centre.y))
	expect(data.entities.size() == count, "Revisiting group must not duplicate bushes")
	var cell := Vector3i(3, 0, 10)
	var id: String = Berries.plant(data, cell)
	expect(not id.is_empty() and Berries.plant(data, cell).is_empty(), "Plant must require an empty soil cell and reject duplicate planting")
	data.advance(29)
	expect(Berries.stage(data.entities[id], data.game_time) == 0 and not Berries.ripe(data.entities[id], data.game_time), "New seedling must stay in first stage for thirty seconds")
	data.advance(1)
	expect(Berries.stage(data.entities[id], data.game_time) == 1, "Second illustration must begin after thirty seconds")
	data.advance(30)
	expect(Berries.stage(data.entities[id], data.game_time) == 2, "Third illustration must begin after sixty seconds")
	var loaded := Data.new()
	expect(loaded.import_state(data.export_state()), "Growth timers must save")
	loaded.advance(59)
	expect(not Berries.ripe(loaded.entities[id], loaded.game_time), "Planted bush must not be harvestable before two minutes")
	loaded.advance(1)
	expect(Berries.stage(loaded.entities[id], loaded.game_time) == 3 and Berries.ripe(loaded.entities[id], loaded.game_time), "Fourth bush form must finish growth after two minutes")
	var yield_count: int = Berries.harvest(loaded, id)
	expect(yield_count >= 1 and yield_count <= 4 and not loaded.entities.has(id) and Berries.harvest(loaded, id) == 0, "Harvest must yield one to four berries and remove ripe fruit")
	Registry.catalog.items.axe.max_uses = 37
	expect(Registry.stack("axe").durability == 37 and Registry.stack("pickaxe").durability == 100, "Each tool must have an independently configurable lifetime")
	Registry.catalog.items.axe.max_uses = 100
	var bag := Inventory.new()
	bag.add_stack(Registry.stack("axe", 1, {"durability": 29, "max_durability": 100}))
	var table := Crafting.new()
	var cursor := Cursor.new()
	cursor.bind(bag, table)
	cursor.press(24, MOUSE_BUTTON_LEFT)
	cursor.finish()
	cursor.press(32, MOUSE_BUTTON_LEFT)
	cursor.finish()
	expect(table.slots[0].durability == 29 and cursor.return_all() and bag.slots[24].durability == 29, "Worn tools must retain durability through dragging, crafting grid and close")
	cursor.press(24, MOUSE_BUTTON_RIGHT)
	bag.add_items("wood", 1)
	expect(cursor.fill_template(Registry.catalog.recipes[0]) and bag.count_item("axe") == 1, "Templates must return a held tool rather than consume or lose it")
	var tool_index: int = -1
	for index in range(32):
		if bag.slots[index].kind == "axe":
			tool_index = index
	expect(tool_index >= 0 and bag.slots[tool_index].durability == 29, "Template filling must not repair worn tools")
	for use in range(28):
		expect(not bag.wear(tool_index), "Tool must survive until its last remaining use")
	expect(bag.slots[tool_index].durability == 1 and bag.wear(tool_index) and bag.count_item("axe") == 0, "Tool must break exactly when its durability reaches zero")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.inventory.slots[24] = {"kind": "blueberry", "count": 4}
	world.select_hotbar(0)
	world.player.vitals.satiety = 90
	mouse_right(true)
	world.update_eating(1.99)
	expect(world.inventory.slots[24].count == 4 and world.player.vitals.satiety == 90, "Eating must wait a full two seconds per berry")
	world.update_eating(0.01)
	expect(world.inventory.slots[24].count == 3 and world.player.vitals.satiety == 95, "One berry must restore five percent satiety")
	world.update_eating(2)
	world.update_eating(10)
	expect(world.inventory.slots[24].count == 2 and world.player.vitals.satiety == 100, "Holding eat at full satiety must not consume more berries")
	mouse_right(false)
	world.player.position = Vector3(3.5, 0.05, 12.5)
	world.player.camera.look_at(Vector3(3.5, 0, 10.5))
	await physics_frame
	world.update_build_preview()
	expect(world.try_plant_berry() and world.inventory.slots[24].count == 1, "Aiming at soil must plant one bush and consume one berry")
	var bush_id: String = Berries.at_cell(world.model, cell)
	expect(not bush_id.is_empty(), "Planted bush must occupy the aimed cell")
	world.model.advance(120)
	world.entity_system.tick(world.player.position, 1)
	await physics_frame
	await physics_frame
	world.update_build_preview()
	expect(world.target_bush == bush_id and world.bush_focus.visible and not world.preview.visible, "Bush focus must enclose the bush instead of the soil behind it")
	world.player.camera.look_at(world.model.entities[bush_id].position + Vector3(0.44, 0.5, 0))
	world.update_build_preview()
	expect(world.target_bush == bush_id and world.bush_focus.visible, "Aiming at the outer berries must still select the bush rather than its soil")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://berry-focus-preview.png")
	world.inventory.slots[24] = Registry.stack("axe", 1)
	world.select_hotbar(0)
	world.player.position = world.model.entities[bush_id].position + Vector3(0, 0.05, 0.9)
	world.target_bush = bush_id
	world.mining_held = true
	world.update_harvest(2.99)
	expect(Berries.ripe(world.model.entities[bush_id], world.model.game_time), "Harvest must wait three seconds")
	world.update_harvest(0.01)
	expect(not world.model.entities.has(bush_id) and not world.entity_system.active.has(bush_id) and Registry.remaining_uses(world.inventory.slots[24]) == 100, "Harvest must give berries without wearing the held tool")
	var dropped_berries: int = 0
	for entity: Dictionary in world.model.entities.values():
		if entity.type == "pickup" and entity.kind == "blueberry":
			dropped_berries += int(entity.get("count", 1))
	expect(dropped_berries >= 1 and dropped_berries <= 4, "Harvest must leave one to four physical berry pickups")
	world.entity_system.tick(world.player.position, 1)
	world.model.advance(1)
	var berry_bag := Inventory.new()
	var harvest_position: Vector3 = world.player.position
	world.entity_system.collect(harvest_position, berry_bag)
	expect(berry_bag.count_item("blueberry") == 0, "Airborne berries must not collect even after their old pickup delay")
	for frame in range(60):
		world.entity_system.simulate_drops(1.0 / 60.0)
	world.model.advance(0.3)
	world.entity_system.collect(harvest_position, berry_bag)
	expect(berry_bag.count_item("blueberry") == 0, "Landed berries must remain until the player actually approaches")
	for entity_id: String in world.entity_system.active.keys():
		if world.model.entities.has(entity_id) and world.model.entities[entity_id].type == "pickup" and world.model.entities[entity_id].kind == "blueberry":
			world.entity_system.collect(world.model.entities[entity_id].position, berry_bag)
	expect(berry_bag.count_item("blueberry") > 0, "Approaching landed berries must pick them up")
	world.target_bush = ""
	world.target_cell = cell + Vector3i.DOWN
	world.update_mining(10)
	expect(world.model.kind_at(cell + Vector3i.DOWN) == "dirt" and Registry.remaining_uses(world.inventory.slots[24]) == 100, "Completing a harvest must never continue mining the soil on the same held click")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	world._unhandled_input(release)
	release.pressed = true
	world._unhandled_input(release)
	world.target_cell = Vector3i(8, 0, 10)
	world.model.set_block(world.target_cell, "wood")
	world.update_mining(1.5)
	expect(Registry.remaining_uses(world.inventory.slots[24]) == 99, "Finishing a wood block must use exactly one axe durability")
	world.player.vitals.reset()
	var thorn_id: String = Berries.plant(world.model, Vector3i(4, 0, 10))
	world.entity_system.tick(Vector3(4.5, 0, 11), 1)
	world.player.position = world.model.entities[thorn_id].position + Vector3(0.5, 0, 0)
	world.check_bush_contact(1)
	expect(world.player.vitals.health == 95 and absf(world.player.knockback.remaining.length() - 0.5) < 0.001, "Touching a bush must cause five percent damage and half-metre recoil")
	world.check_bush_contact(0.1)
	expect(world.player.vitals.health == 95, "Thorns must not damage on every physics frame")
	for index in range(4):
		var kind: String = ["stone_sword", "axe", "shovel", "pickaxe"][index]
		world.inventory.slots[24 + index] = Registry.stack(kind, 1, {"durability": [9, 29, 99, 100][index], "max_durability": 100})
	world.update_counter()
	expect(world.hotbar_slots[0].durability_bar.visible and world.hotbar_slots[0].durability_bar.get_theme_stylebox("fill").bg_color.r > 0.9, "Below ten percent durability must show a red bar")
	expect(world.hotbar_slots[1].durability_bar.get_theme_stylebox("fill").bg_color.g > 0.7 and not world.hotbar_slots[3].durability_bar.visible, "Below thirty percent must be yellow and fresh tools must hide their bar")
	var state: Dictionary = world.snapshot()
	expect(world.restore_snapshot(state) and world.inventory.slots[24].durability == 9, "Tool durability and planted bushes must survive full save/load")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position = Vector3(0, 1.7, 12)
		for index in range(4):
			var bush_cell := Vector3i(-3 + index * 2, 0, 7)
			var plant_id: String = Berries.plant(world.model, bush_cell)
			if not plant_id.is_empty():
				world.model.entities[plant_id].planted_at = world.model.game_time - [0, 30, 60, 120][index]
				world.model.entities[plant_id].ripe_at = world.model.entities[plant_id].planted_at + 120
		world.entity_system.tick(world.player.position, 1)
		world.player.camera.look_at(Vector3(0, 0.4, 7))
		world.player.knockback.stop()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://berry-growth-preview.png")
		world.toggle_inventory()
		await process_frame
		await RenderingServer.frame_post_draw
		expect(world.inventory_slots[24].durability_bar.get_global_rect().size.y <= 6, "Wear bar must remain a thin strip below the tool icon")
		root.get_texture().get_image().save_png("res://tool-durability-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("BERRIES AND DURABILITY TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
