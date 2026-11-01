extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Farm = preload("res://scripts/core/farming.gd")
const Craft = preload("res://scripts/crafting.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	Registry.initialize()
	expect(Registry.label("pickaxe")=="Gruvhacka" and Registry.tool("hoe"),"Mining pick renamed and hoe registered")
	var data := Data.new(20261030)
	var eligible: int = 0
	var grasses: Array[Vector3i] = []
	for x in range(80):
		for z in range(80):
			var cell := Vector3i(x,data.generator.height(x,z),z)
			if data.kind_at(cell)=="air" and data.kind_at(cell+Vector3i.DOWN)=="dirt":
				eligible+=1
			if Farm.wild_at(data,cell):
				grasses.append(cell)
	var density: float = float(grasses.size())/eligible
	expect(density>=0.2 and density<=0.3,"Wild grass covers 20-30 percent of eligible meadow soil")
	seed(731)
	var seeds: int = 0
	for i in range(500):
		var cell: Vector3i = grasses[i]
		var reward: Dictionary=Farm.harvest(data,{"wild":true,"cell":cell})
		seeds+=int(reward.get("grass_seed",0))
		expect(not Farm.wild_at(data,cell),"Harvested wild grass stays removed")
	expect(seeds>70 and seeds<130,"Seed reward frequency near twenty percent")
	var cell := Vector3i(4,35,4)
	data.set_block(cell+Vector3i.DOWN,"dirt")
	expect(Farm.plant(data,cell,"debug").is_empty(),"Seeds require tilled soil")
	expect(Farm.till(data,cell+Vector3i.DOWN),"Hoe prepares soil")
	for mode in ["debug","play"]:
		var id: String=Farm.plant(data,cell,mode)
		expect(not id.is_empty(),"Seed can be planted on farmland")
		var record: Dictionary=data.entities[id]
		var checkpoint := Data.new()
		expect(checkpoint.import_state(data.export_state()) and checkpoint.entities[id].ripe_at==record.ripe_at,"Planted crop and maturation deadline survive save/load")
		var duration: float=record.ripe_at-record.planted_at
		expect((duration>=60 and duration<=120) if mode=="debug" else (duration>=240 and duration<=480),"Growth duration matches game mode")
		for stage in range(4):
			expect(Farm.stage(record,record.planted_at+duration*stage/4)==stage,"Four growth stages")
		expect(Farm.harvest(data,{"wild":false,"id":id}).is_empty(),"Immature grain cannot be harvested")
		data.game_time=record.ripe_at
		var rewards: Dictionary=Farm.harvest(data,{"wild":false,"id":id})
		expect(rewards.get("grain")==1 and int(rewards.get("grass_seed"))>=1 and int(rewards.get("grass_seed"))<=3,"Mature grain gives one stalk and one to three seeds")
	var saved := Data.new()
	expect(saved.import_state(data.export_state()) and not Farm.wild_at(saved,grasses[0]) and saved.kind_at(cell+Vector3i.DOWN)=="farmland","Harvest and farmland survive save/load")
	var hoe_table := Craft.new(3)
	for i in [1,2]:
		hoe_table.slots[i]=Registry.stack("stone",1)
	for i in [4,7]:
		hoe_table.slots[i]=Registry.stack("stick",1)
	expect(hoe_table.recipe().get("kind","")=="hoe","Hoe recipe places second stone right of shaft")
	var hoe_bag=load("res://scripts/inventory.gd").new()
	hoe_bag.add_items("stone",2)
	hoe_bag.add_items("stick",2)
	var hoe_cursor=load("res://scripts/core/stack_cursor.gd").new()
	var template_grid:=Craft.new(3)
	hoe_cursor.bind(hoe_bag,template_grid)
	for recipe in Registry.catalog.recipes:
		if recipe.kind=="hoe":
			expect(hoe_cursor.fill_template(recipe) and template_grid.recipe().get("kind","")=="hoe","Offset hoe template still crafts")
	for i in [0,3,6]:
		expect(template_grid.slots[i].count==0,"Hoe template leaves first column empty")
	var table := Craft.new(3)
	for i in range(3):
		table.slots[i]=Registry.stack("grain",1)
	var bag=load("res://scripts/inventory.gd").new()
	expect(table.craft(bag) and bag.count_item("bread")==1,"Three grain across craft one bread")
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
	world.game_mode="debug"
	for x in range(0,8):
		for z in range(0,8):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	world.player.position=Vector3(4.5,35,6)
	world.streamer.warm_start(world.player.position)
	await process_frame
	world.player.camera.look_at(Vector3(4.5,35,4.5))
	world.inventory.slots[27]=Registry.stack("hoe",1)
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	expect(world.try_farm_action() and world.model.kind_at(Vector3i(4,34,4))=="farmland","Right-click hoe actually tills targeted soil")
	expect(Registry.remaining_uses(world.inventory.slots[27])==99,"Successful till wears hoe once")
	world.inventory.slots[27]=Registry.stack("grass_seed",3)
	world.update_counter()
	expect(world.try_farm_action() and world.inventory.slots[27].count==2,"Right-click plants and consumes one seed")
	var crop_id: String=Farm.crop_at(world.model,Vector3i(4,35,4))
	expect(not crop_id.is_empty(),"Crop entity exists")
	if not crop_id.is_empty():
		world.model.game_time=world.model.entities[crop_id].ripe_at
		world.entity_system.active[crop_id].refresh()
		world.player.camera.look_at(Vector3(4.5,35.4,4.5))
		world.update_build_preview()
		expect(world.target_plant.get("id","")==crop_id and world.bush_focus.visible,"Focus selects crop instead of soil behind it")
		world.mining_held=true
		world.update_plant_harvest(3.01)
		expect(not world.model.entities.has(crop_id) and world.model.kind_at(Vector3i(4,34,4))=="farmland","Harvest removes crop but preserves soil")
		var grain_drops: int=0
		for record in world.model.entities.values():
			if record.type=="pickup" and record.kind=="grain":
				grain_drops+=1
		expect(grain_drops==1,"Crop reward first becomes a falling ground pickup")
	if "--capture-ui" in OS.get_cmdline_user_args():
		for stage in range(4):
			var display_cell:=Vector3i(2+stage,35,3)
			world.model.set_block(display_cell+Vector3i.DOWN,"farmland")
			var id: String=Farm.plant(world.model,display_cell,"debug")
			var record: Dictionary=world.model.entities[id]
			var duration: float=record.ripe_at-record.planted_at
			record.planted_at=world.model.game_time-duration*float(stage)/3
			record.ripe_at=record.planted_at+duration
			world.entity_system.activate(id,record)
		world.streamer.build_now(Vector3i(0,2,0))
		world.player.position=Vector3(4,35,7)
		await process_frame
		world.player.camera.look_at(Vector3(4,35.4,3.5))
		world.update_daylight(0)
		world.day_hud.refresh(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://farming-preview.png")
		world.player.position=Vector3(25,world.model.generator.height(25,30)+0.1,30)
		world.streamer.warm_start(world.player.position)
		for step in range(10):
			world.entity_system.grass_field.tick(world.player.position,0.3)
		await process_frame
		world.player.camera.rotation=Vector3(-0.25,0,0)
		world.reset_held_pose()
		world.update_daylight(0)
		world.day_hud.refresh(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://meadow-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("FARMING TESTS: ","PASS" if failures==0 else failures," meadow density=",density," seed drops=",seeds)
	quit(0 if failures==0 else 1)
