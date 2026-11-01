extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Job = preload("res://scripts/rendering/chunk_job.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func side_color(data: RefCounted, cell: Vector3i) -> Color:
	var key: Vector3i = data.key(cell)
	var job := Job.new(data.seed_value, key, data.worker_edits(key))
	job.run()
	var vertices: PackedVector3Array = job.result.arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = job.result.arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = job.result.arrays[Mesh.ARRAY_COLOR]
	var target := Vector3(cell - key * 16) + Vector3(1, 0.5, 0.5)
	for index in range(0, vertices.size(), 4):
		var center := (vertices[index] + vertices[index+1] + vertices[index+2] + vertices[index+3]) / 4
		if normals[index] == Vector3.RIGHT and center.distance_to(target) < 0.01:
			return colors[index]
	return Color(-1, -1, -1)
func tile(color: Color) -> int:
	return roundi(color.r * 255) + roundi(color.g * 255) * 256
func run() -> void:
	Registry.initialize()
	var data := Data.new(123)
	var cell := Vector3i(3, 47, 3)
	data.set_block(cell, "dirt")
	var exposed := side_color(data, cell)
	expect(tile(exposed) == Registry.tile(Registry.id("dirt"), Vector3i.RIGHT) and exposed.b == 1, "Exposed dirt keeps grass and faint block grid")
	data.set_block(cell + Vector3i.UP, "torch")
	expect(tile(side_color(data,cell)) == tile(exposed),"Torch keeps soil grassy")
	data.set_block(cell + Vector3i.UP, "stone")
	var buried := side_color(data, cell)
	expect(tile(buried) == Registry.tile(Registry.id("dirt"), Vector3i.DOWN), "Covered dirt must have plain soil across chunk boundary")
	data.set_block(cell + Vector3i.UP, "air")
	expect(tile(side_color(data, cell)) == tile(exposed), "Removing cover restores surface grass")
	data.set_block(cell, "stone")
	expect(side_color(data, cell).b == 1, "Stone gets block outline")
	data.set_block(cell, "wood")
	expect(side_color(data, cell).b == 0, "Other materials keep original appearance")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var crosshair: Control = world.find_child("Crosshair", true, false)
	expect(crosshair != null and is_equal_approx(crosshair.get_global_rect().get_center().y, root.get_visible_rect().size.y * 0.5 + 7), "Reticle is below actual camera focus")
	if "--capture-ui" in OS.get_cmdline_user_args():
		for x in range(0, 8):
			for z in range(0, 8):
				world.model.set_block(Vector3i(x, 46, z), "dirt")
		for z in range(1, 5):
			world.model.set_block(Vector3i(3, 47, z), "dirt")
			world.model.set_block(Vector3i(3, 48, z), "stone")
		world.streamer.build_now(Vector3i(0, 2, 0))
		world.streamer.build_now(Vector3i(0, 3, 0))
		world.player.position = Vector3(6, 47, 7)
		world.player.camera.look_at(Vector3(3.5, 47.6, 3))
		await physics_frame
		world.update_build_preview()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://terrain-focus-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("TERRAIN FOCUS TESTS: ", "PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
