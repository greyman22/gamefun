extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
const Data=preload("res://scripts/core/world_data.gd")
const Furnace=preload("res://scripts/core/furnaces.gd")
const Craft=preload("res://scripts/crafting.gd")
const Inventory=preload("res://scripts/inventory.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func fresh(data: RefCounted, cell: Vector3i, fuel: String, count: int) -> Dictionary:
	Furnace.records(data).erase(cell)
	data.set_block(cell,"furnace")
	var value: Dictionary=Furnace.state(data,cell)
	value.slots[0]=Registry.stack("wood",10)
	value.slots[1]=Registry.stack(fuel,count)
	return value
func run() -> void:
	Registry.initialize()
	var table:=Craft.new(3)
	for i in [0,1,2,3,5,6,7,8]:
		table.slots[i]=Registry.stack("stone",1)
	var bag:=Inventory.new()
	expect(table.craft(bag) and bag.count_item("furnace")==1,"Eight stones around empty centre craft furnace")
	var data:=Data.new()
	var cell:=Vector3i(3,35,3)
	var value: Dictionary=fresh(data,cell,"wood",1)
	data.advance(12)
	expect(value.slots[2].count==4 and value.slots[0].count==6 and value.slots[1].count==0,"One twelve-second log fuel smelts four logs")
	expect(value.burn_left==0 and data.kind_at(cell)=="furnace","Fire goes out after fuel duration")
	value=fresh(data,cell,"foliage",6)
	data.advance(2.99)
	expect(value.slots[2].count==0,"Not finished before three seconds")
	data.advance(0.01)
	expect(value.slots[2].count==1 and value.slots[1].count==0,"Six short leaf fuels combine into one three-second smelt")
	value=fresh(data,cell,"foliage",1)
	data.advance(5)
	expect(value.slots[2].count==0 and value.slots[0].count==10 and value.burn_left==0,"Insufficient fuel stops without losing input")
	value.slots[1]=Registry.stack("stick",3)
	data.advance(2.5)
	expect(value.slots[2].count==1,"Adding fuel resumes partial progress")
	value=fresh(data,cell,"planks",2)
	value.slots[2]=Registry.stack("coal",64)
	data.advance(30)
	expect(value.slots[1].count==2 and value.slots[0].count==10,"Full output prevents fresh fuel consumption")
	value=fresh(data,cell,"planks",1)
	data.advance(1.5)
	var imported:=Data.new()
	expect(imported.import_state(data.export_state()),"Burning furnace saves")
	var restored: Dictionary=Furnace.state(imported,cell)
	expect(restored.burn_left==2.5 and restored.progress==1.5,"Fuel and progress survive load")
	imported.advance(1.5)
	expect(restored.slots[2].count==1,"Unloaded/saved furnace continues working")
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.player.paused=false
	world.player.movement_blocked=false
	world.model.set_block(cell,"furnace")
	world.inventory.slots[27]=Registry.stack("wood",4)
	world.inventory.slots[28]=Registry.stack("planks",2)
	world.inventory.slots[29]=Registry.stack("stone",1)
	world.inventory.slots[30]=Registry.stack("grass_seed",2)
	world.select_hotbar(3)
	world.player.position=Vector3(3.5,35,6)
	world.streamer.build_now(Vector3i(0,2,0))
	await process_frame
	world.player.camera.look_at(Vector3(3.5,35.5,3.5))
	await physics_frame
	await physics_frame
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_RIGHT
	click.pressed=true
	world._unhandled_input(click)
	expect(world.chest_ui.visible,"Actual right click opens furnace even while holding seeds")
	var ui=world.chest_ui
	expect(ui.furnace_mode and ui.storage.slots.size()==3,"Right-click opens three-slot furnace storage")
	ui.inventory_pointer_press(27,MOUSE_BUTTON_LEFT,true)
	ui.inventory_pointer_press(28,MOUSE_BUTTON_LEFT,true)
	ui.inventory_pointer_press(29,MOUSE_BUTTON_LEFT,true)
	value=Furnace.state(world.model,cell)
	expect(value.slots[0].kind=="wood" and value.slots[0].count==4 and value.slots[1].kind=="planks","Shift-move routes input and fuel correctly")
	expect(world.inventory.slots[29].count==1,"Non-fuel stone cannot enter furnace slots")
	ui.cursor.held=Registry.stack("wood",1)
	ui.cursor.press(38,MOUSE_BUTTON_LEFT)
	ui.cursor.finish()
	expect(ui.cursor.held.count==1 and value.slots[2].count==0,"Result is extraction-only")
	ui.cursor.return_all()
	world._physics_process(3.1)
	ui.refresh()
	expect(value.slots[2].kind=="coal" and value.slots[2].count==1 and value.slots[0].count==3,"Furnace keeps running while its dialog is open")
	expect(ui.furnace_progress.value>0 and ui.fuel_progress.value>0,"Progress and remaining fire are visible")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.day_hud.refresh(0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://furnace-preview.png")
	ui.inventory_pointer_press(38,MOUSE_BUTTON_LEFT,true)
	expect(world.inventory.count_item("coal")==1 and value.slots[2].count==0,"Output shift-moves into inventory")
	expect(ui.get_global_rect().end.y<=root.get_visible_rect().size.y,"Furnace dialog fits the screen")
	expect(ui.close() and Furnace.contents(world.model,cell).size()==3,"Closing dialog preserves furnace slots")
	world.model.advance(3)
	expect(value.slots[2].count==1,"Furnace continues after dialog closes")
	world.inventory.slots[27]=Registry.stack("pickaxe",1)
	world.select_hotbar(0)
	world.target_cell=cell
	world.mining_held=true
	world.update_mining(0.71)
	expect(world.model.kind_at(cell)=="air" and not Furnace.records(world.model).has(cell),"Mining burning furnace removes its saved state")
	var oven_drops: int=0
	var coal_drops: int=0
	for record in world.model.entities.values():
		if record.type=="pickup" and record.kind=="furnace":
			oven_drops+=record.count
		if record.type=="pickup" and record.kind=="coal":
			coal_drops+=record.count
	expect(oven_drops==1 and coal_drops==1,"Mining returns furnace and its stored output as ground items")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("FURNACE TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
