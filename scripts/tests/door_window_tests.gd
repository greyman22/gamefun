extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Daylight=preload("res://scripts/core/daylight.gd")
const Doors=preload("res://scripts/core/doors.gd")
const Registry=preload("res://scripts/core/registry.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func room(data: RefCounted) -> void:
	for x in range(0,7):
		for z in range(0,8):
			data.set_block(Vector3i(x,34,z),"stone")
			data.set_block(Vector3i(x,38,z),"stone")
			for y in range(35,38):
				data.set_block(Vector3i(x,y,z),"stone" if x in [0,6] or z in [0,7] else "air")
	data.set_block(Vector3i(3,35,7),"air")
	data.set_block(Vector3i(3,36,7),"air")
	Doors.place(data,Vector3i(3,35,7),0)
func run() -> void:
	Registry.initialize()
	var data:=Data.new()
	room(data)
	var light:=Daylight.new()
	light.configure(data)
	var inside:=Vector3(3.3,36.7,6.2)
	var window_light: float=light.exposure(inside)
	expect(window_light>0.1,"Closed door window admits daylight into sealed stone room")
	expect(Registry.cube(data.block(Vector3i(3,36,7))),"Window remains impassable to bodies and navigation")
	data.set_block(Vector3i(3,36,7),"planks")
	expect(light.exposure(inside)==0,"Opaque upper panel still blocks light")
	data.set_block(Vector3i(3,36,7),"door_top")
	expect(is_equal_approx(light.exposure(inside),window_light),"Window/light caches refresh after changing door")
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	room(world.model)
	var cell:=Vector3i(3,35,7)
	var id: String=Doors.entity_id(world.model,cell)
	world.entity_system.activate(id,world.model.entities[id])
	var door=world.entity_system.active[id]
	for point in [Vector2(0.22,1.75),Vector2(0.63,1.75),Vector2(0.22,1.26),Vector2(0.63,1.26)]:
		var clear: bool=true
		for part in door.hinge.find_children("*","MeshInstance3D",true,false):
			var start: Vector3=part.to_local(door.hinge.to_global(Vector3(point.x,point.y,-1)))
			var finish: Vector3=part.to_local(door.hinge.to_global(Vector3(point.x,point.y,1)))
			if part.mesh.get_aabb().intersects_segment(start,finish)!=null:
				clear=false
		expect(clear,"All four window panes have a genuine unobstructed visual opening")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.position=Vector3(3.3,35,6.1)
		world.streamer.warm_start(world.player.position)
		await process_frame
		world.player.camera.look_at(Vector3(3.3,36.65,9))
		var marker:=MeshInstance3D.new()
		var box:=BoxMesh.new()
		box.size=Vector3(0.35,0.45,0.1)
		marker.mesh=box
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color("42c8da")
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override=material
		marker.position=Vector3(3.3,36.65,9)
		world.add_child(marker)
		world.daylight_amount=window_light
		world.update_daylight(0)
		world.day_hud.refresh(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://door-window-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("DOOR WINDOW TESTS: ","PASS" if failures==0 else failures," exposure=",window_light)
	quit(0 if failures==0 else 1)
