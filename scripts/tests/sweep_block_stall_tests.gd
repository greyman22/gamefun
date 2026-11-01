extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Crafting = preload("res://scripts/crafting.gd")
const Inventory = preload("res://scripts/inventory.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	Registry.initialize()
	Combat.initialize()
	expect(ProjectSettings.get_setting("application/config/name") == "Game Fun", "Game window must use Game Fun name")
	var table := Crafting.new(3)
	for slot in table.slots:
		slot.kind = "soul_remnant"
		slot.count = 1
	var bag := Inventory.new()
	expect(table.craft(bag) and bag.count_item("soul_block") == 1, "Nine soul remnants must craft one soul block on workbench")
	expect(Registry.stack_limit("soul_block") == 64 and Registry.cube(Registry.id("soul_block")), "Soul block must be a stackable solid block")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var positions: Array[Vector3] = [Vector3(-1, 0, 11.8), Vector3(2, 0, 11.8), Vector3(2.5, 0, 12.5), Vector3(0.5, 0, 14), Vector3(0.5, 0, 10.3)]
	var ids: Array[String] = []
	for index in range(5):
		var id: String = "house_zombie_%d" % index
		ids.append(id)
		world.entity_system.deactivate(id)
		var record: Dictionary = world.model.entities[id]
		record.position = positions[index]
		record.home = positions[index]
		record.spawn_position = positions[index]
		record.state = {"health": 100, "wait": 100}
		world.entity_system.activate(id, record)
	world.model.set_block(Vector3i(0, 1, 11), "stone")
	world.streamer.build_now(Vector3i.ZERO)
	world.player.position = Vector3(0.5, 0.05, 12.5)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	world.inventory.slots[27] = {"kind": "stone_sword", "count": 1}
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	expect(world.try_attack(), "Sword sweep must find creatures in the front semicircle")
	expect(Registry.remaining_uses(world.inventory.slots[27]) == 99, "A three-target sweep must cost one weapon use, not three")
	var sword_damage: float = Combat.damage(25, 30)
	for index in range(5):
		var expected: float = 100 - sword_damage if index < 3 else 100
		expect(is_equal_approx(world.entity_system.active[ids[index]].health, expected), "Sweep must hit all three front targets and exclude rear/occluded targets")
	expect(world.attack_cooldown == 0.5, "A multi-target sweep must consume only one attack interval")
	world.inventory.slots[27] = {"kind": "axe", "count": 1}
	world.select_hotbar(0)
	world.player.camera.look_at(positions[0] + Vector3(0, 1.4, 0))
	world.attack_cooldown = 0
	expect(world.try_attack(), "Axe must hit its aimed target")
	expect(is_equal_approx(world.entity_system.active[ids[0]].health, 100 - sword_damage - Combat.damage(35, 30)), "Axe must deal more damage than sword")
	expect(is_equal_approx(world.entity_system.active[ids[1]].health, 100 - sword_damage) and world.attack_cooldown == 1, "Axe must affect only one target and have slower frequency")
	var corpse: Vector3 = world.entity_system.active[ids[0]].position
	world.entity_system.damage_actor(ids[0], 1000, 180)
	var soul: Dictionary = {}
	for entity: Dictionary in world.model.entities.values():
		if entity.type == "pickup" and entity.kind == "soul_remnant":
			soul = entity
	expect(not soul.is_empty() and soul.position == corpse + Vector3(0, 0.95, 0) and soul.state.velocity_x == 0 and soul.state.velocity_z == 0, "Soul remnant must start at zombie centre and fall straight down")
	world.model.set_block(Vector3i(5, 0, 10), "soul_block")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and world.model.kind_at(Vector3i(5, 0, 10)) == "soul_block", "Soul blocks must persist through save/load")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.inventory.add_items("soul_remnant", 9)
		world.toggle_inventory(true)
		for entry: Dictionary in world.template_buttons:
			if entry.recipe.kind == "soul_block":
				world.fill_recipe_template(entry.recipe)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://soul-block-crafting-preview.png")
		world.toggle_inventory()
	# A hanging stance on a tiny part of a ledge must not loop in place forever.
	var actor = world.entity_system.active[ids[1]]
	world.model.set_block(Vector3i(1, 0, 10), "stone")
	world.model.set_block(Vector3i(0, 1, 11), "air")
	world.model.set_block(Vector3i(1, 0, 10), "air")
	world.model.set_block(Vector3i(1, 0, 11), "stone")
	actor.position = Vector3(0.7, 0, 11.3)
	actor.hopping = false
	actor.knockback.stop()
	actor.behavior = "chase"
	actor.goal = Vector3(1.5, 0, 10.5)
	expect(actor.clear_at(actor.position) and not actor.start_hop((actor.goal - actor.position).normalized()), "A diagonal corner must not start a hop that lands hanging on a sliver of support")
	world.model.set_block(Vector3i(1, 0, 11), "air")
	world.model.set_block(Vector3i(1, 0, 10), "stone")
	actor.position = Vector3(0.75, 1, 10.5)
	actor.hopping = false
	actor.knockback.stop()
	actor.wait = 0
	actor.behavior = "return"
	actor.goal = Vector3(1.5, 1, 10.5)
	actor.progress_anchor = actor.position
	actor.progress_elapsed = 0
	var attempts: int = 0
	var last_hopping: bool = false
	for frame in range(180):
		actor.simulate(1.0 / 60.0)
		if actor.hopping and not last_hopping:
			attempts += 1
		last_hopping = actor.hopping
		if Vector2(actor.position.x - 1.5, actor.position.z - 10.5).length() < 0.25 and actor.grounded():
			break
	expect(actor.clear_at(actor.position) and attempts <= 3 and Vector2(actor.position.x - 1.5, actor.position.z - 10.5).length() < 0.25, "Edge stance must reach stable footing instead of repeating a failed jump")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("SWEEP, BLOCK AND STALL TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
