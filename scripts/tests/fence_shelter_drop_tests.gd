extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Craft = preload("res://scripts/crafting.gd")
const Access = preload("res://scripts/core/pursuit_access.gd")
const Doors = preload("res://scripts/core/doors.gd")
const Hens = preload("res://scripts/core/hens.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Job = preload("res://scripts/rendering/chunk_job.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func side_tile(world: Node, cell: Vector3i) -> int:
	var key: Vector3i = world.model.key(cell)
	var job := Job.new(world.model.seed_value,key,world.model.worker_edits(key))
	job.run()
	var vertices: PackedVector3Array = job.result.arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = job.result.arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = job.result.arrays[Mesh.ARRAY_COLOR]
	var target := Vector3(cell-key*16)+Vector3(1,0.5,0.5)
	for index in range(0,vertices.size(),4):
		var center := (vertices[index]+vertices[index+1]+vertices[index+2]+vertices[index+3])/4
		if normals[index]==Vector3.RIGHT and center.distance_to(target)<0.01:
			return roundi(colors[index].r*255)+roundi(colors[index].g*255)*256
	return -1
func run() -> void:
	Registry.initialize()
	var table := Craft.new(3)
	for index in range(6):
		table.slots[index]=Registry.stack("stick" if index%3==1 else "planks",1)
	expect(table.recipe().get("kind")=="fence" and table.recipe().get("count")==6,"Four planks and two sticks craft six fence sections")
	var world = load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	var soil := Vector3i(12,35,3)
	world.model.set_block(soil,"dirt")
	var expected: int = Registry.tile(Registry.id("dirt"),Vector3i.RIGHT)
	world.model.set_block(soil+Vector3i.UP,"torch")
	expect(side_tile(world,soil)==expected,"Torch above soil must not remove grass surface")
	world.model.set_block(soil+Vector3i.UP,"stone")
	expect(side_tile(world,soil)!=expected,"Actual solid cover still removes grass")
	for kind: String in ["stick","foliage","wood","dirt","stone"]:
		var pickup := Pickup.new()
		pickup.configure(kind)
		expect(pickup.scale==Vector3.ONE*1.25,"Requested dropped item is 25% larger")
		pickup.free()
	var leaf := Vector3i(11,35,5)
	world.model.set_block(leaf,"foliage")
	world.player.position=Vector3(11.5,35,8)
	world.inventory.slots[27]=Registry.stack("axe",1)
	world.select_hotbar(0)
	world.target_cell=leaf
	world.target_bush=""
	world.mining_held=true
	world.update_mining(0.69)
	expect(world.model.kind_at(leaf)=="foliage","Axe waits full 1.2 seconds")
	world.update_mining(0.02)
	var drops: Array = world.model.entities.values().filter(func(r: Dictionary)->bool: return r.type=="pickup" and r.kind in ["foliage","stick"])
	expect(world.model.kind_at(leaf)=="air" and drops.size()==1 and drops[0].state.falling,"Chopped foliage becomes a falling branch or stick")
	# Closed block house: interior 5x6 with a closed two-block door.
	for x in range(-3,10):
		for z in range(-3,13):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	for x in range(7):
		for z in range(8):
			world.model.set_block(Vector3i(x,38,z),"planks")
			if x in [0,6] or z in [0,7]:
				for y in range(35,38):
					world.model.set_block(Vector3i(x,y,z),"planks")
	world.model.set_block(Vector3i(3,35,7),"air")
	world.model.set_block(Vector3i(3,36,7),"air")
	Doors.place(world.model,Vector3i(3,35,7),0)
	var access := Access.new()
	access.configure(world.model)
	var outside := Vector3(3.5,35,9.5)
	var inside := Vector3(3.5,35,5.5)
	expect(not access.allowed(outside,inside),"Closed block house protects player")
	world.player.position=inside
	world.model.entities.guard={"type":"zombie","position":outside,"home":outside,"state":{"behavior":"chase"}}
	world.entity_system.activate("guard",world.model.entities.guard)
	Hens.create(world.model,"lured",outside+Vector3.RIGHT,outside,"debug")
	world.entity_system.activate("lured",world.model.entities.lured)
	world.entity_system.soul_lure=inside
	world.entity_system.simulate_actors(0,world.player)
	expect(world.entity_system.active.guard.behavior!="chase" and not world.entity_system.active.guard.can_hit(world.player),"Existing chase stops and no attack inside sealed house")
	expect(not world.entity_system.active.lured.following_soul,"Soul attraction stops inside sealed house")
	Doors.toggle(world.entity_system,Vector3i(3,35,7))
	expect(access.allowed(outside,inside),"Open door restores access immediately")
	Doors.remove(world.entity_system,Vector3i(3,35,7))
	for x in range(7):
		for z in range(8):
			if x in [0,6] or z in [0,7]:
				world.model.set_block(Vector3i(x,35,z),"fence")
				for y in [36,37]:
					world.model.set_block(Vector3i(x,y,z),"air")
	expect(access.allowed(outside,inside),"Fence enclosure deliberately preserves attraction")
	world.entity_system.active.guard.position=Vector3(3.5,35,8.3)
	world.player.position=Vector3(3.5,35,6.5)
	world.entity_system.soul_lure=world.player.position
	world.entity_system.simulate_actors(0,world.player)
	expect(world.entity_system.active.guard.behavior=="chase" and world.entity_system.active.guard.can_hit(world.player),"Zombie stays attracted and can reach player too near fence")
	expect(world.entity_system.active.lured.following_soul,"Hens remain attracted through fence")
	world.player.vitals.protection=0
	var before_health: float = world.player.vitals.health
	for frame in range(120):
		world.model.advance(1.0/60)
		world.entity_system.simulate_actors(1.0/60,world.player)
	expect(world.entity_system.active.guard.position.z>=8.2,"Zombie cannot walk or hop through fence")
	expect(world.player.vitals.health < before_health,"Zombie actually damages a player standing too near fence")
	if "--capture-ui" in OS.get_cmdline_user_args():
		for x in range(7):
			for z in range(8):
				world.model.set_block(Vector3i(x,38,z),"air")
				if x in [0,6] or z in [0,7]:
					var cell := Vector3i(x,35,z)
					var id: String = "fence_"+world.model.text_key(cell)
					world.model.entities[id]={"type":"fence","kind":"fence","cell":cell,"position":Vector3(cell)+Vector3(0.5,0,0.5),"state":{}}
					world.entity_system.activate(id,world.model.entities[id])
		world.player.position=Vector3(9,35,11)
		world.streamer.warm_start(world.player.position)
		await process_frame
		world.player.camera.look_at(Vector3(3.5,35.8,4.5))
		world.update_daylight(1)
		world.day_hud.refresh(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://fence-shelter-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("FENCE SHELTER DROP TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
