extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func platform(world: Node, height: int) -> void:
	for x in range(-2, 1):
		for z in range(9, 13):
			for y in range(5):
				world.model.set_block(Vector3i(x, y, z), "stone" if y < height else "air")

func spawn(world: Node, position: Vector3, health: float) -> Node3D:
	var id: String = "house_zombie_0"
	world.entity_system.deactivate(id)
	var record: Dictionary = world.model.entities[id]
	record.position = position
	record.home = position
	record.spawn_position = position
	record.state = {"health": health, "wait": 100}
	world.entity_system.activate(id, record)
	return world.entity_system.active[id]

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var id: String = "house_zombie_0"
	platform(world, 4)
	var actor = spawn(world, Vector3(0.5, 4, 10.5), 8)
	actor.apply_knockback(Vector3(-0.5, 4, 10.5), 30)
	for frame in range(180):
		world.entity_system.simulate_actors(1.0 / 60.0)
		if not world.entity_system.active.has(id):
			break
	expect(world.model.entities[id].state.get("dead", false) and not world.entity_system.active.has(id), "A low-health zombie knocked off a four-metre ledge must take fall damage and disappear")
	platform(world, 1)
	actor = spawn(world, Vector3(0.5, 1, 10.5), 8)
	actor.apply_knockback(Vector3(-0.5, 1, 10.5), 30)
	for frame in range(90):
		world.entity_system.simulate_actors(1.0 / 60.0)
	expect(world.entity_system.active.has(id) and actor.health == 8 and actor.clear_at(actor.position), "A one-block fall must preserve health and never embed the zombie in the ledge")
	platform(world, 0)
	actor = spawn(world, Vector3(2.5, 3, 10.5), 80)
	for frame in range(10):
		world.entity_system.simulate_actors(1.0 / 60.0)
	var falling_save: Dictionary = world.snapshot()
	expect(world.restore_snapshot(falling_save), "A zombie save taken during a fall must load")
	for frame in range(120):
		world.entity_system.simulate_actors(1.0 / 60.0)
	actor = world.entity_system.active[id]
	expect(absf(actor.health - 60) < 0.01 and actor.clear_at(actor.position), "A saved three-metre fall must preserve fall height and cause twenty damage on landing")
	# Old saves can already contain the partially buried position from this bug.
	platform(world, 3)
	actor = spawn(world, Vector3(1.05, 0, 10.5), 8)
	expect(actor.clear_at(actor.position), "Activating an already wedged zombie must recover it to a nearby clear position")
	var recovered: Vector3 = actor.position
	actor.wait = 0
	actor.behavior = "return"
	actor.goal = actor.position + Vector3(2, 0, 0)
	for frame in range(12):
		actor.simulate(1.0 / 60.0)
	expect(actor.position.distance_to(recovered) > 0.2, "A recovered zombie must be able to walk again")
	world.streamer.build_now(Vector3i(0, 0, 0))
	world.player.position = actor.position + Vector3(0, 0.05, 1.6)
	world.player.camera.look_at(actor.position + Vector3(0, 1.4, 0))
	world.inventory.slots[24] = {"kind": "stone_sword", "count": 1}
	world.select_hotbar(0)
	world.attack_cooldown = 0
	await physics_frame
	await physics_frame
	expect(world.try_attack() and world.model.entities[id].state.get("dead", false), "Recovered zombie must remain hittable and die from the next sword strike")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("ZOMBIE LEDGE TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
