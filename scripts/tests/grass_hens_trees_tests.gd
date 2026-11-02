extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Generator=preload("res://scripts/core/generator.gd")
const Registry=preload("res://scripts/core/registry.gd")
const Saplings=preload("res://scripts/core/saplings.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var model=Data.new(42)
	var branch_trees: int=0
	var crowns: Dictionary={}
	for i in range(100):
		var short_tree: Dictionary=model.generator.make_tree(Vector3i(i*10,35,3),3)
		var tall: Dictionary=model.generator.make_tree(Vector3i(i*10,35,3),6)
		expect(short_tree.branches.is_empty(),"Short trees have compact crowns without branches")
		if not tall.branches.is_empty():
			branch_trees+=1
		crowns[tall.voxels.size()]=true
		expect(tall==model.generator.make_tree(tall.base,6),"Tree variation is deterministic for a seed")
		for branch in tall.branches:
			expect(model.generator.tree_kind(tall.base+branch,tall)==Registry.id("wood"),"Branches are editable log blocks")
	expect(branch_trees>30 and branch_trees<95 and crowns.size()>2,"Tall trees vary in crown and branching")
	var legacy=Data.new(42)
	legacy.generator=Generator.new(42,1)
	var state: Dictionary=legacy.export_state()
	var restored=Data.new()
	expect(restored.import_state(state) and restored.generator.version==1,"Old worlds keep original tree generation")
	expect(restored.chunk(Vector3i(2,0,2))==legacy.chunk(Vector3i(2,0,2)),"Legacy terrain survives save/load byte for byte")
	expect(restored.export_state().generator_version==1,"Re-saving legacy world preserves its version")
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
	for x in range(0,32):
		for z in range(0,21):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	world.player.position=Vector3(15,35,12)
	world.inventory.slots[27]=Registry.stack("grass_seed",5)
	world.selected_hotbar=0
	world._physics_process(0.01)
	expect(world.entity_system.seed_lure==world.player.position,"Selected grass seeds attract hens")
	world.inventory.slots[27]=Registry.stack("soul_remnant",5)
	world._physics_process(0.01)
	expect(world.entity_system.seed_lure==null,"Soul remnants no longer attract hens")
	var Hens=load("res://scripts/core/hens.gd")
	Hens.create(world.model,"speed_test",Vector3(3.5,35,12.5),Vector3(3.5,35,12.5),"debug",false)
	world.entity_system.activate("speed_test",world.model.entities.speed_test)
	var bird=world.entity_system.active.speed_test
	bird.step_from=bird.position
	bird.step_to=bird.position+Vector3.RIGHT
	bird.step_time=0
	bird.simulate(0.1,null)
	var walking: float=bird.step_time
	bird.step_time=0
	bird.simulate(0.1,Vector3(7.5,35,12.5))
	expect(bird.step_time>walking*1.8,"Attracted hen moves almost twice as quickly")
	if "--capture-ui" in OS.get_cmdline_user_args():
		for pair in [[Vector3i(4,35,3),3],[Vector3i(14,35,3),5],[Vector3i(24,35,3),6]]:
			var tree: Dictionary=world.model.generator.make_tree(pair[0],pair[1])
			for offset in tree.voxels:
				world.model.set_block(tree.base+offset,Registry.kind(tree.voxels[offset]))
		var sapling: String=Saplings.plant(world.model,Vector3i(11,35,11),"debug")
		world.entity_system.activate(sapling,world.model.entities[sapling])
		world.streamer.build_now(Vector3i(0,2,0))
		world.streamer.build_now(Vector3i(1,2,0))
		world.streamer.build_now(Vector3i(0,2,1))
		world.streamer.build_now(Vector3i(1,2,1))
		world.player.position=Vector3(15,39,25)
		world.player.camera.look_at(Vector3(15,37,5))
		world.daylight_amount=1
		world.update_daylight(0)
		world.update_counter()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://grass-trees-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("GRASS / HENS / TREES TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
