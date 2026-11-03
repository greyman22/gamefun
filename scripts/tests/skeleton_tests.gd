extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Flat=preload("res://scripts/tests/night_population_tests.gd")
const Registry=preload("res://scripts/core/registry.gd")
const Combat=preload("res://scripts/core/combat.gd")
const Arrows=preload("res://scripts/core/arrows.gd")
const Loot=preload("res://scripts/core/skeleton_loot.gd")
const Vitals=preload("res://scripts/core/vitals.gd")
class Target extends CharacterBody3D:
	var vitals=preload("res://scripts/core/vitals.gd").new()
	func receive_attack(amount: float,_from: Vector3,_source: String="zombie") -> float:
		return vitals.damage(amount,"arrow")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func clear_arrows(system: Node) -> void:
	for id: String in system.model.entities.keys():
		if system.model.entities[id].type=="arrow_flight":
			Arrows.remove(system,id)
func spawn(system: Node,id: String,point: Vector3) -> Node:
	system.model.entities[id]={"type":"skeleton","position":point,"home":point,"spawn_position":point,"state":{}}
	system.activate(id,system.model.entities[id])
	return system.active[id]
func run() -> void:
	seed(7331)
	Registry.initialize()
	var stats: Dictionary=Combat.stats("skeleton")
	for attack_value in [stats.attack_min,stats.attack_max]:
		var vitals=Vitals.new()
		var hits: int=0
		while vitals.health>0 and hits<10:
			vitals.damage(Combat.damage(attack_value,Combat.stats("player").defense),"arrow")
			hits+=1
			if vitals.health>0:
				vitals.tick(6)
		expect(hits>=2 and hits<=4,"Skeleton arrows kill in two to four hits including fed regeneration")
	for defense in [0,20,40]:
		var damage: float=Combat.damage(Combat.stats("player","stone_sword").attack,defense)
		expect(ceili(float(stats.health)/damage) in [4,5,6],"Skeleton has doubled health")
	var bows: int=0
	for i in range(2000):
		for item: Dictionary in Loot.roll():
			if item.kind=="bone":
				expect(item.count>=1 and item.count<=2,"Bone drops are bounded")
			elif item.kind=="arrow":
				expect(item.count>=1 and item.count<=3,"Arrow drops are bounded")
			elif item.kind=="bow":
				bows+=1
				expect(item.count==1 and item.durability>=5 and item.durability<=25,"Dropped bows have five to twenty-five percent durability")
	expect(bows>330 and bows<470,"Bow drop chance is approximately twenty percent")
	var model=Data.new(42)
	model.generator=Flat.FlatLand.new()
	var system=System.new()
	system.configure(model,"debug")
	root.add_child(system)
	var target:=Target.new()
	root.add_child(target)
	target.position=Vector3(0.5,0,0.5)
	var arrow: String=Arrows.spawn(system,"test",Vector3(-5,1,0.5),Vector3(18,0,0),56,"enemy",0)
	for frame in range(30):
		Arrows.tick(system,1.0/60,target)
	expect(absf(target.vitals.health-60)<0.01 and not model.entities.has(arrow),"An actual arrow crossing the player deals damage once")
	clear_arrows(system)
	target.vitals.health=100
	target.position=Vector3(0.5,0,3.5)
	Arrows.spawn(system,"test",Vector3(-5,1,0.5),Vector3(18,0,0),56,"enemy",0)
	for frame in range(40):
		Arrows.tick(system,1.0/60,target)
	expect(target.vitals.health==100,"Moving out of the flight line avoids the shot")
	clear_arrows(system)
	target.position=Vector3(0.5,0,0.5)
	model.set_block(Vector3i(-2,1,0),"stone")
	arrow=Arrows.spawn(system,"test",Vector3(-5,1,0.5),Vector3(18,0,0),56,"enemy",0)
	for frame in range(30):
		Arrows.tick(system,1.0/60,target)
	expect(target.vitals.health==100 and model.entities[arrow].stuck,"Walls stop arrows before the player")
	Arrows.tick(system,2,target)
	expect(model.entities.has(arrow) and model.entities[arrow].remaining>290,"Missed arrows remain embedded for five minutes")
	var bag=load("res://scripts/inventory.gd").new()
	system.collect(Vector3(-2.9,0,0.5),bag)
	expect(model.entities.has(arrow) and bag.count_item("arrow")==0,"Enemy arrows cannot be recovered as ammunition")
	var player_arrow: String=Arrows.spawn(system,"player",Vector3(-5,1,0.5),Vector3(18,0,0),35,"player",0)
	for frame in range(30):
		Arrows.tick(system,1.0/60,target)
	expect(model.entities[player_arrow].stuck,"Player arrow embeds in an actual wall")
	for slot in range(bag.slots.size()):
		bag.slots[slot]=Registry.stack("stone",64)
	system.collect(Vector3(-2.9,0,0.5),bag)
	expect(model.entities.has(player_arrow),"A full inventory leaves the arrow in place")
	bag.slots[35]=Registry.stack("",0)
	system.collect(Vector3(-2.9,0,0.5),bag)
	expect(not model.entities.has(player_arrow) and bag.count_item("arrow")==1,"Wall arrow is recovered exactly once when a slot is available")
	model.set_block(Vector3i(-2,1,0),"air")
	clear_arrows(system)
	var skeleton: Node=spawn(system,"archer",Vector3(7.5,0,0.5))
	var shots: Array[float]=[]
	skeleton.arrow_released.connect(func(_point: Vector3,_velocity: Vector3,_attack: float) -> void: shots.append(model.game_time))
	for frame in range(840):
		model.game_time+=1.0/60
		skeleton.simulate(1.0/60,target)
		skeleton.attack(target)
	expect(shots.size()==3,"Archer fires repeatedly while the player stays exposed")
	for i in range(1,shots.size()):
		expect(absf(shots[i]-shots[i-1]-6)<0.06,"Arrow releases are six seconds apart")
	expect(skeleton.behavior=="chase","Skeleton acquires target inside eight metres")
	target.position=skeleton.position+Vector3(20.2,0,0)
	skeleton.update_behavior(0.5,target)
	expect(skeleton.behavior!="chase","Skeleton drops pursuit at the zombie distance")
	clear_arrows(system)
	var accuracy: Array[int]=[]
	for distance in [4,14]:
		var hits_at_distance: int=0
		target.position=Vector3(0.5,0,0.5)
		skeleton.position=target.position+Vector3(0,0,distance)
		skeleton.behavior="chase"
		for trial in range(24):
			clear_arrows(system)
			target.vitals.health=100
			skeleton.strike_time=0.81
			skeleton.strike_hit=false
			skeleton.advance_strike(0,target)
			for frame in range(65):
				Arrows.tick(system,1.0/60,target)
			if target.vitals.health<100:
				hits_at_distance+=1
		accuracy.append(hits_at_distance)
	clear_arrows(system)
	print("ARROW ACCURACY near=",accuracy[0],"/24 far=",accuracy[1],"/24")
	expect(accuracy[0]>accuracy[1],"Real projectile accuracy decreases with distance")
	# Find real cover and a clear firing position beside a tree trunk.
	for y in range(5):
		model.set_block(Vector3i(3,y,3),"wood")
	skeleton.position=Vector3(5.5,0,3.5)
	target.position=Vector3(0.5,0,3.5)
	skeleton.choose_cover(target.position)
	expect(skeleton.cover_point is Vector3 and skeleton.peek_point is Vector3,"Skeleton finds hiding and peeking points near a tree")
	if skeleton.cover_point is Vector3:
		expect(Arrows.first_wall(model,skeleton.cover_point+Vector3.UP*1.3,target.position+Vector3.UP)!=null,"Tree blocks the hidden position")
		expect(Arrows.first_wall(model,skeleton.peek_point+Vector3.UP*1.45,target.position+Vector3.UP)==null,"Peeking point provides a clear shot")
		skeleton.behavior="chase"
		skeleton.strike_time=-1
		skeleton.attack_cooldown=5
		expect(skeleton.behavior_destination(target)==skeleton.cover_point,"Archer hides between shots")
		skeleton.attack_cooldown=1
		expect(skeleton.behavior_destination(target)==skeleton.peek_point,"Archer steps out to shoot")
	var saved: Dictionary=model.export_state()
	var restored=Data.new()
	expect(restored.import_state(saved) and restored.entities.archer.defense==model.entities.archer.defense,"Skeleton stats persist")
	# Kill with actual damage dispatch: the skeleton disappears and is not resurrected.
	system.damage_actor("archer",1000,60,target.position)
	expect(not model.entities.has("archer"),"Dead skeleton is removed permanently")
	for r: Dictionary in model.entities.values():
		if r.type=="pickup":
			expect(r.kind in ["bone","arrow","bow"],"Skeleton loot contains no zombie remnant")
	target.queue_free()
	system.queue_free()
	await process_frame
	await world_checks()
	print("SKELETON TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
func world_checks() -> void:
	var world=load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for x in range(-1,13):
		for z in range(-2,13):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	var actor: Node=spawn(world.entity_system,"melee_skeleton",Vector3(3.5,35,2.5))
	world.player.position=Vector3(3.5,35,4.2)
	world.player.camera.look_at(Vector3(3.5,36.2,2.5))
	world.inventory.slots[27]=Registry.stack("stone_sword")
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	var hits: int=0
	while world.model.entities.has("melee_skeleton") and hits<8:
		world.attack_cooldown=0
		world.try_attack()
		hits+=1
	expect(hits in [4,5,6] and not world.model.entities.has("melee_skeleton"),"Real stone sword targeting kills skeleton with doubled health")
	world.inventory.slots[27]=Registry.stack("bow",1,{"durability":17})
	world.inventory.slots[28]=Registry.stack("arrow",4)
	world.select_hotbar(0)
	world.player.paused=false
	world.player.movement_blocked=false
	world.attack_cooldown=0
	expect(world.shoot_bow() and world.inventory.slots[28].count==3 and world.inventory.slots[27].durability==16,"Player can fire a looted bow, consuming one arrow and one use")
	world.begin_bow_draw()
	expect(world.bow_drawing and world.bow_charge==0 and world.attack_cooldown==0,"A new draw starts immediately after firing without a cooldown")
	world.update_bow_charge(0.5)
	expect(world.bow_drawing and is_equal_approx(world.bow_charge,0.5) and world.inventory.count_item("arrow")==3,"Drawing charges without consuming ammunition")
	world.player.inventory_open=true
	world.update_bow_charge(0.1)
	expect(not world.bow_drawing and world.inventory.count_item("arrow")==3,"Opening inventory cancels the draw without ammo loss")
	world.player.inventory_open=false
	world.begin_bow_draw()
	world.update_bow_charge(2)
	expect(world.bow_charge==1,"Draw caps at one second")
	var release:=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_RIGHT
	release.pressed=false
	world._unhandled_input(release)
	expect(not world.bow_drawing and world.inventory.count_item("arrow")==2,"Releasing right mouse fires exactly one arrow")
	world.update_hand_animation(0.1,false)
	expect(world.held_bow_arrow.visible==false,"Nocked arrow disappears after release")
	var wall_arrow: String=Arrows.spawn(world.entity_system,"player",world.player.position+Vector3(0,1,-0.7),Vector3.FORWARD,10,"player",0)
	world.model.entities[wall_arrow].stuck=true
	world.model.entities[wall_arrow].remaining=300
	var old_count: int=world.inventory.count_item("arrow")
	world.entity_system.collect(world.player.position,world.inventory)
	expect(not world.model.entities.has(wall_arrow) and world.inventory.count_item("arrow")==old_count+1,"Player can recover a stuck arrow at chest height")
	var snapshot: Dictionary=world.snapshot()
	var flight_ids: Array=world.entity_system.projectile_ids.keys()
	expect(not flight_ids.is_empty(),"Player shot creates a tracked in-flight arrow")
	expect(world.restore_snapshot(snapshot) and world.inventory.slots[27].durability==15,"Used bow condition saves correctly")
	if not flight_ids.is_empty():
		expect(world.model.entities.has(flight_ids[0]) and world.entity_system.projectile_ids.has(flight_ids[0]) and world.model.entities[flight_ids[0]].velocity==snapshot.world.entities[flight_ids[0]].velocity,"Loading restores in-flight arrow velocity and scheduling")
	if "--capture-ui" in OS.get_cmdline_user_args():
		var archer: Node=spawn(world.entity_system,"portrait",Vector3(3.5,35,2.5))
		archer.behavior="chase"
		archer.rotation.y=0
		archer.strike_time=0.65
		archer.strike_hit=false
		archer.animate(false,0)
		world.player.position=Vector3(5.2,35,6.5)
		world.player.camera.look_at(Vector3(3.5,36,2.5))
		archer.rotation.y=atan2(archer.position.x-world.player.position.x,archer.position.z-world.player.position.z)
		archer.animate(false,0)
		world.attack_cooldown=0
		world.begin_bow_draw()
		world.update_bow_charge(1)
		world.update_hand_animation(0.1,false)
		world.daylight_amount=1
		world.update_daylight(0)
		world.streamer.build_now(Vector3i(0,2,0))
		world.day_hud.refresh(0.1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://skeleton-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
