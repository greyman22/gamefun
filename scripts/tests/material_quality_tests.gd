extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Atlas = preload("res://scripts/rendering/atlas.gd")
const Surfaces = preload("res://scripts/rendering/surface_textures.gd")
const Cycle = preload("res://scripts/core/day_cycle.gd")
const Doors = preload("res://scripts/core/doors.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	for kind: String in ["stone","dirt","wood","planks","workbench","chest","soul_block","foliage","bedrock"]:
		for face in range(3):
			expect(Surfaces.tile(kind,face).get_size()==Vector2i(256,256),"All appropriate block surfaces have actual 256px artwork")
		var mat := Surfaces.material(kind)
		expect(mat.normal_enabled and mat.normal_texture!=null and mat.roughness_texture!=null,"Shared materials have normal and roughness maps")
	var atlas := Atlas.material()
	expect(atlas==Atlas.material(),"Atlas cached across world changes")
	var texture: Texture2D = atlas.get_shader_parameter("atlas_texture")
	expect(texture.get_width()>2000 and texture.get_height()>1000,"HD atlas contains full-resolution surfaces")
	var bytes: int = texture.get_width()*texture.get_height()*4*2
	print("HD atlas base colour+detail bytes: ",bytes,"; dimensions: ",texture.get_size())
	var world = load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	for x in range(0,12):
		for z in range(0,10):
			world.model.set_block(Vector3i(x,34,z),"stone")
	var kinds: Array[String] = ["stone","dirt","wood","planks","workbench","soul_block","foliage","chest","chest"]
	for index in range(kinds.size()):
		world.model.set_block(Vector3i(index+1,35,2),kinds[index])
	world.model.set_block(Vector3i(1,35,4),"bedrock")
	Doors.place(world.model,Vector3i(4,35,4),0)
	world.entity_system.tick(Vector3(5,35,4),1)
	world.streamer.build_now(Vector3i(0,2,0))
	world.player.position=Vector3(5.5,35.5,9)
	await process_frame
	world.player.camera.look_at(Vector3(5.5,35.7,2.5))
	Cycle.state(world.model).minute=720
	world.update_daylight(1)
	world.day_hud.refresh(0)
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://materials-hd-preview.png")
		world.player.position=Vector3(2.5,35,5)
		await process_frame
		world.player.camera.look_at(Vector3(2,35.6,2.5))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://materials-hd-close-preview.png")
		var cell := Vector3i(3,35,3)
		world.model.set_block(cell,"torch")
		world.model.entities.texture_torch={"type":"torch","kind":"torch","cell":cell,"position":Vector3(cell),"normal":Vector3.UP,"state":{}}
		world.entity_system.activate("texture_torch",world.model.entities.texture_torch)
		Cycle.state(world.model).minute=1380
		world.update_daylight(1)
		world.day_hud.refresh(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://materials-hd-night-preview.png")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved),"HD surfaces do not change world save format")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("MATERIAL QUALITY TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
