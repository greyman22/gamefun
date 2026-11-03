extends SceneTree
const Hens=preload("res://scripts/core/hens.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	seed(12345)
	var world=load("res://scripts/world.gd").new()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.streamer.shutdown()
	for id: String in world.entity_system.active.keys():
		world.entity_system.deactivate(id)
	world.model.entities.clear()
	for x in range(-20,21):
		for z in range(-20,21):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	world.player.position=Vector3(0.5,35,0.5)
	for i in range(36):
		var p:=Vector3((i%6)*1.2-3,35,(i/6)*1.2-3)
		Hens.create(world.model,"bench_%d"%i,p,p,"debug",false,"hen" if i%2==0 else "sheep")
		world.entity_system.activate("bench_%d"%i,world.model.entities["bench_%d"%i])
	world.PerfLog.start()
	var times: Array[float]=[]
	for frame in range(600):
		world.model.game_time+=1.0/60
		world.player.position=Vector3(sin(frame/100.0)*6,35,cos(frame/100.0)*6)
		world.entity_system.seed_lure=world.player.position
		world.entity_system.grain_lure=world.player.position
		var stamp: int=Time.get_ticks_usec()
		world.entity_system.simulate_actors(1.0/60,world.player)
		times.append((Time.get_ticks_usec()-stamp)/1000.0)
	var path: String=world.PerfLog.stop()
	times.sort()
	var total: float=0
	for t in times:
		total+=t
	print("CREATURE BENCHMARK mean_ms=",total/600," p95_ms=",times[569]," max_ms=",times[-1]," report=",path)
	world.queue_free()
	await process_frame
	quit()
