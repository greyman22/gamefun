extends SceneTree

const Registry = preload("res://scripts/core/registry.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Zombie = preload("res://scripts/zombie.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	Registry.initialize()
	for kind in ["stone_sword", "pickaxe", "axe", "shovel"]:
		expect(Registry.stack_limit(kind) == 1, "Each tool must occupy its own slot")
	var bag := Inventory.new()
	expect(bag.add_items("stone_sword", 2) and bag.slots[24].count == 1 and bag.slots[25].count == 1, "Two swords must occupy two slots")
	expect(not bag.move_stack(24, 25), "Swords must not merge into a stack")
	expect(bag.add_items("dirt", 64) and bag.slots[26].count == 64, "Materials must retain their 64-item stacks")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var zombie := Zombie.new()
	var record: Dictionary = {"position": Vector3(0.5, 0, 10.5), "home": Vector3(0.5, 0, 10.5), "spawn_position": Vector3(0.5, 0, 10.5), "state": {}}
	zombie.configure(world.model, record)
	zombie.position = record.position
	root.add_child(zombie)
	world.player.position = zombie.position + Vector3(10.1, 0, 0)
	zombie.update_behavior(0.016, world.player)
	expect(zombie.behavior == "wander", "A zombie must not notice player outside ten metres")
	world.player.position = zombie.position + Vector3(9.9, 0, 0)
	zombie.update_behavior(0.016, world.player)
	expect(zombie.behavior == "chase", "Zombie must start pursuit within ten metres")
	world.player.position = zombie.position + Vector3(15, 0, 0)
	zombie.update_behavior(0.016, world.player)
	expect(zombie.behavior == "chase", "Acquired pursuit must continue between ten and twenty metres")
	var before: Vector3 = zombie.position
	for frame in range(60):
		zombie.simulate(1.0 / 60.0, world.player)
	expect(absf(zombie.position.distance_to(before) - 5.0 / 3.0) < 0.15 and Zombie.SPEED == world.player.SPEED / 3.0, "Zombie must walk at one third player speed")
	world.player.position = zombie.position + Vector3(20.1, 0, 0)
	zombie.update_behavior(0.016, world.player)
	expect(zombie.behavior == "return", "Pursuit must break beyond twenty metres")
	world.player.position = Vector3(30, 0, 10.5)
	var returned: bool = false
	for frame in range(450):
		zombie.simulate(1.0 / 60.0, world.player)
		if zombie.behavior == "wander" and zombie.position.distance_to(zombie.origin) < 0.8:
			returned = true
			break
	expect(returned, "A zombie must return to its own original spawn after losing player")
	# Chasing routes around a solid wall instead of repeatedly walking into it.
	zombie.position = zombie.origin
	zombie.hopping = false
	zombie.set_behavior("chase")
	world.player.position = Vector3(4.5, 0, 10.5)
	for z in [10, 11]:
		for y in range(3):
			world.model.set_block(Vector3i(2, y, z), "stone")
	var detoured: bool = false
	var clear_route: bool = true
	for frame in range(450):
		zombie.simulate(1.0 / 60.0, world.player)
		detoured = detoured or absf(zombie.position.z - 10.5) > 0.6
		clear_route = clear_route and zombie.clear_at(zombie.position)
		if zombie.position.distance_to(world.player.position) < 1.5:
			break
	expect(detoured and clear_route and zombie.position.distance_to(world.player.position) < 1.5, "Chase must navigate around a tall wall and reach the player")
	for z in [10, 11]:
		for y in range(3):
			world.model.set_block(Vector3i(2, y, z), "air")
	# Attack has a visible windup, an actual impact and a dodge opportunity.
	zombie.position = Vector3(0.5, 0, 10.5)
	zombie.hopping = false
	zombie.strike_time = -1
	zombie.attack_cooldown = 0
	world.player.position = zombie.position + Vector3(0, 0, 1.2)
	world.player.vitals.reset()
	world.player.vitals.protection = 0
	zombie.attack(world.player)
	zombie.advance_strike(0.2, world.player)
	zombie.animate(false, 0)
	expect(world.player.vitals.health == 100 and zombie.right_arm.rotation.x < 0, "Zombie must pull its arm back before impact")
	world.player.position.z += 3
	zombie.advance_strike(0.15, world.player)
	expect(world.player.vitals.health == 100, "Moving away before impact must dodge a zombie strike")
	zombie.strike_time = -1
	zombie.attack_cooldown = 0
	world.player.position = zombie.position + Vector3(0, 0, 1.2)
	zombie.attack(world.player)
	zombie.advance_strike(0.36, world.player)
	zombie.animate(false, 0)
	expect(world.player.vitals.health < 100 and zombie.right_arm.rotation.x > 1.5, "Actual impact must coincide with the visible forward strike")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.camera.look_at(zombie.position + Vector3(0, 1.5, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://zombie-melee-preview.png")
	zombie.queue_free()
	# Existing stacks are migrated without losing tools.
	world.new_world(42, "debug")
	var legacy: Dictionary = world.snapshot()
	legacy.inventory[24] = {"kind": "stone_sword", "count": 3}
	expect(world.restore_snapshot(legacy) and world.inventory.count_item("stone_sword") == 3, "Legacy sword stack must split into separate inventory slots")
	for slot in world.inventory.slots:
		expect(slot.count <= Registry.stack_limit(slot.kind), "Every restored slot must respect its new tool stack limit")
	legacy = world.snapshot()
	for slot in legacy.inventory:
		slot.kind = "axe"
		slot.count = 64
	expect(world.restore_snapshot(legacy), "Full legacy inventory must still load")
	var axes: int = world.inventory.count_item("axe")
	for entity: Dictionary in world.model.entities.values():
		if entity.type == "pickup" and entity.kind == "axe":
			axes += int(entity.get("count", 1))
	expect(axes == 2048, "Overflowing legacy tool stacks must become world pickups without loss")
	world.inventory.slots[24] = {"kind": "stone_sword", "count": 1}
	world.update_counter()
	expect(world.hotbar_slots[0].count_label.text.is_empty(), "Tool slots must hide the count indicator")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.toggle_inventory()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://nonstack-tools-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("PURSUIT AND TOOL TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
