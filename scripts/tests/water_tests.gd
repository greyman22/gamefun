extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Registry=preload("res://scripts/core/registry.gd")
const DebugWater=preload("res://scripts/core/debug_water.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func settle(data: RefCounted) -> void:
	var count: int=0
	while not data.water.pending.is_empty() and count<100000:
		count+=data.water.process_pending(512)
	expect(data.water.pending.is_empty(),"Water simulation settles")
func run() -> void:
	var data=Data.new(42)
	for x in range(-7,8):
		for z in range(-7,8):
			data.set_block(Vector3i(x,34,z),"stone")
	var revisions: Dictionary=data.revisions.duplicate()
	expect(data.water.source(Vector3i(0,35,0)),"Place source")
	settle(data)
	for x in range(1,4):
		expect(data.kind_at(Vector3i(x,35,0))=="water_flow_%d"%(4-x),"Horizontal falloff")
	expect(data.kind_at(Vector3i(4,35,0))=="air","Four metre limit")
	expect(revisions==data.revisions,"Water does not remesh solid terrain")
	expect(data.water.contains(Vector3(1.5,35.5,0.5)),"Partial water volume")
	expect(not data.water.contains(Vector3(1.5,35.9,0.5)),"Air above shallow flow")
	data.water.take(Vector3i(0,35,0))
	settle(data)
	expect(data.water.chunks.is_empty(),"Flows drain after source removed")
	data.set_block(Vector3i(0,34,0),"air")
	data.set_block(Vector3i(0,30,0),"stone")
	data.water.source(Vector3i(0,35,0))
	data.water.process_pending(8)
	var restored=Data.new(42)
	restored.block(Vector3i(0,35,0))
	restored.import_state(data.export_state())
	settle(data)
	settle(restored)
	expect(data.edits==restored.edits,"Save/load resumes pending flow")
	expect(data.kind_at(Vector3i(0,31,0)).begins_with("water_fall"),"Water falls to ground")
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.new_world(42,"debug")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	expect(world.model.landmarks.debug_water.pits.size()==1,"One debug pool")
	expect(world.inventory.count_item("bucket")==1,"Debug has empty bucket")
	expect(world.inventory.count_item("water_bucket")==1,"Debug has water bucket")
	world.player.velocity.y= -10
	world.player.swim_vertical(1,false)
	expect(is_equal_approx(world.player.velocity.y,-0.45),"Slow sinking")
	world.player.swim_vertical(1,true)
	expect(is_equal_approx(world.player.velocity.y,2.2),"Swim up")
	for y in range(31,38):
		world.model.set_block(Vector3i(5,y,5),"water_source")
	world.player.position=Vector3(5.5,33.5,5.5)
	world.player.velocity=Vector3.ZERO
	world.player.set_physics_process(true)
	for i in range(60):
		await physics_frame
	world.player.set_physics_process(false)
	expect(world.player.in_water and world.player.position.y<33.5 and world.player.position.y>32.5,"Actual player sinks slowly in water")
	var sunk: float=world.player.position.y
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_SPACE
	key.pressed=true
	Input.parse_input_event(key)
	world.player.set_physics_process(true)
	for i in range(60):
		await physics_frame
	world.player.set_physics_process(false)
	key.pressed=false
	Input.parse_input_event(key)
	expect(world.player.position.y>sunk+1,"Holding Space swims upward")
	world.player.position=Vector3(5.5,33.5,5.5)
	world.update_daylight(0)
	expect(is_equal_approx(world.sky_environment.fog_density,0.18),"Underwater visibility limited")
	var pool: Vector3i=world.model.landmarks.debug_water.pits[0]
	world.player.position=Vector3(pool)+Vector3(0.5,1,0.5)
	world.player.camera.rotation=Vector3(-PI/2,0,0)
	world.selected_hotbar=0
	world.inventory.slots[27]=Registry.stack("bucket",1)
	for i in range(15):
		await physics_frame
	expect(world.use_bucket(),"Bucket scoops aimed source")
	expect(world.selected_kind()=="water_bucket","Bucket fills")
	expect(world.model.kind_at(pool+Vector3i.DOWN)=="air","Source removed from pool")
	# Place the filled bucket in a separate empty space (the pool now has several layers).
	world.model.set_block(Vector3i(6,34,6),"stone")
	world.streamer.build_now(Vector3i(0,2,0))
	world.player.position=Vector3(6.5,36,6.5)
	world.player.camera.rotation=Vector3(-PI/2,0,0)
	for frame in range(3):
		await physics_frame
	expect(world.use_bucket(),"Bucket places water")
	expect(world.selected_kind()=="bucket","Bucket empties")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position=Vector3(pool)+Vector3(-10,24,10)
		world.streamer.warm_start(Vector3(pool)+Vector3(-10,0,0))
		world.player.camera.look_at(Vector3(pool)+Vector3(-10,-1,0))
		world.daylight_amount=1
		world.update_daylight(0)
		for i in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://water-pools-preview.png")
		var wall: Vector3i=world.model.landmarks.debug_water.waterfall
		world.player.position=Vector3(wall)+Vector3(5,0,9)
		world.player.camera.look_at(Vector3(wall)+Vector3(0,-1,1))
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var before: Image=root.get_texture().get_image()
		before.save_png("res://waterfall-preview.png")
		var water_view=world.entity_system.get_node("WaterSurface")
		var key_chunk: Vector3i=world.model.key(wall)
		var original_mesh: Mesh=water_view.nodes[key_chunk].mesh
		await create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		var after: Image=root.get_texture().get_image()
		var patch:=Rect2i(before.get_size()/2-Vector2i(16,16),Vector2i(32,32))
		expect(before.get_region(patch).get_data()!=after.get_region(patch).get_data(),"Waterfall visibly animates between frames")
		expect(water_view.nodes[key_chunk].mesh==original_mesh,"Animation does not rebuild water geometry")
	var table=load("res://scripts/crafting.gd").new(3)
	for index in [0,2,4]:
		table.slots[index]=Registry.stack("planks",1)
	expect(table.recipe().get("kind","")=="bucket","V-shaped wooden bucket recipe")
	var source: Vector3i=world.model.landmarks.debug_water.waterfall
	expect(world.model.kind_at(source)=="water_source","Wall contains source")
	expect(world.model.kind_at(source+Vector3i(-3,-1,0)).begins_with("water_fall"),"Wall stream falls down")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("WATER TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
