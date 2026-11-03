extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Generator = preload("res://scripts/core/generator.gd")
const Job = preload("res://scripts/rendering/chunk_job.gd")
const Save = preload("res://scripts/core/save_store.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Crafting = preload("res://scripts/crafting.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, text: String) -> void:
	if not condition:
		failures += 1
		push_error(text)

func run() -> void:
	Registry.initialize()
	check_catalog()
	check_generation_and_data()
	check_crafting()
	check_storage()
	await check_game()
	print("ARCHITECTURE TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)

func check_catalog() -> void:
	var original: Dictionary = Registry.catalog.duplicate(true)
	var expanded: Dictionary = original.duplicate(true)
	for index in range(50):
		var name: String = "test_block_%d" % index
		expanded.blocks[name] = {"id": 100 + index, "name": name, "color": "aabbcc"}
		expanded.items[name] = {"name": name, "block": name, "stack": 64}
	for index in range(100):
		expanded.items["test_item_%d" % index] = {"name": "Test", "stack": 16}
	expect(Registry.install(expanded), "Registry must accommodate 50 additional block types and 100 items")
	expect(Registry.id("test_block_49") == 149 and Registry.cube(149), "Stable IDs must not depend on array order")
	var bag := Inventory.new()
	expect(bag.add_items("test_item_99", 17) and bag.slots[27].count == 16 and bag.slots[28].count == 1, "Item registry must control stack limits")
	var wrong: Dictionary = expanded.duplicate(true)
	wrong.blocks.test_block_49.id = 1
	expect(not Registry.install(wrong), "Duplicate IDs must be rejected without replacing working registry")
	expect(Registry.install(original), "Original registry must restore")
	for pair in [["hand", "stone", 3.0], ["pickaxe", "stone", 0.7], ["axe", "wood", 0.7], ["shovel", "dirt", 0.7]]:
		expect(is_equal_approx(Registry.seconds(pair[0], pair[1]), pair[2]), "Harvest rules must come from registry")
	expect(not Registry.drops("hand", "stone") and not Registry.drops("axe", "foliage"), "Existing material drop rules must remain")

func check_generation_and_data() -> void:
	var first := Generator.new(123456)
	var second := Generator.new(123456)
	var here := Vector3i(0, -1, 0)
	first.generate(Vector3i(-9, 0, 11))
	var a: PackedByteArray = first.generate(here)
	expect(a == second.generate(here) and a.size() == 8192, "Seed and coordinates must deterministically generate compact 16-cube chunks")
	expect(Data.key(Vector3i(-1, -1, -17)) == Vector3i(-1, -1, -2) and Data.index(Vector3i(-1, -1, -1)) == 4095, "Negative coordinates must floor correctly")
	var changed_seed := Generator.new(98765)
	var seed_differs: bool=false
	for x in range(-200,201,40):
		for z in range(-200,201,40):
			seed_differs=seed_differs or first.height(x,z)!=changed_seed.height(x,z)
	expect(seed_differs, "Different seeds must change the landscape")
	var data := Data.new(123456)
	var cell := Vector3i(15, -1, 8)
	data.set_block(cell, "air")
	expect(data.kind_at(cell) == "air", "Deleted blocks must be explicit air overrides")
	expect(int(data.revisions.get(Vector3i(1, -1, 0), 0)) > 0, "Boundary edits must invalidate adjacent chunk meshes")
	data.cache.clear()
	expect(data.kind_at(cell) == "air", "Chunk eviction must preserve edits")
	data.set_block(Vector3i(16, 1, 8), "workbench")
	expect(data.kind_at(Vector3i(16, 1, 8)) == "workbench", "Placed blocks must share the terrain model")
	expect(not data.set_block(Vector3i(0, -65, 0), "air"), "Absolute bedrock must be immutable")
	var state := data.export_state()
	var restored := Data.new()
	expect(restored.import_state(state) and restored.kind_at(cell) == "air" and restored.kind_at(Vector3i(16, 1, 8)) == "workbench", "Model snapshot must preserve deletions and placements")
	var wrong: Dictionary = state.duplicate(true)
	wrong.generator_version = 999
	expect(not restored.import_state(wrong) and restored.kind_at(cell) == "air", "Unsupported generators must fail without replacing current model")
	# All solid cubes in an interior section have no drawable faces.
	var job := Job.new(data.seed_value, Vector3i(0, -4, 0), {})
	job.run()
	expect(job.result.vertices == 0, "Fully buried chunks must emit no geometry")
	var flat := Job.new(data.seed_value, Vector3i(0, -1, 0), {})
	flat.run()
	expect(flat.result.vertices < 16 * 16 * 6 * 4, "Greedy meshing must merge adjacent exposed faces")
	# Decay deadlines survive unloading, save and restore.
	var tree: Dictionary = {}
	for x in range(-30, 30):
		for z in range(-30, 30):
			tree = data.generator.tree_info(x, z)
			if not tree.is_empty():
				break
		if not tree.is_empty():
			break
	data.set_block(tree.base, "air")
	var expected_leaves: int=0
	for offset in tree.voxels:
		if int(tree.voxels[offset])==4 and data.kind_at(tree.base+offset)=="foliage":
			expected_leaves+=1
	expect(data.decay.size() == expected_leaves and expected_leaves>0, "Cutting a generated tree must schedule its complete crown decay")
	for record: Dictionary in data.decay.values():
		expect(record.deadline >= 30 and record.deadline <= 90, "Decay must use saved 30-90s deadlines")
	var leaf: Vector3i = data.decay.keys()[0]
	var decay_save := data.export_state()
	var after := Data.new()
	expect(after.import_state(decay_save), "Decay snapshot must load")
	after.advance(91)
	expect(after.kind_at(leaf) == "air", "Overdue decay must run even if its area was not rendered")

func check_crafting() -> void:
	var bag := Inventory.new()
	var crafting := Crafting.new()
	bag.add_items("wood", 2)
	crafting.transfer(bag, 27, 36)
	expect(crafting.craft(bag) and bag.count_item("planks") == 4, "Log conversion must remain usable")
	crafting.transfer(bag, 28, 36)
	crafting.transfer(bag, 28, 38)
	expect(crafting.craft(bag) and bag.count_item("stick") == 4, "Stick recipe must remain usable")
	crafting.transfer(bag, 27, 39)
	expect(crafting.return_ingredients(bag) and bag.count_item("wood") == 1, "Closing crafting must return ingredients")
	var bench := Crafting.new(3)
	for row in range(3):
		for col in range(3):
			bench.slots[row * 3 + col] = {"kind": "stone" if row == 0 else ("stick" if col == 1 else ""), "count": 1 if row == 0 or col == 1 else 0}
	expect(bench.craft(bag) and bag.count_item("pickaxe") == 1, "Data-defined workbench recipe must craft pickaxe")
	bag = Inventory.new()
	bag.add_items("dirt", 512)
	bag.add_item("wood")
	expect(bag.slots[35].kind == "wood", "Inventory must still fill bottom-up")

func fixture() -> Dictionary:
	var data := Data.new(41829)
	data.world_id = "architecture_test_world"
	data.set_block(Vector3i(0, -1, 0), "air")
	data.set_block(Vector3i(1, 1, 0), "workbench")
	data.entities["future_monster"] = {"type": "monster", "position": Vector3(2, 0, 2), "state": {"health": 17, "goal": "wander"}}
	data.entities["torch_1"] = {"type": "torch", "cell": Vector3i(3, 0, 0), "kind": "torch", "position": Vector3(3.5, 0.3, 0.5), "state": {}}
	var inventory := Inventory.new()
	inventory.add_items("wood", 7)
	return {"world": data.export_state(), "player": {"position": Vector3(0, 0.05, 12), "rotation": Vector3.ZERO, "camera": Vector3.ZERO, "velocity": Vector3.ZERO}, "inventory": inventory.slots.duplicate(true), "crafting": {"width": 2, "slots": Crafting.new().slots.duplicate(true), "open": false}, "selected": 0}

func check_storage() -> void:
	var root: String = "user://architecture_tests"
	var saved := fixture()
	expect(Save.save(saved, root) == OK, "Compressed checkpoint must save")
	var loaded: Dictionary = Save.load_world(saved.world.world_id, root)
	expect(not loaded.is_empty() and loaded.inventory[27].count == 7, "Checkpoint must preserve inventory")
	expect(loaded.world.entities.future_monster.state.health == 17, "Future actor state must survive save without requiring a scene")
	saved.inventory[27].count = 6
	expect(Save.save(saved, root) == OK, "Second save must create recoverable backup")
	var corrupt := FileAccess.open_compressed(root.path_join(saved.world.world_id).path_join("world.save"), FileAccess.WRITE)
	corrupt.store_var({"format_version": 999})
	corrupt.close()
	loaded = Save.load_world(saved.world.world_id, root)
	expect(loaded.inventory[27].count == 7, "Corrupt primary must fall back to last complete backup")
	expect(Save.load_world("../outside", root).is_empty(), "Save slot paths must remain within save directory")

func check_game() -> void:
	var started: int = Time.get_ticks_msec()
	var world = load("res://scenes/main.tscn").instantiate()
	world.testing = true
	root.add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	expect(world.streamer.chunks.size() == 27, "Startup must load only nearby chunks, not the whole map")
	print("Startup milliseconds: ", Time.get_ticks_msec() - started)
	await physics_frame
	await physics_frame
	# Mine a chunk border and re-mesh only affected loaded sections.
	world.player.position = Vector3(0.5, 0.05, 12)
	world.player.camera.look_at(Vector3(0.5, -1, 9.5))
	world.update_build_preview()
	expect(world.target_cell.y != -1000, "Existing ground must be selectable")
	var cell: Vector3i = world.target_cell
	var initial_dirt: int=world.inventory.count_item("dirt")
	world.mining_held = true
	world.update_mining(4.51)
	expect(world.model.kind_at(cell) == "air" and world.inventory.count_item("dirt") == initial_dirt, "Mining must create a world drop instead of directly changing inventory")
	var drop_id: String = ""
	for id: String in world.model.entities:
		if id.begins_with("drop_"):
			drop_id = id
	expect(not drop_id.is_empty(), "Mined block must exist as persistent pickup")
	world.entity_system.tick(world.player.position, 1)
	for frame in range(45):
		world.entity_system.simulate_drops(1.0 / 60.0)
	world.model.advance(0.6)
	world.entity_system.collect(world.model.entities[drop_id].position, world.inventory)
	expect(world.inventory.count_item("dirt") == initial_dirt+1 and not world.model.entities.has(drop_id), "Nearby pickup must transfer exactly once into inventory")
	# All constructed blocks, trees and ground use batched chunk geometry.
	world.model.set_block(Vector3i(2, 0, 10), "workbench")
	world.streamer.build_now(Vector3i.ZERO)
	await physics_frame
	await physics_frame
	world.player.position = Vector3(2.5, 0.05, 13)
	world.player.camera.look_at(Vector3(2.5, 0.5, 10.5))
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	world._unhandled_input(right)
	expect(world.player.inventory_open and world.crafting.width == 3, "Batched workbench must still open 3x3 crafting")
	world.toggle_inventory()
	# Torch records and block occupancy must survive restoring an entire session.
	world.model.set_block(Vector3i(4, 0, 10), "torch")
	world.model.entities["torch_4"] = {"type": "torch", "kind": "torch", "cell": Vector3i(4, 0, 10), "position": Vector3(4.5, 0.3, 10.5), "state": {}}
	world.entity_system.tick(world.player.position, 1)
	expect(world.entity_system.active.has("torch_4"), "Nearby torch record must activate a light object")
	var state: Dictionary = world.snapshot()
	var inventory_before: int = world.inventory.count_item("dirt")
	world.inventory.take_item("dirt")
	expect(world.restore_snapshot(state) and world.inventory.count_item("dirt") == inventory_before, "Loading must restore player and inventory")
	expect(world.model.kind_at(cell) == "air" and world.model.kind_at(Vector3i(2, 0, 10)) == "workbench", "Loading must not regenerate removed blocks or lose placed ones")
	expect(world.model.entities.has("torch_4"), "Loading must restore torch state")
	# Stream out, return, and rebuild a modified area without resurrecting blocks.
	var before_nodes: int = world.get_tree().get_node_count()
	world.streamer.view_distance = 48
	world.streamer.refresh_desired(Vector3(120, 0, 120))
	for frame in range(12):
		world.streamer.tick(Vector3(120,0,120),0.016)
	expect(world.streamer.chunks.size() < 27, "Distant movement unloads old render objects across budgeted frames")
	world.streamer.warm_start(Vector3(0, 0.05, 12))
	expect(world.model.kind_at(cell) == "air", "Returning to an area must retain edits")
	for record: Dictionary in world.streamer.chunks.values():
		expect(record.mesh.get_surface_count() <= 1, "All block types must share a single atlas surface per chunk")
	expect(world.model.cache.size() <= Data.CACHE_LIMIT, "Decoded chunk cache must remain bounded")
	expect(world.get_tree().get_node_count() < before_nodes + 200, "World must not instantiate one node per block")
	await check_voxel_movement(world)
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.streamer.view_distance = 96
		world.streamer.refresh_desired(world.player.position)
		world.player.position = Vector3(0, 8, 18)
		world.player.camera.look_at(Vector3(0, 1, -30))
		world.player.paused = true
		world.pause_panel.visible = false
		var deadline: int = Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < deadline:
			await process_frame
		world.player.set_physics_process(false)
		world.player.paused = false
		world.pause_panel.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scaled-world-preview.png")
		world.player.paused = true
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://save-menu-preview.png")
	print("Loaded chunk meshes: ", world.streamer.chunks.size(), "; scene nodes: ", world.get_tree().get_node_count(), "; cached chunks: ", world.model.cache.size())
	world.streamer.shutdown()
	world.queue_free()
	await process_frame

func check_voxel_movement(world: Node) -> void:
	world.set_process(false)
	world.player.movement_blocked = false
	world.player.paused = false
	world.player.inventory_open = false
	var cell := Vector3i(0, 0, 4)
	var jump := InputEventKey.new()
	jump.keycode = KEY_SPACE
	jump.physical_keycode = KEY_SPACE
	jump.pressed = true
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	for kind in ["stone", "wood", "workbench"]:
		world.model.set_block(cell, kind)
		world.streamer.build_now(Vector3i.ZERO)
		world.player.position = Vector3(0.5, 0.05, 6.2)
		world.player.velocity = Vector3.ZERO
		world.player.rotation = Vector3.ZERO
		world.player.jump_buffer_remaining = 0
		world.player.coyote_remaining = 0
		await physics_frame
		await physics_frame
		for frame in range(8):
			world.player._physics_process(1.0 / 60.0)
			await physics_frame
		expect(world.player.is_on_floor(), "Voxel jump must start grounded")
		forward.pressed = true
		Input.parse_input_event(forward)
		Input.flush_buffered_events()
		world.player._unhandled_input(jump)
		for frame in range(34):
			world.player._physics_process(1.0 / 60.0)
			await physics_frame
		forward.pressed = false
		Input.parse_input_event(forward)
		Input.flush_buffered_events()
		for frame in range(65):
			world.player._physics_process(1.0 / 60.0)
			await physics_frame
		expect(world.player.is_on_floor() and absf(world.player.position.y - 1) < 0.03, "Jump must land on batched " + kind)
		world.model.set_block(cell, "air")
	world.streamer.build_now(Vector3i.ZERO)
	world.player.position = Vector3(0, 0.05, 12)
	world.player.velocity = Vector3.ZERO
	world.set_process(true)
