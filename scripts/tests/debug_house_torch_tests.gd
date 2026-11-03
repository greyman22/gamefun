extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const House = preload("res://scripts/core/debug_house.gd")
const Doors = preload("res://scripts/core/doors.gd")
const Registry = preload("res://scripts/core/registry.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
const Cycle = preload("res://scripts/core/day_cycle.gd")
const Hens = preload("res://scripts/core/hens.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var data := Data.new(123)
	var house: Dictionary = House.new().place(data)
	var base: Vector3i = house.base
	for x in range(-1,8):
		var y: int=4+(4-absi(x-3))/2
		for z in range(-1,9):
			expect(data.kind_at(base+Vector3i(x,y,z))=="stone","Debug house has a sloping stone roof")
	for x in range(1,6):
		for z in range(1,7):
			expect(data.kind_at(base+Vector3i(x,0,z))=="planks" and data.kind_at(base+Vector3i(x,4,z))=="planks","Interior floor and ceiling enclose exactly three blocks of height")
			for y in range(1,4):
				expect(data.kind_at(base+Vector3i(x,y,z)) in ["air","torch"],"Interior 5x6 stays free of solid obstacles")
	expect(house.torches.size()==8 and data.entities.has(Doors.entity_id(data,house.door)),"House has eight torches and a functional door")
	for normal: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var point: Vector3 = Visuals.torch_anchor(Vector3i(3,35,3),normal)
		expect(is_equal_approx(point.y,35.5),"Wall torch is vertically centred")
		expect((Visuals.torch_tilt(normal)*Vector3.UP).dot(normal)>0.3,"Wall torch leans outward")
	expect(Visuals.torch_anchor(Vector3i(3,35,3),Vector3.UP)==Vector3(3.5,35.25,3.5),"Standing torch centred on block")
	expect(Hens.interval("debug")==120,"Debug egg production is halved")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.new_world(123,"debug")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	expect(world.model.landmarks.has("debug_house"),"Debug mode creates house automatically")
	expect(world.sun_light.shadow_opacity <= 0.3,"Shadows are softened rather than globally brightening animals")
	var old_egg := {"type":"pickup","kind":"egg","position":world.player.position,"state":{}}
	world.model.entities.old_egg = old_egg
	world.entity_system.expire_drops()
	expect(old_egg.expires_at==world.model.game_time+300,"Legacy eggs gain expiry deadline")
	world.model.game_time += 301
	world.entity_system.expire_drops()
	expect(not world.model.entities.has("old_egg"),"Eggs disappear after timeout")
	var actual: Dictionary = world.model.landmarks.debug_house
	world.entity_system.tick(Vector3(actual.base),1)
	for id: String in actual.torches:
		expect(world.entity_system.active.has(id),"All house torches stream in")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and world.model.landmarks.debug_house.torches.size()==8,"House and lights persist")
	if "--capture-ui" in OS.get_cmdline_user_args():
		base=world.model.landmarks.debug_house.base
		world.player.position=Vector3(base)+Vector3(3.5,1,13)
		world.player.position.y=maxf(world.player.position.y,world.model.generator.height(floori(world.player.position.x),floori(world.player.position.z))+0.05)
		await process_frame
		world.player.camera.look_at(Vector3(base)+Vector3(3.5,3,4))
		world.streamer.warm_start(world.player.position)
		for hour in [12,23]:
			Cycle.state(world.model).minute=hour*60.0
			world.entity_system.tick(world.player.position,1)
			world.update_daylight(1)
			world.day_hud.refresh(0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://debug-house-%d-preview.png"%hour)
		world.player.position=Vector3(base)+Vector3(3.5,1,4)
		await process_frame
		world.player.camera.look_at(Vector3(base)+Vector3(3.5,2.5,0))
		world.update_daylight(1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://debug-house-inside-preview.png")
	if "--capture-ui" in OS.get_cmdline_user_args():
		Cycle.state(world.model).minute=720.0
		world.player.position=Vector3(0,1,12)
		await process_frame
		world.player.camera.look_at(Vector3(1,0.5,8))
		world.update_daylight(1)
		world.day_hud.refresh(0)
		world.inventory.slots[27]=Registry.stack("foliage",12)
		world.inventory.slots[28]=Registry.stack("planks",20)
		world.update_counter()
		world.toggle_inventory()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://leaf-plank-preview.png")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.toggle_inventory()
		var torch_cell := Vector3i(0,0,9)
		world.model.set_block(torch_cell,"torch")
		world.model.entities.grass_torch = {"type":"torch","kind":"torch","cell":torch_cell,"position":Visuals.torch_anchor(torch_cell,Vector3.UP),"normal":Vector3.UP,"state":{}}
		world.entity_system.activate("grass_torch",world.model.entities.grass_torch)
		world.player.position=Vector3(0.5,0.05,12.5)
		await process_frame
		world.player.camera.look_at(Vector3(0.5,0.2,9.5))
		world.update_daylight(1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://neutral-torch-grass-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("DEBUG HOUSE TORCH TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
