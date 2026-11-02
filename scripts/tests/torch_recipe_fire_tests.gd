extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
const Craft=preload("res://scripts/crafting.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Cursor=preload("res://scripts/core/stack_cursor.gd")
const Furnace=preload("res://scripts/core/furnaces.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var recipe: Dictionary={}
	for entry in Registry.catalog.recipes:
		if entry.kind=="torch":
			recipe=entry
	for width in [2,3]:
		var table:=Craft.new(width)
		var bag:=Inventory.new()
		bag.add_items("coal",1)
		bag.add_items("stick",1)
		var cursor:=Cursor.new()
		cursor.bind(bag,table)
		expect(cursor.fill_template(recipe),"Torch template fills both crafting sizes")
		var column: int=0 if width==2 else 1
		expect(table.slots[column].kind=="coal" and table.slots[width+column].kind=="stick","Coal above stick in intended column")
		expect(table.craft(bag) and bag.count_item("torch")==4,"One coal and one stick craft four torches")
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	var cell:=Vector3i(3,35,3)
	world.model.set_block(cell,"furnace")
	world.chest_ui.open(cell)
	world.chest_ui.set_process(false)
	var value: Dictionary=Furnace.state(world.model,cell)
	value.slots[0]=Registry.stack("wood",2)
	value.slots[1]=Registry.stack("foliage",1)
	world.model.advance(0.001)
	world.chest_ui.refresh()
	var initial: float=world.chest_ui.fuel_progress.value
	expect(initial>99 and value.slots[1].count==0,"Flame stays visible after last fuel item leaves its slot")
	world.model.advance(0.499)
	world.chest_ui.refresh()
	expect(world.chest_ui.fuel_progress.value==initial,"Fuel expiry does not abruptly clear flame display")
	world.chest_ui.update_fire_display(0.2)
	var fading: float=world.chest_ui.fuel_progress.value
	expect(fading>0 and fading<initial,"Flame fades gradually toward zero")
	world.chest_ui.update_fire_display(2)
	expect(world.chest_ui.fuel_progress.value==0,"Flame eventually reaches zero")
	expect(value.slots[2].count==0 and value.burn_left==0,"Visual fade does not add energy or production")
	world.chest_ui.close()
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("TORCH RECIPE AND FIRE FADE TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
