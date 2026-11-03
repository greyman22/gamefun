extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Hens = preload("res://scripts/core/hens.gd")
const Data = preload("res://scripts/core/world_data.gd")
const System = preload("res://scripts/core/entity_system.gd")
const Bag = preload("res://scripts/inventory.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func eggs(model: RefCounted) -> Array:
	return model.entities.values().filter(func(r: Dictionary) -> bool: return r.type == "pickup" and r.kind == "egg")
func run() -> void:
	Registry.initialize()
	var data := Data.new(123)
	Hens.ensure_nearby(data, Vector3(18, 0, 18), "debug")
	var groups: Dictionary = data.landmarks.hen_groups
	expect(groups.size() > 0, "Nearby hen groups generated")
	var original := data.entities.size()
	Hens.ensure_nearby(data, Vector3(18, 0, 18), "debug")
	expect(data.entities.size() == original, "Groups must not duplicate on revisit")
	for record: Dictionary in data.entities.values():
		expect(record.type == "hen", "Wild groups contain adult hens and occasional chicks")
	for trial in range(40):
		var interval := Hens.interval("play")
		expect(interval >= 180 and interval <= 300, "Play egg intervals 3-5 minutes")
	var homes: Dictionary = {}
	for record: Dictionary in data.entities.values():
		var group_center: Vector3=record.get("group_center",record.home)
		homes[group_center] = int(homes.get(group_center, 0)) + 1
	for count: int in homes.values():
		expect(count in [3, 4], "Natural flocks contain three or four hens")
	data = Data.new(123)
	for x in range(-3, 7):
		for z in range(-3, 7):
			data.set_block(Vector3i(x, 34, z), "dirt")
	Hens.create(data, "a", Vector3(1.5, 35, 1.5), Vector3(1.5, 35, 1.5), "debug")
	Hens.create(data, "b", Vector3(2.1, 35, 1.5), Vector3(1.5, 35, 1.5), "debug")
	var system := System.new()
	system.configure(data, "debug")
	root.add_child(system)
	system.activate("a", data.entities.a)
	system.activate("b", data.entities.b)
	expect(Hens.feed(data, "a") and not Hens.feed(data, "a"), "Adult accepts one grass seed remnant per love period")
	Hens.tick(system, 0)
	expect(data.entities.a.partner == "", "Single fed hen must wait for another")
	expect(Hens.feed(data, "b"), "Second hen accepts seed")
	Hens.tick(system, 0)
	expect(data.entities.a.partner == "b", "Nearby fed hens pair")
	data.advance(2.9)
	Hens.tick(system, 0)
	expect(data.entities.size() == 2, "Birth waits three seconds")
	data.advance(0.11)
	Hens.tick(system, 0)
	var chicks: Array = data.entities.values().filter(func(r: Dictionary) -> bool: return r.type == "hen" and not Hens.adult(r, data.game_time))
	expect(chicks.size() == 1 and data.entities.a.partner == "" and data.entities.b.love_until == 0, "One chick per pair consumes both love states")
	var chick_id: String = ""
	for id: String in data.entities:
		if id.begins_with("chick_"):
			chick_id = id
	expect(not Hens.feed(data, chick_id), "Chicks cannot breed")
	# A fed pair must walk together across flat terrain, then produce one chick.
	Hens.create(data, "walker_a", Vector3(3.5, 35, 3.5), Vector3(3.5, 35, 3.5), "debug")
	Hens.create(data, "walker_b", Vector3(5.5, 35, 3.5), Vector3(3.5, 35, 3.5), "debug")
	system.activate("walker_a", data.entities.walker_a)
	system.activate("walker_b", data.entities.walker_b)
	Hens.feed(data, "walker_a")
	Hens.feed(data, "walker_b")
	for frame in range(420):
		data.advance(1.0 / 60)
		Hens.tick(system, 1.0 / 60)
	expect(data.entities.walker_a.love_until == 0 and data.entities.walker_b.love_until == 0, "Pair two metres apart must meet and breed")
	for id: String in ["walker_a", "walker_b"]:
		system.deactivate(id)
		data.entities.erase(id)
	data.game_time = 120
	Hens.tick(system, 0)
	expect(eggs(data).size() == 2, "Debug adults each lay an egg at two minutes")
	var drop: Dictionary = eggs(data)[0]
	expect(drop.expires_at == 420 and drop.state.falling, "Egg drops physically and lasts five minutes")
	var bag := Bag.new()
	var egg_id: String = ""
	for id: String in data.entities:
		if data.entities[id].type == "pickup":
			egg_id = id
			break
	system.activate(egg_id, data.entities[egg_id])
	data.game_time = 121
	system.collect(data.entities[egg_id].position, bag)
	expect(bag.count_item("egg") == 1, "Egg can be collected into inventory")
	var roundtrip := Data.new(0)
	expect(roundtrip.import_state(data.export_state()) and roundtrip.entities[chick_id].adult_at == data.entities[chick_id].adult_at, "Growth and egg timers survive save")
	data.game_time = 124
	system.activate(chick_id, data.entities[chick_id])
	Hens.tick(system, 0)
	expect(not system.active[chick_id].chick, "Chick becomes adult after 120 seconds")
	Hens.feed(data, "a")
	data.game_time += 60
	Hens.tick(system, 0)
	expect(Hens.feed(data, "a"), "Love expires and adult accepts another seed")
	data.game_time = 1000
	system.expire_drops()
	expect(eggs(data).is_empty(), "Expired eggs removed even when inactive")
	# Integration: actual ray feeding consumes exactly one remnant and is blocked by terrain.
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for x in range(0, 7):
		for z in range(0, 7):
			world.model.set_block(Vector3i(x, 34, z), "dirt")
	Hens.create(world.model, "hen_ray", Vector3(3.5, 35, 2.5), Vector3(3.5, 35, 2.5), "debug")
	Hens.create(world.model, "chick_preview", Vector3(4.5, 35, 2.5), Vector3(3.5, 35, 2.5), "debug", true)
	world.entity_system.activate("hen_ray", world.model.entities.hen_ray)
	world.entity_system.activate("chick_preview", world.model.entities.chick_preview)
	world.inventory.slots[27] = Registry.stack("grass_seed", 2)
	world.select_hotbar(0)
	world.player.position = Vector3(3.5, 35, 4.3)
	world.player.camera.look_at(Vector3(3.5, 35.45, 2.5))
	await physics_frame
	await physics_frame
	world.inventory.slots[27]=Registry.stack("soul_remnant",2)
	expect(not world.feed_hen() and world.inventory.slots[27].count==2,"Soul remnants no longer feed hens")
	world.inventory.slots[27]=Registry.stack("grass_seed",2)
	var feed_click:=InputEventMouseButton.new()
	feed_click.button_index=MOUSE_BUTTON_RIGHT
	feed_click.pressed=true
	world._unhandled_input(feed_click)
	expect(world.model.entities.hen_ray.love_until>world.model.game_time and world.inventory.slots[27].count==1 and not world.planting_held,"Right click feeds hen with one grass seed instead of planting behind it")
	expect(world.feed_hen() and world.inventory.slots[27].count == 1, "Repeated feed does not waste grass seeds")
	world.model.entities.hen_ray.love_until = 0.0
	world.model.set_block(Vector3i(3, 35, 3), "dirt")
	world.model.set_block(Vector3i(3, 36, 3), "dirt")
	expect(not world.feed_hen() and world.inventory.slots[27].count == 1, "Feeding must not pass through walls")
	world.model.set_block(Vector3i(3, 35, 3), "air")
	world.model.set_block(Vector3i(3, 36, 3), "air")
	expect(world.feed_hen(), "Feeding works again after wall removal")
	world.entity_system.active.hen_ray.simulate(0)
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.streamer.build_now(world.model.key(Vector3i(3, 35, 2)))
		world.player.position = Vector3(3.9, 35, 5)
		world.player.camera.look_at(Vector3(3.9, 35.45, 2.5))
		var egg: String = world.entity_system.spawn_drop("egg", Vector3(3.3, 35.15, 2.9))
		world.entity_system.activate(egg, world.model.entities[egg])
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://hens-preview.png")
	var bird: Node3D = world.entity_system.active.hen_ray
	world.model.entities.hen_ray.partner = ""
	bird.step_time = 1
	bird.position = Vector3(3.5, 35, 2.5)
	var lure := Vector3(3.5, 35, 5.5)
	bird.simulate(0, lure)
	expect(bird.following_seeds and bird.step_to.z > bird.position.z, "Hen within ten metres runs toward seed holder")
	for frame in range(120):
		bird.simulate(1.0 / 60, lure)
	expect(bird.position.distance_to(lure) < 3.0, "Lure makes hen approach player")
	bird.simulate(0, bird.position + Vector3(0, 0, 9.9))
	expect(bird.following_seeds, "Hen follows at extended 9.9 metre range")
	bird.simulate(0, bird.position + Vector3(0, 0, 10.1))
	expect(not bird.following_seeds, "Hen does not follow beyond ten metres")
	bird.simulate(0, Vector3(3.5, 35, 20))
	expect(not bird.following_seeds, "Hen stops following beyond ten metres")
	bird.simulate(0, lure)
	bird.simulate(0)
	expect(not bird.following_seeds, "Hen stops following when seeds are put away")
	var snap: Dictionary = world.snapshot()
	expect(world.restore_snapshot(snap) and world.model.entities.hen_ray.love_until > world.model.game_time, "Fed hen persists in full world save")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	system.queue_free()
	await process_frame
	print("HEN TESTS: ", "PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
