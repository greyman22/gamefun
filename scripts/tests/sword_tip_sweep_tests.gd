extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.player.paused = false
	var frames: Array[Image] = []
	for tool in ["stone_sword","axe","pickaxe","shovel"]:
		world.inventory.slots[27] = Registry.stack(tool,1)
		world.select_hotbar(0)
		world.update_held_item()
		world.apply_tool_action(0)
		var rest_tip: Vector3 = world.player.camera.to_local(world.held_item.to_global(world.held_tip_local()))
		var shoulder: Vector3 = world.arm_shoulder_position
		expect(not world.held_arm_fore.visible and not world.held_arm_upper.visible,"Arm hidden in folded resting pose: "+tool)
		for phase in [0.0,0.25,0.5,1.0]:
			world.apply_tool_action(phase)
			expect(shoulder.distance_to(world.arm_shoulder_position)<0.00001,"Shoulder stays fixed: "+tool)
			if phase == 0.5:
				var tip: Vector3 = world.held_item.to_global(world.held_tip_local())
				var screen: Vector2 = world.player.camera.unproject_position(tip)/root.get_visible_rect().size
				expect(screen.distance_to(Vector2(0.5,0.5))<0.01,"Tool tip reaches crosshair: "+tool)
				expect(world.player.camera.to_local(tip).z<rest_tip.z-0.2,"Tool extends into scene depth: "+tool)
				expect(world.held_arm_fore.visible,"Forearm visible at extension: "+tool)
			if tool == "stone_sword" and "--capture-ui" in OS.get_cmdline_user_args():
				await process_frame
				await RenderingServer.frame_post_draw
				frames.append(root.get_texture().get_image())
		for phase in [0.2,0.7]:
			world.apply_tool_action(phase)
			var expected: Transform3D = world.held_item.transform
			for material in ["dirt","stone","wood"]:
				world.target_cell = Vector3i(7,35,7)
				world.model.set_block(world.target_cell,material)
				world.swing_phase = phase*TAU
				world.swing_blend = 1
				world.update_hand_animation(0,true)
				expect(world.held_item.transform.is_equal_approx(expected),"Shared target-independent work pose: "+tool)
			world.attack_animation = 0.3*(1-phase)
			world._process(0)
			expect(world.held_item.transform.is_equal_approx(expected),"Shared combat pose: "+tool)
	if not frames.is_empty():
		var strip := Image.create(frames[0].get_width()*4,frames[0].get_height(),false,Image.FORMAT_RGBA8)
		for i in range(4):
			strip.blit_rect(frames[i],Rect2i(Vector2i.ZERO,frames[i].get_size()),Vector2i(i*frames[i].get_width(),0))
		strip.save_png("res://sword-tip-sweep-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("ARTICULATED TOOL SWEEP TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
