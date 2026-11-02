extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Hens=preload("res://scripts/core/hens.gd")
const System=preload("res://scripts/core/entity_system.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	for count in [1,3]:
		var model=Data.new(42)
		for x in range(-2,31):
			for z in range(-2,14):
				model.set_block(Vector3i(x,34,z),"dirt")
		var system=System.new()
		system.configure(model,"debug")
		root.add_child(system)
		var player:=CharacterBody3D.new()
		root.add_child(player)
		for i in range(count):
			var id: String="test_%d"%i
			Hens.create(model,id,Vector3(2.5+i*0.2,35,2.5),Vector3(4.5,35,4.5),"debug",false)
			system.activate(id,model.entities[id])
		for target in [Vector3(7.8,35,3.2),Vector3(10.2,35,6.8),Vector3(6.2,35,9.2),Vector3(8.8,35,5.8),Vector3(16.5,35,5.5),Vector3(23.5,35,5.5),Vector3(26.5,35,5.5)]:
			player.position=target
			system.seed_lure=target
			for frame in range(360):
				system.simulate_actors(1.0/60,player)
			for id in system.active:
				var bird=system.active[id]
				expect(bird.position.distance_to(target)<2.5,"Every hen keeps following when the player moves")
			for i in range(count):
				for j in range(i+1,count):
					expect(system.active["test_%d"%i].position.distance_to(system.active["test_%d"%j].position)>0.65,"Following hens remain separated")
		var relocated: Dictionary={}
		for id in system.active:
			relocated[id]=system.active[id].position
		system.seed_lure=null
		system.simulate_actors(1.0/60,player)
		for id in system.active:
			expect(system.active[id].record.home.distance_to(relocated[id])<0.1,"Lured hen adopts its new home when attraction ends")
		system.snapshot_active()
		var restored=Data.new()
		expect(restored.import_state(model.export_state()),"Relocated hens save/load")
		for id in system.active:
			expect(restored.entities[id].home==system.active[id].record.home,"New home position persists")
		for frame in range(1200):
			system.simulate_actors(1.0/60,player)
		for id in system.active:
			var bird=system.active[id]
			expect(Vector2(bird.position.x-bird.record.home.x,bird.position.z-bird.record.home.z).length()<=20.1,"Hens stay within twenty metres of their new home")
		# Even within one voxel, a diagonal offset can exceed the stopping radius.
		var solo=system.active.test_0
		solo.position=Vector3(3.02,35,3.02)
		solo.step_time=1
		solo.route.clear()
		player.position=Vector3(3.98,35,3.98)
		system.seed_lure=player.position
		for frame in range(120):
			system.simulate_actors(1.0/60,player)
		expect(solo.position.distance_to(player.position)<1.25,"Hen approaches within the same voxel")
		player.queue_free()
		system.queue_free()
		await process_frame
	print("HEN FOLLOW STALL TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
