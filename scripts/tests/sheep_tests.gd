extends SceneTree
const Hens=preload("res://scripts/core/hens.gd")
const Sheep=preload("res://scripts/core/sheep.gd")
const Registry=preload("res://scripts/core/registry.gd")
const Combat=preload("res://scripts/core/combat.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func count(world: Node, kind: String) -> int:
	var result: int=0
	for r: Dictionary in world.model.entities.values():
		if r.type=="pickup" and r.kind==kind:
			result+=int(r.count)
	return result
func spawn(world: Node,id: String,point: Vector3,young: bool=false,species: String="sheep") -> Node:
	Hens.create(world.model,id,point,point,"debug",young,species)
	world.entity_system.activate(id,world.model.entities[id])
	return world.entity_system.active[id]
func run() -> void:
	Registry.initialize()
	for width in [2,3]:
		var crafting=load("res://scripts/crafting.gd").new(width)
		crafting.slots[1]=Registry.stack("stone")
		crafting.slots[width]=Registry.stack("stone")
		expect(crafting.recipe().get("kind","")=="stone_shears","Diagonal stone recipe works in both grids")
	var world=load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.entity_system.game_mode="debug"
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for x in range(-10,11):
		for z in range(-10,11):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	var sheep: Node=spawn(world,"sheep_test",Vector3(3.5,35,2.5))
	expect(sheep.wander_radius==30 and not sheep.swims,"Sheep roam 30m and avoid water")
	expect(Hens.feed(world.model,"sheep_test"),"Adult sheep accepts breeding food")
	world.model.entities.sheep_test.love_until=0
	var before: int=count(world,"wool")
	expect(Sheep.shear(world.entity_system,"sheep_test"),"Clipping removes fleece and always yields wool")
	expect(not sheep.woolly and count(world,"wool")-before>=1 and count(world,"wool")-before<=3,"Every clipping gives one to three wool")
	expect(not Sheep.shear(world.entity_system,"sheep_test"),"Cannot shear bare sheep again")
	var delay: float=world.model.entities.sheep_test.wool_at-world.model.game_time
	expect(delay>=30 and delay<=60,"Debug wool regrowth is 30 to 60 seconds")
	world.model.game_time=world.model.entities.sheep_test.wool_at+0.01
	sheep.simulate(0)
	expect(sheep.woolly,"Fleece grows back")
	before=count(world,"wool")
	Sheep.shear(world.entity_system,"sheep_test")
	expect(int(world.model.entities.sheep_test.last_shear_yield)>=1,"Successful clip records the wool yield for player feedback")
	expect(count(world,"wool")-before>=1 and count(world,"wool")-before<=3,"Successful clipping drops one to three wool")
	# Exercise real pickup activation and gravity, not just the spawn records.
	world.entity_system.tick(Vector3(3.5,35,2.5),1)
	for frame in range(90):
		world.model.game_time+=1.0/60
		world.entity_system.simulate_drops(1.0/60)
	var wool_on_ground: int=0
	for r: Dictionary in world.model.entities.values():
		if r.type=="pickup" and r.kind=="wool":
			if r.state.get("grounded",false) and r.position.y>=35 and r.position.y<35.3:
				wool_on_ground+=int(r.count)
	expect(wool_on_ground==count(world,"wool") and wool_on_ground>0,"Clipped wool physically falls onto the ground")
	var lamb: Node=spawn(world,"lamb_test",Vector3(6.5,35,2.5),true)
	expect(not Hens.feed(world.model,"lamb_test"),"Lamb cannot breed")
	expect(not Sheep.shear(world.entity_system,"lamb_test"),"Lamb cannot be sheared")
	world.entity_system.damage_actor("lamb_test",Combat.damage(10,0),0,world.player.position)
	expect(not world.model.entities.has("lamb_test"),"Lamb dies in one unarmed hit")
	world.entity_system.damage_actor("sheep_test",1,0,Vector3(3.5,35,4))
	expect(sheep.flee_until>world.model.game_time,"Surviving sheep flees when hit")
	var hen: Node=spawn(world,"hen_flee",Vector3(-3.5,35,2.5),false,"hen")
	world.entity_system.damage_actor("hen_flee",1,0,Vector3(-3.5,35,4))
	expect(hen.flee_until>world.model.game_time,"Surviving hen flees when hit")
	var wool_before_death: int=count(world,"wool")
	world.entity_system.damage_actor("sheep_test",1000,0,world.player.position)
	expect(not world.model.entities.has("sheep_test") and count(world,"raw_mutton")==1,"Ordinary adult sheep death drops mutton")
	var death_wool: int=count(world,"wool")-wool_before_death
	expect(death_wool>=1 and death_wool<=3,"Adult sheep death drops one to three wool blocks")
	var young_before: int=0
	for r: Dictionary in world.model.entities.values():
		if r.type=="sheep" and not Hens.adult(r,world.model.game_time):
			young_before+=1
	var a: Node=spawn(world,"mate_a",Vector3(0.5,35,0.5))
	var b: Node=spawn(world,"mate_b",Vector3(1.35,35,0.5))
	Hens.feed(world.model,"mate_a")
	Hens.feed(world.model,"mate_b")
	Hens.tick(world.entity_system,0,"sheep")
	world.model.game_time+=3.1
	Hens.tick(world.entity_system,0,"sheep")
	var young_count: int=0
	for r: Dictionary in world.model.entities.values():
		if r.type=="sheep" and not Hens.adult(r,world.model.game_time):
			young_count+=1
	expect(young_count==young_before+1 and a.record.partner=="" and b.record.partner=="","Sheep pair produces one lamb after three seconds")
	expect(Hens.growth("debug")==120 and Hens.growth("play")==600,"Lambs and chicks share mode-dependent growth")
	var drowning: Node=spawn(world,"drowning",Vector3(8.5,35,2.5))
	world.model.set_block(Vector3i(8,35,2),"water_source")
	drowning.drowning=10
	Sheep.tick(world.entity_system,0)
	expect(not world.model.entities.has("drowning") and count(world,"raw_mutton")==2,"Drowned sheep drops mutton")
	var sword: Dictionary=Combat.stats("player","stone_sword")
	expect(Combat.damage(sword.attack,Combat.stats("sheep").defense)*2>=Combat.stats("sheep").health,"Sword kills adult in at most two hits")
	# Interact through the actual camera ray and selected quickbar tool.
	var interact: Node=spawn(world,"interact_sheep",Vector3(3.5,35,2.5))
	world.player.position=Vector3(3.5,35,4.1)
	world.player.camera.look_at(Vector3(3.5,35.7,2.5))
	world.inventory.slots[27]=Registry.stack("grain",2)
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	expect(world.feed_hen() and interact.record.love_until>world.model.game_time,"Right click feeds sheep with grain")
	expect(world.inventory.slots[27].count==1,"Feeding consumes one grain")
	world.inventory.slots[27]=Registry.stack("stone_shears")
	world.update_counter()
	expect(world.feed_hen() and not interact.woolly,"Right click with stone shears clips sheep")
	expect(Registry.remaining_uses(world.inventory.slots[27])==99,"Clipping wears shears once")
	var panic: Node=spawn(world,"panic_runner",Vector3(-6.5,35,-5.5))
	world.entity_system.damage_actor("panic_runner",1,0,Vector3(-6.5,35,-3.5))
	var start: Vector3=panic.position
	for i in range(60):
		world.model.game_time+=1.0/60
		panic.simulate(1.0/60)
	expect(panic.position.distance_to(start)>3,"Frightened sheep really runs away rather than only changing state")
	var saved: Dictionary=world.snapshot()
	expect(world.restore_snapshot(saved),"World with sheep and new items restores")
	expect(world.model.entities.interact_sheep.wool_at>world.model.game_time,"Clipped wool timer persists")
	expect(world.inventory.slots[27].kind=="stone_shears" and Registry.remaining_uses(world.inventory.slots[27])==99,"Shears durability persists")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.entity_system.game_mode="debug"
		world.player.position=Vector3(3.5,35,6.5)
		world.player.camera.look_at(Vector3(3.5,35.65,1.5))
		spawn(world,"visual_wool",Vector3(2,35,1))
		spawn(world,"visual_lamb",Vector3(4.5,35,1),true)
		world.daylight_amount=1
		world.update_daylight(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://sheep-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("SHEEP TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
