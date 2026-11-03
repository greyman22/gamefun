extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Generator=preload("res://scripts/core/generator.gd")
const Budget=preload("res://scripts/core/ai_budget.gd")
const Access=preload("res://scripts/core/pursuit_access.gd")
const Hens=preload("res://scripts/core/hens.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Streamer=preload("res://scripts/rendering/streamer.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var budget=Budget.new()
	budget.max_searches=1
	budget.time_budget_usec=1000000
	budget.begin_frame(0.1)
	expect(budget.request("near",20) and not budget.request("far",0),"Search count is bounded per frame")
	var served: bool=false
	for frame in range(12):
		budget.begin_frame(0.1)
		budget.request("near",20)
		served=budget.request("far",0) or served
	expect(served,"Waiting distant creatures eventually receive search time")
	# Single-voxel AI reads must match full generated chunks, including edits.
	for version in [1,3,4,5]:
		var data=Data.new(42)
		data.generator=Generator.new(42,version)
		for key in [Vector3i.ZERO,Vector3i(-2,0,1),Vector3i(2,0,2)]:
			var full: PackedByteArray=data.generator.generate(key)
			for i in range(0,4096,37):
				var cell: Vector3i=key*16+Vector3i(i%16,(i/16)%16,i/256)
				expect(data.sample_block(cell)==full.decode_u16(i*2),"Point probes match full voxel generation")
		expect(data.cache.is_empty(),"AI point probes do not allocate decoded terrain chunks")
		data.set_block(Vector3i(0,2,0),"planks")
		expect(data.sample_kind(Vector3i(0,2,0))=="planks","Point probes honor player edits")
	var model=Data.new(42)
	for x in range(-8,9):
		for z in range(-8,9):
			model.set_block(Vector3i(x,34,z),"dirt")
	var system=System.new()
	system.configure(model,"debug")
	root.add_child(system)
	Hens.create(model,"resting",Vector3(0.5,35,0.5),Vector3(0.5,35,0.5),"debug")
	system.activate("resting",model.entities.resting)
	var bird=system.active.resting
	var idle_frames: int=0
	var moving_frames: int=0
	for frame in range(1200):
		model.game_time+=1.0/60
		system.simulate_actors(1.0/60)
		if bird.idling:
			idle_frames+=1
		else:
			moving_frames+=1
	var fraction: float=float(idle_frames)/1200
	print("IDLE FRACTION ",fraction)
	expect(fraction>0.3 and fraction<0.46,"Ordinary wandering includes approximately forty percent rest")
	model.game_time=10-bird.rest_offset+1
	bird.step_time=1
	system.seed_lure=bird.position+Vector3(3,0,0)
	system.simulate_actors(1.0/60)
	expect(not bird.idling and bird.following_seeds,"Lure immediately overrides rest")
	bird.apply_knockback(bird.position+Vector3(0,0,1),1)
	system.simulate_actors(1.0/60)
	expect(not bird.idling,"Danger overrides rest")
	# A sliced reachability search must eventually prove a closed room is safe.
	for x in range(0,6):
		for z in range(0,6):
			if x in [0,5] or z in [0,5]:
				for y in range(35,38):
					model.set_block(Vector3i(x,y,z),"stone")
	var access=Access.new()
	access.configure(model)
	access.budget=Budget.new()
	var safe: bool=false
	for frame in range(80):
		model.game_time+=0.1
		access.budget.begin_frame(0.1,model.game_time)
		safe=not access.allowed(Vector3(7.5,35,2.5),Vector3(2.5,35,2.5))
		if safe:
			break
	expect(safe,"Sliced searches still detect protected interiors")
	model.set_block(Vector3i(5,35,2),"air")
	model.set_block(Vector3i(5,36,2),"air")
	model.game_time+=1
	access.budget.begin_frame(0.1,model.game_time)
	expect(access.allowed(Vector3(7.5,35,2.5),Vector3(2.5,35,2.5)),"Opening a wall invalidates shelter cache")
	var streamer=Streamer.new()
	streamer.configure(model)
	root.add_child(streamer)
	streamer.view_distance=48
	streamer.view_forward=Vector3.RIGHT
	streamer.warm_start(Vector3(0.5,35,0.5))
	var anchor: Vector3=streamer.desired_anchor
	streamer.tick(Vector3(0.6,35,0.5),0.5)
	expect(streamer.desired_anchor==anchor,"Standing or tiny movement does not repeatedly rebuild the desired terrain set")
	streamer.refresh_desired(Vector3(200,35,200))
	var before: int=streamer.chunks.size()
	streamer.tick(Vector3(200,35,200),0.01)
	expect(before-streamer.chunks.size()<=4 and streamer.last_installs<=1,"Terrain maintenance and mesh installs are spread over frames")
	for frame in range(16):
		streamer.tick(Vector3(200,35,200),0.016)
	expect(streamer.chunks.size()<before,"Deferred unloads eventually complete")
	streamer.shutdown()
	streamer.queue_free()
	system.queue_free()
	await process_frame
	print("PERFORMANCE SCHEDULING TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
