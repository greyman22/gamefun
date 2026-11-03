extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Flat=preload("res://scripts/tests/night_population_tests.gd")
const Cotton=preload("res://scripts/core/cotton.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Registry=preload("res://scripts/core/registry.gd")
var failures: int=0
func expect(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	Registry.initialize()
	var data=Data.new(42)
	data.generator=Flat.FlatLand.new()
	for mode in ["debug","play"]:
		for i in range(30):
			var cell:=Vector3i(i,0,0)
			var id: String=Cotton.plant(data,cell,mode)
			expect(not id.is_empty(),"Cotton plants in dirt")
			var record: Dictionary=data.entities[id]
			expect(record.growth_seconds>=60 and record.growth_seconds<=180 if mode=="debug" else record.growth_seconds>=120 and record.growth_seconds<=300,"Growth duration follows game mode")
			expect(Cotton.plant(data,cell,mode).is_empty(),"Cannot plant twice in same cell")
			expect(Cotton.harvest(data,id,"stone_shears").is_empty(),"Immature cotton cannot be clipped")
			data.game_time=record.ripe_at
			var drops: Dictionary=Cotton.harvest(data,id,"stone_shears")
			expect(drops.cotton>=1 and drops.cotton<=3 and data.entities.has(id),"Clipping yields cotton and retains plant")
			expect(record.ripe_at>data.game_time and Cotton.stage(record,data.game_time)==0,"Clipping starts regrowth")
			var shoots: Dictionary=Cotton.harvest(data,id,"shovel" if i%2 else "")
			expect(shoots.cotton_shoot>=1 and shoots.cotton_shoot<=2 and shoots.cotton>=1 and shoots.cotton<=3 and not data.entities.has(id),"Digging produces one to two shoots plus one to three cotton and removes plant")
	var world=load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var cell:=Vector3i(3,35,3)
	world.model.set_block(cell+Vector3i.DOWN,"dirt")
	world.model.set_block(cell,"air")
	var id: String=Cotton.plant(world.model,cell,"debug",true)
	world.entity_system.activate(id,world.model.entities[id])
	world.inventory.slots[27]=Registry.stack("stone_shears",1)
	world.select_hotbar(0)
	world.target_bush=id
	world.mining_held=true
	world.update_harvest(0.8)
	expect(world.model.game_time>=world.model.entities[id].ripe_at,"Left mouse with shears does not clip the plant")
	world.player.position=Vector3(3.5,35,5)
	world.player.camera.look_at(Vector3(3.5,35.7,3.5))
	world.player.paused=false
	world.player.inventory_open=false
	world.player.movement_blocked=false
	await physics_frame
	await physics_frame
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_RIGHT
	click.pressed=true
	world._unhandled_input(click)
	expect(world.model.entities.has(id) and world.model.kind_at(cell+Vector3i.DOWN)=="dirt","Clipping leaves plant and supporting soil")
	var cotton_drops: Array=world.model.entities.values().filter(func(r: Dictionary) -> bool: return r.type=="pickup" and r.kind=="cotton")
	expect(not cotton_drops.is_empty() and cotton_drops[0].state.falling and cotton_drops[0].ground_before_pickup,"Cotton falls as collectible objects")
	world.inventory.slots[27]=Registry.stack("shovel",1)
	world.update_counter()
	world.target_bush=id
	world.mining_held=true
	world.update_harvest(0.8)
	expect(not world.model.entities.has(id) and world.model.kind_at(cell+Vector3i.DOWN)=="dirt","Shovel uproots plant without digging soil")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("COTTON TESTS ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
