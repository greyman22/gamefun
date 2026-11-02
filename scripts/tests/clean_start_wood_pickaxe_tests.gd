extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Craft=preload("res://scripts/crafting.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var table:=Craft.new(3)
	for i in [0,1,2]:
		table.slots[i]=Registry.stack("planks",1)
	for i in [4,7]:
		table.slots[i]=Registry.stack("stick",1)
	var bag:=Inventory.new()
	expect(table.craft(bag) and bag.count_item("wood_pickaxe")==1,"Three planks and two sticks craft wooden mining pick")
	expect(Registry.seconds("wood_pickaxe","stone")==1.4 and Registry.seconds("pickaxe","stone")==0.7,"Wood pick mines twice as slowly as stone pick")
	expect(Registry.drops("wood_pickaxe","stone") and not Registry.drops("hand","stone"),"Wood pick yields stone like stone pick")
	expect(Registry.seconds("wood_pickaxe","dirt")==Registry.seconds("pickaxe","dirt"),"Wrong-material behaviour is identical")
	expect(Registry.stack_limit("wood_pickaxe")==1 and Registry.durability_max("wood_pickaxe")==40,"Wood pick takes one slot and lasts forty uses")
	bag.slots[27]=Registry.stack("wood_pickaxe",1)
	for i in range(39):
		expect(not bag.wear(27),"Wood pick survives first thirty-nine uses")
	expect(bag.wear(27) and bag.slots[27].count==0,"Wood pick breaks on fortieth use")
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
	expect(world.game_mode=="play" and world.inventory.slots.all(func(s: Dictionary) -> bool: return s.count==0),"Play starts with all slots empty")
	for id in world.model.entities:
		expect(not id.begins_with("starter_") and world.model.entities[id].type!="pickup","No loose starter items in play world")
	var cell:=Vector3i(10,35,10)
	world.model.set_block(cell,"stone")
	world.inventory.slots[27]=Registry.stack("wood_pickaxe",1)
	world.select_hotbar(0)
	world.target_cell=cell
	world.mining_held=true
	world.update_mining(1.39)
	expect(world.model.kind_at(cell)=="stone","Wood pick has not finished before 1.4 seconds")
	world.update_mining(0.02)
	expect(world.model.kind_at(cell)=="air" and Registry.remaining_uses(world.inventory.slots[27])==39,"Wood pick actually mines stone and wears once")
	var stone_drops: int=0
	for record in world.model.entities.values():
		if record.type=="pickup" and record.kind=="stone":
			stone_drops+=1
	expect(stone_drops==1,"Wood pick creates normal falling stone reward")
	world.model.entities.starter_pickaxe={"type":"pickup","kind":"pickaxe","position":Vector3(0,1,0),"state":{}}
	var saved: Dictionary=world.snapshot()
	expect(world.restore_snapshot(saved) and not world.model.entities.has("starter_pickaxe"),"Legacy loose starter tools removed when loading")
	expect(world.inventory.count_item("wood_pickaxe")==1 and Registry.remaining_uses(world.inventory.slots[27])==39,"Loading keeps earned equipment and tool wear")
	world.new_world(42,"debug")
	expect(world.inventory.count_item("wood_pickaxe")==1 and world.inventory.count_item("pickaxe")==1,"Debug still supplies both pickaxe variants")
	world.toggle_inventory(true)
	world.select_recipe_category("tools")
	expect(world.template_buttons.any(func(e: Dictionary) -> bool: return e.recipe.kind=="wood_pickaxe" and e.button.visible),"Wood pick has a tool recipe template")
	if "--capture-ui" in OS.get_cmdline_user_args():
		for entry in world.template_buttons:
			if entry.recipe.kind=="wood_pickaxe":
				entry.button.pressed.emit()
		world.day_hud.refresh(0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://wood-pickaxe-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("CLEAN START AND WOOD PICKAXE TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
