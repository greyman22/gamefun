extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Hens = preload("res://scripts/core/hens.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func drops(world: Node) -> int:
	return world.model.entities.values().filter(func(r: Dictionary) -> bool: return r.type == "pickup" and r.kind == "raw_chicken").size()
func spawn(world: Node, id: String, point: Vector3, chick: bool = false, defense: float = 10) -> void:
	Hens.create(world.model,id,point,point,"debug",chick)
	world.model.entities[id].defense = defense
	world.entity_system.activate(id,world.model.entities[id])
func run() -> void:
	Registry.initialize()
	Combat.initialize()
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for x in range(0,7):
		for z in range(0,7):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	spawn(world,"victim",Vector3(3.5,35,2.5))
	world.player.position = Vector3(3.5,35,4)
	world.player.camera.look_at(Vector3(3.5,35.4,2.5))
	world.inventory.slots[27] = Registry.stack("axe",1)
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	expect(world.try_attack() and not world.model.entities.has("victim") and drops(world) == 1, "Axe kills ordinary adult and drops one raw chicken")
	expect(Registry.remaining_uses(world.inventory.slots[27]) == 99, "Successful axe strike wears once")
	world.attack_cooldown = 0
	spawn(world,"tough",Vector3(3.5,35,2.5),false,90)
	await physics_frame
	expect(world.try_attack() and world.model.entities.has("tough") and world.entity_system.active.tough.health > 0, "Rare high defense hen survives first axe hit")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and world.model.entities.tough.defense == 90 and world.entity_system.active.tough.health < 24, "Defense and partial health persist")
	world.attack_cooldown = 0
	await physics_frame
	expect(world.try_attack() and not world.model.entities.has("tough") and drops(world) == 2, "Second axe hit kills tough hen")
	world.attack_cooldown = 0
	spawn(world,"young",Vector3(3.5,35,2.5),true)
	await physics_frame
	expect(world.try_attack() and not world.model.entities.has("young") and drops(world) == 2, "Chick dies without loot")
	world.inventory.slots[27] = Registry.stack("stone_sword",1)
	world.update_counter()
	spawn(world,"left",Vector3(2.7,35,2.5))
	spawn(world,"right",Vector3(4.3,35,2.5))
	world.attack_cooldown = 0
	world.try_attack()
	expect(world.entity_system.active.left.health < 24 and world.entity_system.active.right.health < 24, "Sword sweep hits both hens")
	world.attack_cooldown = 0
	world.try_attack()
	expect(not world.model.entities.has("left") and not world.model.entities.has("right") and drops(world) == 4, "Second sword sweep kills ordinary adults")
	for id: String in world.model.entities.keys():
		if world.model.entities[id].type == "pickup" and world.model.entities[id].kind == "raw_chicken":
			var point: Vector3 = world.model.entities[id].position
			world.entity_system.activate(id,world.model.entities[id]) if not world.entity_system.active.has(id) else 0
			world.model.game_time += 1
			world.entity_system.collect(point,world.inventory)
	expect(world.inventory.count_item("raw_chicken") == 4, "Raw chicken collects into inventory")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.toggle_inventory()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://raw-chicken-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("HEN COMBAT TESTS: ","PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
