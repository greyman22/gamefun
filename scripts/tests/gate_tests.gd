extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Doors = preload("res://scripts/core/doors.gd")
const Craft = preload("res://scripts/crafting.gd")
const Data = preload("res://scripts/core/world_data.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var craft := Craft.new(3)
	for i in [0,2,3,5]:
		craft.slots[i]=Registry.stack("stick",1)
	for i in [1,4]:
		craft.slots[i]=Registry.stack("planks",1)
	var bag = load("res://scripts/inventory.gd").new()
	expect(craft.craft(bag) and bag.count_item("gate")==1,"Four sticks and two planks craft gate")
	var world = load("res://scenes/main.tscn").instantiate()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_process_input(false)
	world.set_physics_process(false)
	world.set_process_unhandled_input(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	var cell := Vector3i(3,35,3)
	for x in range(0,8):
		for z in range(0,8):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	world.model.set_block(cell+Vector3i.UP,"stone")
	expect(Doors.can_place(world.model,cell,"gate"),"Gate needs only one clear cell")
	Doors.place(world.model,cell,0,"gate")
	var id: String = Doors.entity_id(world.model,cell)
	world.entity_system.activate(id,world.model.entities[id])
	var gate = world.entity_system.active[id]
	expect(gate.gate_hinges.size()==2 and gate.is_in_group("wooden_fences"),"Closed gate has two leaves and fence-entry rule")
	for leaf in gate.gate_hinges:
		for part in leaf.find_children("*","CollisionShape3D",true,false):
			expect(part.shape.size.y==1.0,"Gate collision must be exactly one metre high")
	world.player.position=Vector3(3.5,35,4.5)
	expect(Doors.toggle(world.entity_system,cell,world.player),"Gate opens from front")
	expect(world.model.kind_at(cell)=="gate_open" and not gate.is_in_group("wooden_fences"),"Open gate permits passage")
	var front_sign: float = world.model.entities[id].swing_sign
	expect(is_equal_approx(gate.gate_hinges[0].rotation.y,-gate.gate_hinges[1].rotation.y),"Leaves open symmetrically from centre")
	world.model.set_block(cell+Vector3i.UP,"air")
	world.player.position=Vector3(3.5,35,3.5)
	expect(Doors.toggle(world.entity_system,cell,world.player) and absf(world.player.position.z-3.5)>0.4,"Closing moves player out of leaf plane")
	world.player.position=Vector3(3.5,35,2.5)
	expect(Doors.toggle(world.entity_system,cell,world.player) and world.model.entities[id].swing_sign==-front_sign,"Gate opens the other way from rear")
	var imported := Data.new()
	expect(imported.import_state(world.model.export_state()) and imported.entities[id].open and imported.entities[id].kind=="gate","Gate open state survives save/load")
	Doors.toggle(world.entity_system,cell,world.player)
	await physics_frame
	await physics_frame
	var picked: Variant = Doors.pick(world.entity_system,Vector3(3.5,35.6,5),Vector3(3.5,35.6,2),[])
	expect(picked==cell,"Right-click ray selects one-metre gate")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position = Vector3(5.8,35,7)
		world.streamer.warm_start(world.player.position)
		await process_frame
		world.player.camera.look_at(Vector3(3.5,35.5,3.5))
		world.update_daylight(0)
		var frames: Array[Image] = []
		for opened in [false,true]:
			if bool(world.model.entities[id].open)!=opened:
				Doors.toggle(world.entity_system,cell,world.player)
			await process_frame
			await RenderingServer.frame_post_draw
			frames.append(root.get_texture().get_image())
		var strip := Image.create(frames[0].get_width()*2,frames[0].get_height(),false,Image.FORMAT_RGBA8)
		for index in range(2):
			strip.blit_rect(frames[index],Rect2i(Vector2i.ZERO,frames[index].get_size()),Vector2i(index*frames[index].get_width(),0))
		strip.save_png("res://gate-preview.png")
	world.model.set_block(cell+Vector3i.UP,"stone")
	world.model.set_block(cell+Vector3i.DOWN,"air")
	expect(not world.model.entities.has(id) and world.model.kind_at(cell)=="air","Unsupported gate removes entity and voxel")
	expect(world.model.kind_at(cell+Vector3i.UP)=="stone","Gate removal must not erase block above")
	var drops: int = 0
	for record in world.model.entities.values():
		if record.type=="pickup" and record.kind=="gate":
			drops += 1
	expect(drops==1,"Unsupported gate becomes one falling gate pickup")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("GATE TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
