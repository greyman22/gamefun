extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
const Sheep=preload("res://scripts/core/sheep.gd")
const Hens=preload("res://scripts/core/hens.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func pickups(world: Node,kind: String) -> Array:
	return world.model.entities.values().filter(func(r: Dictionary) -> bool: return r.type=="pickup" and r.kind==kind)
func run() -> void:
	Registry.initialize()
	var world=load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.new_world(42,"debug")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.set_process_unhandled_input(false)
	for i in range(27):
		expect(world.inventory.slots[i].count==0,"Debug backpack starts empty")
	expect(world.inventory.slots[27].kind=="stone_sword" and world.inventory.slots[35].kind=="torch","Quickbar defaults preserved")
	for x in range(-6,7):
		for z in range(-6,7):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	world.player.position=Vector3(0.5,35,3.5)
	world.player.camera.rotation=Vector3.ZERO
	world.toggle_inventory()
	world.toggle_debug_catalog()
	expect(world.debug_catalog and world.debug_catalog_grid.visible,"Debug catalog replaces recipe grid")
	world.take_debug_material("stone")
	expect(world.stack_cursor.held.kind=="stone" and world.stack_cursor.held.count==64,"Catalog supplies a full material stack")
	world.stack_cursor.touch(0)
	world.stack_cursor.finish()
	expect(world.inventory.slots[0].kind=="stone" and world.inventory.slots[0].count==64,"Catalog stack drags into inventory")
	world.take_debug_material("stone_shears")
	expect(world.stack_cursor.held.count==1 and Registry.remaining_uses(world.stack_cursor.held)==100,"Catalog tools have one item and full durability")
	world.stack_cursor.touch(1)
	world.stack_cursor.finish()
	world.stack_cursor.press(0,MOUSE_BUTTON_LEFT)
	expect(world.drop_selected_stack(false) and world.stack_cursor.held.count==63,"Q drops one held item")
	expect(world.drop_selected_stack(true) and world.stack_cursor.held.count==0,"Shift Q drops remaining held stack")
	var stone: Array=pickups(world,"stone")
	expect(stone.size()==2 and stone[0].count+stone[1].count==64,"Discarded counts are conserved")
	expect(world.player.position.distance_to(stone[0].position)>1.5,"Discarded items appear in front of player")
	world.stack_cursor.held=Registry.stack("wood",7)
	world.get_viewport().warp_mouse(Vector2(2,2))
	world.toggle_inventory()
	expect(not world.player.inventory_open and world.stack_cursor.held.count==0 and pickups(world,"wood").size()==1,"Closing outside drops cursor stack")
	world.inventory.slots[27]=Registry.stack("axe")
	world.inventory.slots[27].durability=17
	world.select_hotbar(0)
	expect(world.drop_selected_stack() and world.inventory.slots[27].count==0,"Q works on selected quickbar")
	var axes: Array=pickups(world,"axe")
	expect(axes.size()==1 and axes[0].item.durability==17,"Discard preserves tool durability")
	world.model.game_time+=2
	world.entity_system.collect(world.player.position,world.inventory)
	expect(pickups(world,"stone").size()==2,"Discarded items cannot be collected in the air")
	Hens.create(world.model,"wool_sheep",Vector3(0.5,35,2.5),Vector3(0.5,35,2.5),"debug",false,"sheep")
	world.entity_system.activate("wool_sheep",world.model.entities.wool_sheep)
	Sheep.shear(world.entity_system,"wool_sheep",world.player.position)
	var wool: Array=pickups(world,"wool")
	expect(wool.size()>=1 and wool.size()<=3,"Clipped fleece spawns physical wool items")
	for r: Dictionary in wool:
		r.position=world.player.position+Vector3(0,0.3,0)
		r.ready_at=0
	world.entity_system.elapsed=1
	world.entity_system.tick(world.player.position,1)
	world.entity_system.collect(world.player.position,world.inventory)
	expect(world.inventory.count_item("wool")==0,"Wool is not collected before landing")
	for r: Dictionary in wool:
		r.position=world.player.position+Vector3(0,0.126,0)
		r.state.grounded=true
	world.entity_system.collect(world.player.position,world.inventory)
	expect(world.inventory.count_item("wool")==0,"Standing still after clipping does not vacuum up fleece")
	world.player.position+=Vector3(0.2,0,0)
	for r: Dictionary in wool:
		r.position=world.player.position+Vector3(0,0.126,0)
	world.entity_system.collect(world.player.position,world.inventory)
	expect(world.inventory.count_item("wool")==wool.size(),"Approaching grounded wool collects it")
	# The same outside-close behavior must apply to storage dialogs.
	world.model.set_block(Vector3i(3,35,0),"chest")
	world.chest_ui.open(Vector3i(3,35,0))
	world.stack_cursor.held=Registry.stack("planks",6)
	world.get_viewport().warp_mouse(Vector2(2,2))
	expect(world.chest_ui.close() and pickups(world,"planks").size()==1,"Closing chest with outside-held stack drops it")
	world.inventory.slots[27]=Registry.stack("dirt",4)
	world.player.paused=false
	var q:=InputEventKey.new()
	q.physical_keycode=KEY_Q
	q.pressed=true
	world._input(q)
	expect(world.inventory.slots[27].count==3,"Q key is wired to dropping one quickbar item")
	q.shift_pressed=true
	world._input(q)
	expect(world.inventory.slots[27].count==0,"Shift Q key drops the remaining stack")
	world.game_mode="play"
	world.toggle_inventory()
	world.apply_recipe_filters()
	expect(not world.debug_catalog and not world.debug_catalog_button.visible,"Play mode has no free catalog")
	world.take_debug_material("stone")
	expect(world.stack_cursor.held.count==0,"Play mode cannot create free items")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.game_mode="debug"
		world.toggle_debug_catalog()
		world.apply_recipe_filters()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://debug-materials-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("DEBUG CATALOG AND DROPS TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
