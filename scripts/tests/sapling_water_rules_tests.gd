extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Saplings=preload("res://scripts/core/saplings.gd")
const Registry=preload("res://scripts/core/registry.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var data=Data.new(42)
	for axis in [Vector3i.RIGHT,Vector3i.BACK]:
		var center:=Vector3i(10,35,10)
		for i in range(-1,2):
			data.set_block(center+axis*i+Vector3i.DOWN,"stone")
			data.set_block(center+axis*i,"air")
		data.water.source(center-axis)
		data.water.source(center+axis)
		data.water.process_pending(2000)
		expect(data.kind_at(center)=="water_source","Opposite sources refill middle in either axis")
		data.water.take(center)
		data.water.process_pending(2000)
		expect(data.kind_at(center)=="water_source","Refilled source can replenish after scooping")
		for i in range(-1,2):
			data.set_block(center+axis*i,"air")
	var gap:=Vector3i(30,35,30)
	data.water.source(gap-Vector3i.RIGHT)
	data.water.source(gap+Vector3i.RIGHT)
	expect(data.water.desired(gap)!="water_source","No new source floating in midair")
	data.set_block(gap,"stone")
	expect(data.water.desired(gap)=="stone","Water does not replace solid middle")
	var drops: Dictionary={"sapling":0,"stick":0,"foliage":0}
	for i in range(20000):
		drops[Saplings.foliage_drop()]+=1
	expect(drops.sapling>3600 and drops.sapling<4400 and drops.stick>4500 and drops.foliage>10000,"About one in five leaves drops a sapling, with sticks and foliage remaining")
	for mode in ["debug","play"]:
		var model=Data.new(43)
		var cell:=Vector3i(4,35,4)
		model.set_block(cell+Vector3i.DOWN,"dirt")
		var id: String=Saplings.plant(model,cell,mode)
		expect(not id.is_empty(),"Plant on dirt")
		var record: Dictionary=model.entities[id]
		var min_time: int=120 if mode=="debug" else 300
		var max_time: int=180 if mode=="debug" else 600
		expect(record.grow_at>=min_time and record.grow_at<=max_time,"Correct growth duration for mode")
		expect(record.height>=3 and record.height<=6,"Random tree height")
		var restored=Data.new()
		expect(restored.import_state(model.export_state()),"Save/load planted tree")
		expect(restored.entities[id].grow_at==record.grow_at,"Growth deadline persists")
		restored.game_time=record.grow_at-1
		Saplings.tick(restored)
		expect(restored.kind_at(cell)=="sapling","No premature growth")
		# An obstruction delays growth instead of destroying a building.
		restored.set_block(cell+Vector3i.UP,"stone")
		restored.game_time=record.grow_at
		Saplings.tick(restored)
		expect(restored.kind_at(cell)=="sapling","Obstruction prevents destructive growth")
		restored.set_block(cell+Vector3i.UP,"air")
		Saplings.tick(restored)
		expect(not restored.entities.has(id) and restored.kind_at(cell)=="wood","Mature tree replaces sapling directly")
		expect(restored.kind_at(cell+Vector3i.UP*int(record.height))=="foliage","Tree has canopy")
		restored.set_block(cell,"air")
		expect(restored.decay.size()>0,"Planted tree leaves decay after trunk removal")
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	var cell:=Vector3i(3,35,3)
	for x in range(0,9):
		for z in range(0,10):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	world.streamer.build_now(Vector3i(0,2,0))
	world.player.position=Vector3(3.5,35,6)
	world.player.camera.look_at(Vector3(cell)+Vector3(0.5,-0.1,0.5))
	world.selected_hotbar=0
	world.inventory.slots[27]=Registry.stack("sapling",2)
	world.game_mode="debug"
	for i in range(3):
		await physics_frame
	expect(world.try_farm_action(),"Right-click planting routes through actual ground selection")
	var id: String=Saplings.id_for(world.model,cell)
	expect(world.entity_system.active.has(id),"Planted sapling renders as a streamed entity")
	expect(world.inventory.slots[27].count==1,"Planting consumes one sapling")
	expect(not world.item_icons.get("sapling")==null,"Inventory has sapling icon")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position=Vector3(5,35,6)
		world.player.camera.look_at(Vector3(cell)+Vector3(0.5,0.32,0.5))
		world.update_counter()
		world.daylight_amount=1
		world.update_daylight(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://sapling-preview.png")
	world.model.game_time=world.model.entities[id].grow_at
	world.model.advance(1)
	world.entity_system.elapsed=1
	world.entity_system.tick(world.player.position,1)
	expect(not world.entity_system.active.has(id),"Plant visual is removed after tree grows")
	expect(world.model.kind_at(cell)=="wood","World clock grows planted tree")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.streamer.build_now(Vector3i(0,2,0))
		world.player.position=Vector3(8,35,10)
		world.player.camera.look_at(Vector3(cell)+Vector3(0.5,2,0.5))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://sapling-grown-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("SAPLING / WATER RULE TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
