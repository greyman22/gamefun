extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Doors = preload("res://scripts/core/doors.gd")
const Craft = preload("res://scripts/crafting.gd")
const Cycle = preload("res://scripts/core/day_cycle.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var table := Craft.new(3)
	for row in range(3):
		for column in range(2):
			table.slots[row*3+column] = Registry.stack("planks",1)
	expect(table.recipe().get("kind") == "door", "Six planks in first two columns craft a door")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.new_world(123,"debug")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	expect(world.inventory.count_item("bedrock") == 0 and not Registry.breakable("bedrock"),"Bedrock absent in debug and always unbreakable")
	world.day_hud.night()
	expect(Cycle.clock_text(world.model) == "22:00", "Night debug button jumps to night")
	var cell := Vector3i(3,35,3)
	world.model.set_block(cell+Vector3i.DOWN,"dirt")
	expect(Doors.can_place(world.model,cell),"Door needs ground and two clear cells")
	Doors.place(world.model,cell,0)
	var id: String = Doors.entity_id(world.model,cell)
	world.entity_system.activate(id,world.model.entities[id])
	expect(Registry.cube(world.model.block(cell)) and world.model.kind_at(cell+Vector3i.UP)=="door_top","Closed door occupies two cells and blocks navigation")
	expect(Doors.toggle(world.entity_system,cell+Vector3i.UP),"Upper half opens whole door")
	expect(not Registry.cube(world.model.block(cell)) and world.entity_system.active[id].hinge.rotation.y < -1,"Open leaf turns and doorway becomes passable")
	world.player.position = Vector3(cell)+Vector3(0.5,0,0.5)
	expect(Doors.toggle(world.entity_system,cell,world.player),"Door closes while player occupies doorway")
	Doors.toggle(world.entity_system,cell)
	world.player.position = Vector3(6,35,5)
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and world.model.entities[id].open,"Open state survives full save")
	expect(Doors.toggle(world.entity_system,cell),"Door closes again")
	world.player.position = Vector3(3.5,35,6)
	await process_frame
	world.player.camera.look_at(Vector3(3.5,36,3.12))
	world.player.movement_blocked = false
	await physics_frame
	await physics_frame
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	world._unhandled_input(right)
	expect(world.model.entities[id].open,"Actual right-click ray opens door")
	Doors.toggle(world.entity_system,cell)
	if "--capture-ui" in OS.get_cmdline_user_args():
		for x in range(0,8):
			for z in range(0,8):
				world.model.set_block(Vector3i(x,34,z),"dirt")
		for index in range(6):
			var kind: String = ["wood","planks","soul_block","foliage","dirt","stone"][index]
			world.model.set_block(Vector3i(index+1,35,1),kind)
		world.streamer.build_now(Vector3i(0,2,0))
		world.player.position = Vector3(6,35,7)
		await process_frame
		world.player.camera.look_at(Vector3(3.5,36,2.5))
		Cycle.state(world.model).minute = 720.0
		world.day_hud.refresh(0)
		world.update_daylight(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://doors-materials-preview.png")
		Doors.toggle(world.entity_system,cell)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://door-open-preview.png")
	# Closing selects the nearest side of the actual leaf, rather than rejecting the whole cell.
	if not world.model.entities[id].open:
		Doors.toggle(world.entity_system,cell)
	world.player.position = Vector3(cell)+Vector3(0.5,0,0.1)
	expect(Doors.toggle(world.entity_system,cell,world.player) and world.player.position.z < cell.z, "Player just outside leaf ends outside")
	Doors.toggle(world.entity_system,cell)
	world.player.position = Vector3(cell)+Vector3(0.5,0,0.15)
	expect(Doors.toggle(world.entity_system,cell,world.player) and world.player.position.z > cell.z+0.5, "Player just inside leaf ends inside")
	Doors.toggle(world.entity_system,cell)
	world.player.position = Vector3(6,35,5)
	await physics_frame
	await physics_frame
	var picked: Variant = Doors.pick(world.entity_system,Vector3(2.8,36,6),Vector3(2.8,36,2),[world.player.get_rid()])
	expect(picked == cell,"Clicking slightly left of hinge still selects door")
	world.model.set_block(cell+Vector3i.DOWN,"air")
	var door_drops: Array = world.model.entities.values().filter(func(r: Dictionary) -> bool: return r.type=="pickup" and r.kind=="door")
	expect(door_drops.size()==1 and door_drops[0].state.falling,"Removing support drops exactly one door item")
	expect(world.model.block(cell)==0 and world.model.block(cell+Vector3i.UP)==0 and not world.model.entities.has(id),"Breaking removes both halves and entity")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("DOORS AND MATERIALS TESTS: ","PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
