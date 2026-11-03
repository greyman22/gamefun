extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Generator=preload("res://scripts/core/generator.gd")
const Job=preload("res://scripts/rendering/chunk_job.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var g=Generator.new(42)
	for kind in range(3):
		var bounds: Rect2i=g.zones.nearest_rect(Vector2.ZERO,kind)
		expect(bounds.size.x>=1000 and bounds.size.x<=2000 and bounds.size.y>=1000 and bounds.size.y<=2000,"Zone dimensions are one to two kilometres on each axis")
		var center: Vector2i=bounds.get_center()
		var low: int=1000
		var high: int= -1000
		var rocks: int=0
		for x in range(center.x-300,center.x+301,40):
			for z in range(center.y-300,center.y+301,40):
				var h: int=g.height(x,z)
				low=mini(low,h)
				high=maxi(high,h)
				if g.rock_surface(x,z):
					rocks+=1
		if kind==0:
			expect(low>= -10 and high<=10,"Grassland terrain stays within ten metres up or down")
		elif kind==1:
			expect(high>12 and high<35 and high-low>20 and rocks>0,"Hilly regions have deeper relief and occasional stone")
		else:
			expect(high>35 and high<110 and rocks>50,"Mountain regions have high peaks and exposed rock")
	var boundary: Rect2i=g.zones.rect(0,0)
	var x: int=boundary.end.x
	var z: int=boundary.get_center().y
	expect(absf(g.zones.profile(x-1,z).height-g.zones.profile(x+1,z).height)<8,"Zone transitions blend instead of forming a border wall")
	var mountain: Rect2i=g.zones.nearest_rect(Vector2.ZERO,2)
	var tile:=Vector2i(floori(float(mountain.get_center().x)/64),floori(float(mountain.get_center().y)/64))
	var cave: Dictionary={}
	for dx in range(-10,11):
		for dz in range(-10,11):
			cave=g.cave_for_tile(tile.x+dx,tile.y+dz)
			if not cave.is_empty():
				break
		if not cave.is_empty():
			break
	expect(not cave.is_empty(),"Mountain regions contain surface caves")
	if not cave.is_empty():
		expect(cave.width>=2 and cave.width<=6 and cave.height>=2 and cave.height<=4 and cave.half_length<=19,"Caves have bounded dimensions and depth")
		for p in cave.path:
			for y in range(int(cave.floor),int(cave.floor)+int(cave.height)):
				expect(g.ground(Vector3i(p.x,y,p.y))==0,"Curved cave passage remains continuous")
		for end in [0,cave.path.size()-1]:
			var p: Vector2i=cave.path[end]
			expect(g.height(p.x,p.y)<=int(cave.floor),"Both winding cave ends open outside")
		for branch in cave.branches:
			for p in branch:
				expect(g.ground(Vector3i(p.x,cave.floor+1,p.y))==0,"Blind branch connects to main cave")
		var p:=Vector3i(cave.center.x,cave.floor,cave.center.y)
		expect(g.ground(p+Vector3i.DOWN)==1,"Cave retains a walkable stone floor")
	var data=Data.new(42)
	var changed:=Vector3i(2500,130,2500)
	data.set_block(changed,"planks")
	var saved: Dictionary=data.export_state()
	var restored=Data.new()
	expect(restored.import_state(saved) and restored.kind_at(changed)=="planks","New distant high terrain supports saved edits")
	for version in [1,2,3]:
		var old=Data.new(42)
		old.generator=Generator.new(42,version)
		expect(restored.import_state(old.export_state()) and restored.generator.version==version,"Old generator version is preserved on load")
		expect(restored.generator.world_limit()==1024 and restored.generator.max_y()==63,"Old world bounds are preserved")
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
	for kind in range(3):
		var started: int=Time.get_ticks_msec()
		expect(world.debug_visit_terrain(kind),"F3 can visit each terrain zone")
		print("Terrain visit ",kind," milliseconds ",Time.get_ticks_msec()-started)
		expect(world.model.generator.zones.info(floori(world.player.position.x),floori(world.player.position.z)).kind==kind,"Debug destination belongs to chosen zone")
		if kind==2:
			expect(world.streamer.desired.has(world.model.key(Vector3i(world.player.position.floor()))),"Streaming includes the current mountain elevation")
		if "--capture-ui" in OS.get_cmdline_user_args():
			world.player.camera.rotation=Vector3(-0.25,-0.6,0)
			world.daylight_amount=1
			world.update_daylight(0)
			for frame in range(100):
				world.streamer.tick(world.player.position,0.05)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://terrain-zone-%d-preview.png"%kind)
	expect(world.debug_visit_terrain(2,true),"F3 can visit a mountain cave")
	expect(world.model.kind_at(Vector3i(world.player.position.floor()))=="air","Cave teleport is not inside rock")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.camera.rotation=Vector3(0,0,0)
		world.update_daylight(0.5)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://terrain-cave-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("TERRAIN ZONES TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
