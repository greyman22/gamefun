extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Boats=preload("res://scripts/core/boats.gd")
const Vitals=preload("res://scripts/core/vitals.gd")
const Hens=preload("res://scripts/core/hens.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Registry=preload("res://scripts/core/registry.gd")
const DeathDrops=preload("res://scripts/core/death_drops.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var v=Vitals.new()
	v.breathe(1,true)
	expect(v.air==9 and v.health==100,"One half-bubble used per second")
	v.breathe(8.9,true)
	expect(v.health>0,"Alive before ten seconds")
	v.breathe(0.11,true)
	expect(v.health==0,"Drowns at ten seconds")
	v.reset()
	v.breathe(9,true)
	v.breathe(1.5,false)
	expect(is_equal_approx(v.air,6),"Air refills proportionally over three seconds")
	v.breathe(1.5,false)
	expect(v.air==10,"Air fully restored after three seconds")
	v.breathe(3,true)
	var restored=Vitals.new()
	restored.restore(v.snapshot())
	expect(restored.air==v.air,"Air survives save/load")
	var data=Data.new(42)
	Hens.ensure_nearby(data,Vector3(100,-2,80),"debug")
	for record in data.entities.values():
		if record.type=="hen":
			expect(Hens.dry_land(data,Vector3i(record.position.floor())),"Natural hens spawn only on dry land")
	# A water strip across otherwise level ground forces a following bird to swim.
	var model=Data.new(43)
	for x in range(0,17):
		for z in range(0,9):
			model.set_block(Vector3i(x,34,z),"dirt")
			if x>=6 and x<=10:
				model.set_block(Vector3i(x,30,z),"stone")
				for y in range(31,35):
					model.set_block(Vector3i(x,y,z),"water_source")
	var system=System.new()
	system.configure(model,"debug")
	root.add_child(system)
	Hens.create(model,"swimmer",Vector3(3.5,35,4.5),Vector3(3.5,35,4.5),"debug",false)
	system.activate("swimmer",model.entities.swimmer)
	var bird=system.active.swimmer
	var water_frames: int=0
	for frame in range(1200):
		bird.simulate(1.0/60,Vector3(13.5,35,4.5))
		if bird.swimming:
			water_frames+=1
			expect(bird.position.y>=34.95,"Swimming bird floats at surface")
	expect(water_frames>180 and bird.position.x>11.5,"Following hen swims across water more slowly than walking")
	bird.position=Vector3(8.02,35,4.02)
	bird.step_time=1
	bird.route.clear()
	for frame in range(120):
		bird.simulate(1.0/60,Vector3(8.98,35,4.98))
	expect(bird.position.distance_to(Vector3(8.98,35,4.98))<1.25,"Swimming hen also completes short approaches in the same voxel")
	bird.position=Vector3(8.5,31,4.5)
	bird.step_time=1
	bird.simulate(0,null)
	expect(bird.position.y>=34.95,"Existing underwater hen floats instead of remaining on bottom")
	system.queue_free()
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
	var id: String=Boats.launch(world.entity_system,Vector3(100,-2,80),0)
	Boats.board(world,id)
	world.player.boat_look_yaw=0
	var boat=world.entity_system.active[id]
	var start: Vector3=boat.position
	Boats.move(world,0.5,Vector2(1,0))
	expect(boat.position==start and absf(boat.rotation.y)>0.5,"A/D turns without sideways translation")
	var yaw: float=boat.rotation.y
	var mouse:=InputEventMouseMotion.new()
	mouse.relative=Vector2(100000,0)
	world.player._unhandled_input(mouse)
	expect(boat.rotation.y==yaw and is_equal_approx(absf(world.player.boat_look_yaw),deg_to_rad(135)),"Mouse freely looks sideways with rear ninety-degree sector blocked")
	start=boat.position
	Boats.move(world,0.5,Vector2(0,-1))
	var travel: Vector3=(boat.position-start).normalized()
	expect(travel.dot(-boat.global_basis.z)>0.999,"Forward follows hull rather than head direction")
	var exit_key:=InputEventKey.new()
	exit_key.pressed=true
	exit_key.physical_keycode=KEY_SPACE
	world._unhandled_input(exit_key)
	expect(world.mounted_boat==id,"Space no longer dismounts boat")
	exit_key.physical_keycode=KEY_SHIFT
	world._unhandled_input(exit_key)
	expect(world.mounted_boat.is_empty(),"Shift dismounts boat")
	Boats.leave(world)
	# Keep the death-drop test detached from the real respawn signal.
	world.inventory.slots[27]=Registry.stack("dirt",64)
	world.inventory.slots[28]=Registry.stack("wood",36)
	var count: int=DeathDrops.spill(world,Vector3(0.5,0,12.5))
	expect(count>=70 and count<=90,"Death salvages seventy to ninety percent of inventory")
	for record in world.model.entities.values():
		if record.type=="pickup":
			expect(Vector2(record.position.x-0.5,record.position.z-12.5).length()<=4.01,"Land death drops within four metres")
			expect(not world.model.water.contains(record.position),"Drops are on dry land")
	expect(DeathDrops.land_points(world.model,Vector3(100,-10,80),10).is_empty(),"Deep open lake has no dry recovery positions")
	# A small dry island seven metres away is usable only by the water-death radius.
	for x in range(107,110):
		for z in range(79,82):
			world.model.set_block(Vector3i(x,-2,z),"stone")
	var before: Dictionary=world.model.entities.duplicate()
	count=DeathDrops.spill(world,Vector3(100,-8,80))
	expect(count>=70 and count<=90,"Water death recovers inventory on shore within ten metres")
	for key in world.model.entities:
		if not before.has(key) and world.model.entities[key].type=="pickup":
			var point: Vector3=world.model.entities[key].position
			expect(Vector2(point.x-100,point.z-80).length()>4 and Vector2(point.x-100,point.z-80).length()<=10,"Water drops use nearby land beyond the normal radius")
	for mode in ["debug","play"]:
		world.game_mode=mode
		world.player.position=Vector3(0.5,0,12.5)
		world.player.vitals.reset()
		before=world.model.entities.duplicate()
		world.player.vitals.damage(100)
		expect(world.inventory.slots.all(func(slot: Dictionary) -> bool: return slot.count==0),"Death clears all carried inventory in either mode")
		expect(world.player.vitals.health==100 and world.player.vitals.air==10,"Respawn restores health and lungs")
		if mode=="debug":
			world.inventory.slots[27]=Registry.stack("dirt",64)
			world.inventory.slots[28]=Registry.stack("wood",36)
	world.new_world(42,"debug")
	world.inventory.slots[27]=Registry.stack("dirt",64)
	world.inventory.slots[28]=Registry.stack("wood",36)
	world.player.position=Vector3(100,-8,80)
	before=world.model.entities.duplicate()
	world.player.vitals.damage(100)
	expect(world.inventory.slots.all(func(slot: Dictionary) -> bool: return slot.count==0),"Open-water death loses carried items")
	var new_drops: int=0
	for key in world.model.entities:
		if not before.has(key) and world.model.entities[key].type=="pickup":
			new_drops+=1
	expect(new_drops==0,"No items are dropped when no dry land is within ten metres")
	world.new_world(42,"debug")
	expect(world.model.landmarks.debug_water.pits.size()==1,"Debug has only one pool")
	var outlet: Vector3i=world.model.landmarks.debug_water.waterfall
	expect(Vector2(outlet.x,outlet.z-12).length()>15,"Rock outlet stays away from spawn")
	world.daylight_amount=1
	world.update_daylight(0)
	var torch:=Node3D.new()
	world.add_child(torch)
	torch.position=Vector3(2.5,35,4.5)
	load("res://scripts/item_visuals.gd").torch_model(torch)
	var light: OmniLight3D=torch.find_children("*","OmniLight3D",true,false)[0]
	var cycle=load("res://scripts/core/day_cycle.gd")
	cycle.state(world.model).minute=720
	world.update_torch_lighting()
	var day_light: float=light.light_energy
	cycle.state(world.model).minute=0
	world.update_torch_lighting()
	expect(day_light<0.03 and light.light_energy>0.3,"Torch glow is washed out by daylight but visible at night")
	if "--capture-ui" in OS.get_cmdline_user_args():
		var pit: Vector3i=world.model.landmarks.debug_water.pits[0]
		world.player.position=Vector3(pit)+Vector3(0.5,-3,0.5)
		world.player.camera.rotation=Vector3(-0.1,0,0)
		world.player.vitals.breathe(4,true)
		world.streamer.warm_start(world.player.position)
		world.daylight_amount=1
		world.update_daylight(0)
		world.update_counter()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://air-bubbles-preview.png")
		world.player.position=Vector3(outlet)+Vector3(-8,1,2)
		world.player.camera.look_at(Vector3(outlet))
		world.player.vitals.reset()
		world.streamer.warm_start(world.player.position)
		cycle.state(world.model).minute=720
		world.update_daylight(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://rock-outlet-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("WATER SURVIVAL / CONTROLS TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
