extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Population=preload("res://scripts/core/night_population.gd")
const Cycle=preload("res://scripts/core/day_cycle.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Registry=preload("res://scripts/core/registry.gd")
class FlatLand extends RefCounted:
	var version: int=1
	const SEA_LEVEL: int=-2
	func height(_x: int,_z: int) -> int:
		return 0
	func max_y() -> int:
		return 63
	func world_limit() -> int:
		return 10000
	func hash_at(x: int,z: int,salt: int) -> int:
		return absi(x*1619+z*31337+salt*6971)
	func ground(cell: Vector3i) -> int:
		return 2 if cell.y<0 else 0
	func trees_in_chunk(_key: Vector3i) -> Array[Dictionary]:
		return []
	func owner(_cell: Vector3i) -> Dictionary:
		return {}
	func tree_kind(_cell: Vector3i,_tree: Dictionary) -> int:
		return 0
	func trim_caches() -> void:
		pass
	func generate(key: Vector3i) -> PackedByteArray:
		var result:=PackedByteArray()
		result.resize(8192)
		for i in range(4096):
			result.encode_u16(i*2,ground(key*16+Vector3i(i%16,(i/16)%16,i/256)))
		return result
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func living(model: RefCounted) -> Array[String]:
	var ids: Array[String]=[]
	for id: String in model.entities:
		if model.entities[id].get("night_spawn",false) and not model.entities[id].get("state",{}).get("dead",false):
			ids.append(id)
	return ids
func souls(model: RefCounted) -> int:
	var count: int=0
	for r: Dictionary in model.entities.values():
		if r.type=="pickup" and r.kind=="soul_remnant":
			count+=int(r.count)
	return count
func run() -> void:
	seed(5566)
	var model=Data.new(42)
	model.generator=FlatLand.new()
	var system=System.new()
	system.configure(model,"debug")
	root.add_child(system)
	var pop=system.night_population
	var player:=Vector3(0.5,0,0.5)
	for i in range(20):
		pop.tick(system,player,0.25)
	expect(living(model).is_empty(),"Daylight creates no night zombies")
	model.entities.test_torch={"type":"torch","kind":"torch","position":Vector3(60.5,0.5,0.5),"state":{}}
	expect(not Population.torch_safe(Vector3(60.5,0,5.5),Population.torches(model)),"Placed torch protects within ten metres even without an active scene node")
	expect(not Population.suitable(model,Vector3(39.5,0,0.5),player,[]),"No spawn within forty metres")
	expect(not Population.suitable(model,Vector3(101.5,0,0.5),player,[]),"No spawn beyond one hundred metres")
	Cycle.state(model).minute=1320
	for i in range(50):
		pop.tick(system,player,0.25)
	var ids: Array[String]=living(model)
	expect(ids.size()>=15 and ids.size()<=20 and ids.size()==pop.target_count,"Night reaches its chosen population between fifteen and twenty")
	expect(ids.any(func(id: String) -> bool: return model.entities[id].type=="skeleton"),"Night population includes skeletons without increasing its total target")
	var clock: float=Population.state(model).clock
	for id in ids:
		var r: Dictionary=model.entities[id]
		expect(Population.suitable(model,r.position,player,Population.torches(model)),"All spawns obey distance, terrain and torch rules")
		expect(r.expires_real-clock>=100 and r.expires_real-clock<=300,"Lifetimes use real seconds rather than accelerated day minutes")
	var victim: String=ids.filter(func(id: String) -> bool: return model.entities[id].type=="zombie")[0]
	system.activate(victim,model.entities[victim])
	var soul_before: int=souls(model)
	system.damage_actor(victim,1000,60,player)
	expect(not model.entities.has(victim) and souls(model)==soul_before+1,"Killed night zombie leaves a remnant and has no fixed respawn")
	for i in range(16):
		pop.tick(system,player,0.25)
	expect(living(model).size()==pop.target_count,"A lost zombie is replaced at a new permitted position")
	victim=living(model).filter(func(id: String) -> bool: return model.entities[id].type=="zombie")[0]
	system.activate(victim,model.entities[victim])
	var actor: Node3D=system.active[victim]
	actor.position=player+Vector3(8,0,0)
	actor.set_behavior("chase")
	expect(model.entities[victim].night_engaged and actor.home==actor.position and actor.origin==actor.position,"Pursuit establishes a new persistent home")
	var chase_home: Vector3=actor.home
	pop.tick(system,player,0.25)
	expect(actor.home==chase_home,"Chasers are exempt from distant home repositioning")
	# Unengaged homes that become too near are moved, without embedding the actor
	# in its old wander boundary or teleporting its body.
	var roaming: String=living(model).filter(func(id: String) -> bool: return id!=victim and not model.entities[id].night_engaged)[0]
	system.activate(roaming,model.entities[roaming])
	var roamer: Node3D=system.active[roaming]
	roamer.position=player+Vector3(25,0,0)
	model.entities[roaming].home=roamer.position
	roamer.home=roamer.position
	var old_position: Vector3=roamer.position
	for i in range(16):
		pop.tick(system,player,0.25)
		if roamer.home.distance_to(player)>=40:
			break
	expect(roamer.home.distance_to(player)>=40 and roamer.home.distance_to(player)<=100 and roamer.position==old_position and roamer.behavior=="return","A nearby unengaged home moves outward without freezing or teleporting the zombie")
	var saved: Dictionary=model.export_state()
	var restored=Data.new()
	expect(restored.import_state(saved) and Population.state(restored).clock==Population.state(model).clock and restored.entities[victim].expires_real==model.entities[victim].expires_real,"Remaining life and home state survive saving")
	# Expire one while the debug world clock remains frozen at night.
	var timed: String=living(model).filter(func(id: String) -> bool: return id!=victim)[0]
	model.entities[timed].expires_real=Population.state(model).clock+0.2
	pop.tick(system,player,0.25)
	expect(not model.entities.has(timed),"Self-death works with a frozen day clock")
	# Moving the player does not leave unengaged populations behind.
	var moved: Vector3=player+Vector3(300,0,0)
	for i in range(60):
		pop.tick(system,moved,0.25)
	expect(model.entities.has(victim),"Previously engaged zombie retains its new home until death")
	var nearby: int=0
	for id in living(model):
		if model.entities[id].position.distance_to(moved)<=100:
			nearby+=1
	expect(nearby==pop.target_count,"Population follows the player without keeping distant ordinary zombies alive")
	# Transition to the configured cleanup hour; house zombies also die, but retain normal respawn behavior.
	model.entities.house={"type":"zombie","position":moved+Vector3(20,0,0),"home":moved,"state":{}}
	Cycle.state(model).minute=1260 if Population.CLEANUP_PHASE=="Skymning" else 240
	pop.tick(system,moved,0.25)
	var deadlines: Dictionary={}
	for id in living(model):
		deadlines[model.entities[id].cleanup_at_real]=true
	expect(deadlines.size()>1,"Cleanup deaths are spread randomly rather than simultaneous")
	for i in range(80):
		pop.tick(system,moved,0.25)
	expect(living(model).is_empty() and model.entities.house.state.dead,"All zombies die during cleanup")
	model.game_time+=500
	system.respawn_zombies()
	expect(model.entities.house.state.dead,"House respawn waits until cleanup has ended")
	Cycle.state(model).minute=480
	system.respawn_zombies()
	expect(not model.entities.house.state.get("dead",false),"House zombie retains its normal respawn after cleanup")
	expect(souls(model)>soul_before and model.entities.values().any(func(r: Dictionary) -> bool: return r.type=="pickup" and r.kind=="soul_remnant" and r.expires_at>0),"Remnants retain normal item expiry")
	system.queue_free()
	await process_frame
	print("NIGHT POPULATION TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
