extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Hens = preload("res://scripts/core/hens.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	var cell := Vector3i(3,35,3)
	world.model.set_block(cell+Vector3i.DOWN,"dirt")
	world.player.position = Vector3(6,35,7)
	world.inventory.slots[27]=Registry.stack("chest",2)
	world.select_hotbar(0)
	expect(world.valid_build_cell(cell),"Empty chest site allowed")
	Hens.create(world.model,"occupant",Vector3(cell)+Vector3(0.5,0,0.5),Vector3(cell),"debug")
	expect(not world.valid_build_cell(cell),"Inactive saved hen blocks placement")
	world.model.set_block(cell+Vector3i.LEFT,"chest")
	expect(not world.valid_build_cell(cell),"Second half of double chest cannot trap hen")
	world.entity_system.activate("occupant",world.model.entities.occupant)
	world.model.entities.occupant.position = Vector3(100,35,100)
	expect(not world.valid_build_cell(cell),"Placement uses live actor position, not stale save")
	world.entity_system.active.occupant.position = Vector3(2.8,35,3.5)
	expect(not world.valid_build_cell(cell),"Body crossing cell boundary blocks placement")
	world.entity_system.deactivate("occupant")
	world.model.entities.erase("occupant")
	Hens.create(world.model,"chick",Vector3(3.5,35,3.5),Vector3(cell),"debug",true)
	expect(not world.valid_build_cell(cell),"Chicks also block chest placement")
	world.model.entities.erase("chick")
	world.model.entities.monster = {"type":"zombie","position":Vector3(3.5,35,3.5),"state":{}}
	expect(not world.valid_build_cell(cell),"Other creatures block placement")
	world.model.entities.monster.state.dead = true
	expect(world.valid_build_cell(cell),"Dead actors do not occupy space")
	world.model.entities.erase("monster")
	world.inventory.slots[27]=Registry.stack("door",1)
	Hens.create(world.model,"upper",Vector3(3.5,36,3.5),Vector3(cell),"debug",true)
	expect(not world.valid_build_cell(cell),"Door checks both blocks for creatures")
	world.model.entities.erase("upper")
	world.inventory.slots[27]=Registry.stack("stone_sword",1)
	world.select_hotbar(0)
	world.attack_animation=0.3
	var xs: Array[float] = []
	for progress in [0.08,0.5,0.92]:
		world.attack_animation=0.3*(1-progress)+0.000001
		world._process(0)
		xs.append(world.player.camera.unproject_position(world.held_item.to_global(world.held_tip_local())).x)
	expect(xs[0]>xs[1] and xs[2]>xs[1],"Attack sweeps right-left-right")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.inventory.slots[27]=Registry.stack("planks",12)
		world.inventory.slots[28]=Registry.stack("shovel",1)
		world.update_counter()
		world.toggle_inventory()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://plank-block-icon-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("PLACEMENT AND SWEEP TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
