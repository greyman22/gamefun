extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const House = preload("res://scripts/core/zombie_house.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	Registry.initialize()
	for seed_value in [1, 42, 20261030, -787, 142531]:
		for debug in [false, true]:
			var data := Data.new(seed_value)
			var record := House.new().place(data, debug)
			expect(data.entities.size() == 5, "House must seed exactly five zombie records")
			House.new().ensure_zombies(data)
			expect(data.entities.size() == 5, "Revisiting a saved house must not duplicate zombies")
			var base: Vector3i = record.base
			var distance: float = Vector2(base.x, base.z - 12).length()
			expect((absf(distance - 40) < 1) if debug else (distance >= 199 and distance <= 401), "House must be at requested distance from spawn")
			expect(base.y >= 0, "House avoids deep basins without an artificial high platform")
			expect(data.kind_at(base + Vector3i(-5, 2, -4)) == "wood", "House must have a log frame")
			expect(data.kind_at(base + Vector3i(2, 6, -2)) == "stone", "House must have a stone chimney")
			expect(data.kind_at(base + Vector3i(0, 1, 4)) == "air", "House entrance must be open")
			var supported: bool = true
			for x in range(-5, 6):
				for z in range(-4, 5):
					supported = supported and Registry.cube(data.block(base + Vector3i(x, -1, z)))
			expect(supported, "House floor must have a solid foundation on uneven terrain")
			var saved: Dictionary = data.export_state()
			var restored := Data.new()
			expect(restored.import_state(saved) and restored.landmarks.zombie_house == record, "House landmark must persist")
			data.set_block(base + Vector3i(-5, 2, -4), "air")
			expect(restored.import_state(data.export_state()) and restored.kind_at(base + Vector3i(-5, 2, -4)) == "air", "Saved house damage must remain after loading")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	expect(world.game_mode == "play" and world.inventory.count_item("dirt") == 32 and world.inventory.count_item("pickaxe") == 0, "Play mode must retain normal starter inventory")
	world.new_world(42, "debug")
	for kind: String in Registry.catalog.items:
		expect(world.inventory.count_item(kind) == 0 if kind == "bedrock" else world.inventory.count_item(kind) > 0, "Debug inventory filters bedrock and supplies " + kind)
	expect(world.inventory.slots.slice(27).map(func(slot: Dictionary) -> String: return slot.kind) == ["stone_sword", "pickaxe", "axe", "shovel", "", "dirt", "wood", "", "torch"], "Debug quickbar must use requested order and leave slot five empty")
	world.update_house_marker()
	expect(world.house_marker.visible, "Debug house marker must be visible outside terrain view distance")
	var state: Dictionary = world.snapshot()
	var base: Vector3i = world.model.landmarks.zombie_house.base
	expect(world.restore_snapshot(state) and world.game_mode == "debug" and world.model.landmarks.zombie_house.base == base, "Session save must restore mode and house")
	world.player.paused = false
	world.update_house_marker()
	expect(world.house_marker.visible, "Restored debug world must retain marker")
	world.game_mode = "play"
	world.update_house_marker()
	expect(not world.house_marker.visible, "Play mode must hide debug marker")
	# Distant zombies remain data-only. Nearby actors walk against voxel data.
	world.entity_system.tick(Vector3(0, 0, 12), 1)
	world.entity_system.tick(Vector3(base), 1)
	var origins: Dictionary = {}
	for id: String in world.entity_system.active:
		if world.model.entities[id].type == "zombie":
			origins[id] = world.entity_system.active[id].position
	expect(origins.size() == 5, "All five zombies must activate near the house")
	var stayed_inside: bool = true
	var clear_bodies: bool = true
	for frame in range(1200):
		world.entity_system.simulate_actors(1.0 / 30.0)
		for id: String in origins:
			var actor = world.entity_system.active[id]
			stayed_inside = stayed_inside and Vector2(actor.position.x - actor.home.x, actor.position.z - actor.home.z).length() <= 15.001
			clear_bodies = clear_bodies and actor.clear_at(actor.position)
	var moved: int = 0
	for id: String in origins:
		if world.entity_system.active[id].position.distance_to(origins[id]) > 0.25:
			moved += 1
	expect(stayed_inside, "Wandering zombies must remain within 15 metres of home")
	expect(clear_bodies, "Zombie movement must not pass through terrain or the house")
	expect(moved >= 3, "Zombies must actually wander rather than remain at spawn")
	var actor_save: Dictionary = world.snapshot()
	var actor_id: String = origins.keys()[0]
	var saved_position: Vector3 = world.model.entities[actor_id].position
	world.entity_system.tick(Vector3(900, 0, 900), 1)
	for id: String in origins:
		expect(not world.entity_system.active.has(id), "Distant zombies must unload their scene nodes")
	expect(world.restore_snapshot(actor_save) and world.model.entities[actor_id].position == saved_position, "Zombie positions and movement state must survive save/load")
	world.entity_system.tick(Vector3(base), 1)
	for id: String in origins:
		expect(world.entity_system.active.has(id), "Returning to house must reactivate existing zombies")
	# A fresh launch presents both modes and can continue the existing session.
	world.build_start_menu(true)
	world.start_new_session("debug", "42")
	expect(not world.start_panel.visible and world.game_mode == "debug" and not world.player.paused, "Starting debug mode must close start menu and enable play")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.start_panel.show()
		world.player.paused = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://start-modes-preview.png")
		world.start_panel.hide()
		world.refresh_world_list()
		world.pause_panel.show()
		await process_frame
		await RenderingServer.frame_post_draw
		expect(world.pause_panel.get_global_rect().end.y <= root.size.y, "Mode selection menu must fit within the window")
		root.get_texture().get_image().save_png("res://mode-menu-preview.png")
		world.pause_panel.hide()
		world.player.paused = false
		world.player.position = Vector3(base) + Vector3(17, 8, 21)
		world.player.camera.look_at(Vector3(base) + Vector3(0, 4, 0))
		world.streamer.warm_start(world.player.position)
		world.entity_system.tick(world.player.position, 1)
		world.update_house_marker()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://zombie-house-preview.png")
		world.player.position = Vector3(0, 0.05, 12)
		world.player.camera.look_at(Vector3(base) + Vector3(0, 3, 0))
		world.streamer.warm_start(world.player.position)
		world.entity_system.tick(world.player.position, 1)
		world.update_house_marker()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://house-marker-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("MODE AND HOUSE TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
