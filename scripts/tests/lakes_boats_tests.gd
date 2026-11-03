extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Registry=preload("res://scripts/core/registry.gd")
const Boats=preload("res://scripts/core/boats.gd")
const Generator=preload("res://scripts/core/generator.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var data=Data.new(42)
	var wet: int=0
	var deepest: int=0
	for x in range(-180,361,4):
		for z in range(-120,361,4):
			var floor_y: int=data.generator.height(x,z)
			var depth: int=maxi(0,Generator.SEA_LEVEL-floor_y)
			deepest=maxi(deepest,depth)
			if depth>0:
				wet+=1
				expect(data.generator.ground(Vector3i(x,Generator.SEA_LEVEL-1,z))==21,"Low terrain is filled with generated water")
				expect(depth<=12,"Natural water is at most twelve metres deep")
	expect(wet>1500 and deepest>=8,"World has substantial lakes and deep water")
	expect(data.generator.height(0,12)>=Generator.SEA_LEVEL,"Spawn remains dry")
	var lake:=Vector3(100,Generator.SEA_LEVEL,80)
	expect(data.generator.height(100,80)<Generator.SEA_LEVEL-5,"Large lake around seeded centre")
	for cell in data.generator.trees_in_chunk(Vector3i(6,0,5)):
		expect(cell.base.y>=Generator.SEA_LEVEL,"No generated trees below water")
	expect(data.edits.is_empty() and data.water.pending.is_empty(),"Lakes need no block edits or active flow queue")
	var source:=Vector3i(100,Generator.SEA_LEVEL-1,80)
	data.water.take(source)
	data.water.process_pending(256)
	expect(data.kind_at(source)=="water_source","Scooping lake water restores its supported source")
	expect(data.water.pending.size()<512,"Natural lake changes remain local")
	var floor_cell:=Vector3i(100,data.generator.height(100,80)-1,80)
	expect(data.kind_at(floor_cell) in ["lakebed","stone"],"Lake floor has no grass")
	var old=Data.new(42)
	old.generator=Generator.new(42,2)
	var restored=Data.new()
	expect(restored.import_state(old.export_state()) and restored.generator.version==2,"Older worlds retain terrain")
	var craft=load("res://scripts/crafting.gd").new(3)
	for index in [0,2,3,4,5]:
		craft.slots[index]=Registry.stack("planks",1)
	expect(craft.recipe().get("kind","")=="boat","Five plank boat recipe")
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
	world.player.position=lake+Vector3(0,0,5)
	world.streamer.warm_start(lake)
	world.selected_hotbar=0
	world.inventory.slots[27]=Registry.stack("boat",1)
	world.player.rotation=Vector3.ZERO
	world.player.camera.look_at(lake+Vector3(0.5,-0.1,0.5))
	expect(world.launch_boat(),"Aim at natural water to launch selected boat")
	var id: String=""
	for key in world.model.entities:
		if world.model.entities[key].type=="boat":
			id=key
	expect(not id.is_empty(),"Launch boat in natural lake")
	expect(world.inventory.slots[27].count==0,"Launching consumes inventory boat")
	expect(Boats.launch(world.entity_system,Vector3(0,2,12),0).is_empty(),"Cannot launch on land")
	var boat_position: Vector3=world.entity_system.active[id].position
	world.player.position=boat_position+Vector3(0,0,3)
	world.player.camera.look_at(boat_position+Vector3.UP*0.2)
	for frame in range(3):
		await physics_frame
	expect(Boats.pick(world)==id,"Boat is selectable through the actual interaction ray")
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_RIGHT
	click.pressed=true
	world._unhandled_input(click)
	expect(world.mounted_boat==id,"Right-click boards boat")
	world.player.rotation=Vector3.ZERO
	var start: Vector3=world.player.riding_boat.position
	Boats.move(world,1.0,Vector2(0,-1))
	expect(absf(start.distance_to(world.player.riding_boat.position)-6)<0.002,"Boat travels at player sprint speed")
	expect(world.player.position.distance_to(world.player.riding_boat.position)<0.2,"Player follows boat")
	var saved: Dictionary=world.snapshot()
	expect(saved.player.boat==id,"Save records mounted boat")
	expect(world.restore_snapshot(saved) and world.mounted_boat==id and is_instance_valid(world.player.riding_boat),"Load resumes mounted boat")
	Boats.leave(world)
	expect(world.mounted_boat.is_empty() and world.player.riding_boat==null,"Leave boat")
	var obstacle: Vector3i=Vector3i(world.entity_system.active[id].position.floor())+Vector3i(0,0,-2)
	world.model.set_block(obstacle,"stone")
	world.model.set_block(obstacle+Vector3i.UP,"stone")
	Boats.board(world,id)
	start=world.player.riding_boat.position
	Boats.move(world,1,Vector2(0,-1))
	expect(start.distance_to(world.player.riding_boat.position)<2,"Boat cannot pass into solid obstacles")
	for i in range(3):
		Boats.hit(world,id)
	expect(not world.model.entities.has(id) and world.mounted_boat.is_empty(),"Three hits recover boat and dismount rider")
	var drop_id: String=""
	for key in world.model.entities:
		if world.model.entities[key].type=="pickup" and world.model.entities[key].kind=="boat":
			drop_id=key
	expect(not drop_id.is_empty(),"Recovered boat drops as item")
	if not drop_id.is_empty():
		var record: Dictionary=world.model.entities[drop_id]
		world.entity_system.activate(drop_id,record)
		start=record.position
		world.entity_system.simulate_drops(1)
		expect(record.position==start,"Boat item floats on water")
	if "--capture-ui" in OS.get_cmdline_user_args():
		var boat_id: String=Boats.launch(world.entity_system,lake+Vector3(4,0,0),0.5)
		world.player.position=Vector3(8,5,30)
		world.streamer.warm_start(world.player.position)
		world.player.camera.look_at(Vector3(70,-2,75))
		world.daylight_amount=1
		world.update_daylight(0)
		var view=world.entity_system.get_node("WaterSurface")
		for x in range(3,10):
			for z in range(2,8):
				view.build(Vector3i(x,-1,z))
		for i in range(180):
			world.streamer.tick(world.player.position,0.05)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://lakes-boats-preview.png")
		if not boat_id.is_empty():
			Boats.board(world,boat_id)
			world.player.rotation.y=0
			world.player.camera.rotation.x= -0.85
			Boats.move(world,0.1,Vector2(0,-1))
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://rowing-preview.png")
			var hull=world.entity_system.active[boat_id].visual
			expect(hull.get_node("Seat")!=null and hull.get_node("DryFloor").mesh.get_aabb().position.y>0.02,"Boat has one seat and a floor safely above waves")
			Boats.leave(world)
			var hens=load("res://scripts/core/hens.gd")
			for i in range(2):
				var point: Vector3=lake+Vector3(i*1.2,0,3)
				var bird_id: String="swim_preview_%d"%i
				hens.create(world.model,bird_id,point,point,"debug",i==1)
				world.entity_system.activate(bird_id,world.model.entities[bird_id])
				world.entity_system.active[bird_id].simulate(0.3,lake+Vector3(0,0,7))
			world.player.position=lake+Vector3(4,1,7)
			world.player.camera.look_at(lake+Vector3(0.5,0.1,3))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://swimming-birds-preview.png")
	if "--capture-ui" in OS.get_cmdline_user_args():
		var map:=Image.create(256,256,false,Image.FORMAT_RGB8)
		for x in range(256):
			for z in range(256):
				var h: int=data.generator.height(x*4-256,z*4-256)
				map.set_pixel(x,z,Color(0.10,0.28+float(h+14)/40,0.52) if h<Generator.SEA_LEVEL else Color(0.22,0.42+float(h)/70,0.15))
		map.save_png("res://lakes-map-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("LAKES / BOATS TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
