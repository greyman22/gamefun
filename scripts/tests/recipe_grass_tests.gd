extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Farm = preload("res://scripts/core/farming.gd")
const Pickup = preload("res://scripts/pickup.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var data := Data.new()
	var counts: Array[int] = [0,0,0]
	var tall := Vector3i.ZERO
	for x in range(80):
		for z in range(80):
			var cell := Vector3i(x,data.generator.height(x,z),z)
			if Farm.wild_at(data,cell):
				var height: float = Farm.wild_height(data,cell)
				var index: int = [0.6,0.95,1.9].find(height)
				counts[index]+=1
				if height==1.9:
					tall=cell
	var same: int = 0
	var comparisons: int = 0
	for x in range(80):
		for z in range(80):
			var cell:=Vector3i(x,0,z)
			if Farm.wild_height(data,cell)==1.9:
				comparisons+=1
				if Farm.wild_height(data,cell+Vector3i.RIGHT)==1.9:
					same+=1
	expect(float(same)/comparisons>0.75,"Tall grass must cluster with neighbouring tall grass")
	expect(Farm.harvest_seconds({"wild":true},"hand")==0.2 and Farm.harvest_seconds({"wild":true},"axe")==0.2,"Wild grass always harvests in 0.2 seconds")
	expect(Farm.harvest_seconds({"wild":false},"hand")==3.0,"Crop harvesting time remains unchanged")
	var total: float = counts[0]+counts[1]+counts[2]
	for count in counts:
		expect(float(count)/total>0.28 and float(count)/total<0.38,"Grass heights each cover about one third")
	var start: Vector3=Vector3(tall)+Vector3(0.35,1.75,0.5)
	var hit: Dictionary=Farm.pick(data,start,start+Vector3(0.3,0,0))
	expect(not hit.is_empty() and hit.cell==tall,"Tall grass can be selected at player eye height")
	var seed := Pickup.new()
	seed.configure("grass_seed")
	expect(seed.scale==Vector3.ONE*4,"Ground seeds must be four times larger")
	seed.free()
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
	world.player.paused=false
	var wild_cell: Vector3i = tall
	world.target_plant={"wild":true,"cell":wild_cell}
	world.mining_held=true
	world.update_plant_harvest(0.19)
	expect(Farm.wild_at(world.model,wild_cell),"Grass remains before 0.2 second threshold")
	world.update_plant_harvest(0.02)
	expect(not Farm.wild_at(world.model,wild_cell) and world.model.kind_at(wild_cell+Vector3i.DOWN)=="dirt","Actual grass harvest completes at 0.2 seconds without removing soil")
	world.toggle_inventory(true)
	await process_frame
	world.recipe_search.text="br\u00f6d"
	world.filter_recipes(world.recipe_search.text)
	var visible: Array=[]
	for entry in world.template_buttons:
		if entry.button.visible:
			visible.append(entry.recipe.kind)
	expect(visible==["bread"],"Search filters recipes by Swedish display name")
	world.filter_recipes("no_such_recipe")
	expect(world.recipe_empty.visible,"Empty search gives feedback")
	world.recipe_search.text=""
	world.filter_recipes("")
	await process_frame
	await process_frame
	expect(world.recipe_grid.columns==4,"Recipe list uses four icon columns and supports scrolling when needed")
	world.recipe_scroll.scroll_vertical=10000
	await process_frame
	var bread_button: Button
	for entry in world.template_buttons:
		if entry.recipe.kind=="bread":
			bread_button=entry.button
	expect(bread_button.get_global_rect().intersects(world.recipe_scroll.get_global_rect()),"Last recipe can be reached by scrolling")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://recipe-scroll-preview.png")
	world.toggle_inventory()
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("RECIPE AND GRASS TESTS: ","PASS" if failures==0 else failures," heights=",counts)
	quit(0 if failures==0 else 1)
