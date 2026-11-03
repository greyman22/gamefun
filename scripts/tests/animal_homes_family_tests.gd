extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Hens=preload("res://scripts/core/hens.gd")
const Homes=preload("res://scripts/core/animal_homes.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var model=Data.new(42)
	for x in range(-12,49):
		for z in range(-12,41):
			model.set_block(Vector3i(x,34,z),"dirt")
			if x<9:
				model.set_block(Vector3i(x,33,z),"water_source")
				model.set_block(Vector3i(x,34,z),"water_source")
	var system=System.new()
	system.configure(model,"debug")
	root.add_child(system)
	for i in range(3):
		var id: String="shore_hen_%d"%i
		Hens.create(model,id,Vector3(8.2,35,5+i*0.3),Vector3(-80,35,0),"debug")
		system.activate(id,model.entities[id])
		system.active[id].following_seeds=true
	for frame in range(180):
		model.game_time+=1.0/60
		system.simulate_actors(1.0/60)
	for i in range(3):
		var a: Dictionary=model.entities["shore_hen_%d"%i]
		expect(not a.has("home_request") and Hens.valid_home(model,a.home),"Released flock gets dry homes")
		expect(Homes.inland(model,a.home) and a.home.x>=12,"Several hens settle inland beyond the shoreline")
		for j in range(i+1,3):
			expect(a.home.distance_to(model.entities["shore_hen_%d"%j].home)>=Homes.spacing("hen"),"New hen homes are separated like natural spawn homes")
	for i in range(3):
		var id: String="moved_sheep_%d"%i
		Hens.create(model,id,Vector3(25+i*0.3,35,20),Vector3(-100,35,20),"debug",false,"sheep")
		system.activate(id,model.entities[id])
		system.active[id].following_seeds=true
	for frame in range(180):
		model.game_time+=1.0/60
		system.simulate_actors(1.0/60)
	for i in range(3):
		var a: Dictionary=model.entities["moved_sheep_%d"%i]
		expect(not a.has("home_request"),"Sheep finish choosing their separated homes")
		for j in range(i+1,3):
			expect(a.home.distance_to(model.entities["moved_sheep_%d"%j].home)>=10,"Relocated sheep homes remain ten metres apart")
	var saved: Dictionary=model.export_state()
	var restored=Data.new()
	expect(restored.import_state(saved) and restored.entities.moved_sheep_0.home==model.entities.moved_sheep_0.home,"New homes persist in saves")
	system.queue_free()
	await process_frame
	for species in ["hen","sheep"]:
		var family=Data.new(42)
		for x in range(0,25):
			for z in range(0,7):
				family.set_block(Vector3i(x,34,z),"dirt")
		var actors=System.new()
		actors.configure(family,"debug")
		root.add_child(actors)
		Hens.create(family,"adult",Vector3(7.5,35,3.5),Vector3(7.5,35,3.5),"debug",false,species)
		Hens.create(family,"young",Vector3(1.5,35,3.5),Vector3(-100,35,3.5),"debug",true,species)
		actors.activate("adult",family.entities.adult)
		actors.activate("young",family.entities.young)
		for frame in range(240):
			family.game_time+=1.0/60
			# Hold the adult still while the youngster approaches without player bait.
			Hens.tick(actors,1.0/60,species)
			actors.active.adult.position=Vector3(7.5,35,3.5)
			actors.active.adult.step_time=1
			family.entities.adult.position=Vector3(7.5,35,3.5)
		expect(actors.active.young.family_leader=="adult" and actors.active.young.position.distance_to(family.entities.adult.position)<2.5,"Young animal finds and follows an adult of its own species")
		actors.deactivate("adult")
		family.entities.erase("adult")
		for frame in range(35):
			family.game_time+=1.0/60
			Hens.tick(actors,1.0/60,species)
		expect(not actors.active.young.family_following,"Losing the adult clears the follow target safely")
		family.entities.young.adult_at=family.game_time
		Hens.tick(actors,0,species)
		expect(not actors.active.young.family_following and not actors.active.young.chick,"Growing up ends juvenile follow mode")
		actors.queue_free()
		await process_frame
	print("ANIMAL HOMES AND FAMILY TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
