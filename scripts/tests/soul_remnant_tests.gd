extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)

func remnants(world: Node) -> Array[String]:
	var result: Array[String] = []
	for id: String in world.model.entities:
		var record: Dictionary = world.model.entities[id]
		if record.type == "pickup" and record.kind == "soul_remnant":
			result.append(id)
	return result

func run() -> void:
	Registry.initialize()
	expect(Registry.stack_limit("soul_remnant") == 64 and not Registry.tool("soul_remnant"), "Soul remnants must be stackable material, not tools")
	var bag := Inventory.new()
	expect(bag.add_items("soul_remnant", 65) and bag.slots[24].count == 64 and bag.slots[25].count == 1, "Sixty-five remnants must split as sixty-four plus one")
	var picture: Image = Visuals.icon("soul_remnant").get_image()
	expect(picture.get_pixel(0, 0).a == 0 and picture.get_pixel(48, 48).b > picture.get_pixel(48, 48).g, "Soul icon must be purple with transparent background")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var id: String = "house_zombie_0"
	world.entity_system.deactivate(id)
	var record: Dictionary = world.model.entities[id]
	record.position = Vector3(3.5, 0, 10.5)
	record.home = record.position
	record.spawn_position = record.position
	record.state = {"health": 100, "wait": 100}
	world.entity_system.activate(id, record)
	world.entity_system.damage_actor(id, 1000, 180)
	expect(remnants(world).size() == 1 and world.status.text.contains("själsrest"), "Zombie death must leave one soul remnant and a clear death message")
	world.entity_system.mark_dead(id, 180)
	expect(remnants(world).size() == 1, "Repeated death handling must not duplicate loot")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and remnants(world).size() == 1, "Saving and loading dead zombie must preserve exactly one remnant")
	var drop_id: String = remnants(world)[0]
	world.entity_system.tick(Vector3(3.5, 0, 11), 1)
	bag = Inventory.new()
	world.entity_system.collect(world.model.entities[drop_id].position, bag)
	expect(bag.count_item("soul_remnant") == 0, "Remnant must be visible briefly before auto-pickup")
	for frame in range(60):
		world.entity_system.simulate_drops(1.0 / 60.0)
	expect(world.entity_system.active[drop_id].resource_kind == "soul_remnant", "World pickup must use dedicated soul visual")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position = Vector3(3.5, 0.05, 11.7)
		world.player.camera.look_at(world.model.entities[drop_id].position + Vector3(0, 0.18, 0))
		world.inventory.slots[24] = {"kind": "", "count": 0}
		world.update_counter()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://soul-remnant-preview.png")
	world.model.advance(1.1)
	var full := Inventory.new()
	full.add_items("dirt", 2048)
	world.entity_system.collect(world.model.entities[drop_id].position, full)
	expect(world.model.entities.has(drop_id), "Full inventory must leave remnant in the world")
	world.entity_system.collect(world.model.entities[drop_id].position, bag)
	expect(bag.count_item("soul_remnant") == 1 and not world.model.entities.has(drop_id), "Going near remnant must collect exactly one item")
	world.model.advance(180)
	world.entity_system.respawn_zombies()
	expect(remnants(world).is_empty(), "Zombie respawning must not itself create loot")
	world.entity_system.tick(Vector3(3.5, 0, 11), 1)
	world.entity_system.damage_actor(id, 1000, 180)
	expect(remnants(world).size() == 1, "Next zombie life must yield a new remnant on death")
	world.inventory = Inventory.new()
	world.inventory.add_items("soul_remnant", 65)
	world.update_counter()
	world.toggle_inventory()
	expect(world.inventory_slots[24].count_label.text == "64" and world.inventory_slots[25].count_label.text == "1", "Inventory must display soul stack counts")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://soul-inventory-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("SOUL REMNANT TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
