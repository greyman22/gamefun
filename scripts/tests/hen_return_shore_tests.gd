extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Hens=preload("res://scripts/core/hens.gd")
const System=preload("res://scripts/core/entity_system.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	for chick in [false,true]:
		await check_bird(chick)
	print("HEN / CHICK RETURN TO SHORE TESTS ","PASS" if failures==0 else "FAIL: %d"%failures)
	quit(0 if failures==0 else 1)
func check_bird(chick: bool) -> void:
	var model=Data.new(42)
	for x in range(0,17):
		for z in range(0,9):
			model.set_block(Vector3i(x,34,z),"dirt")
			if x>=6 and x<=10:
				for y in range(31,35):
					model.set_block(Vector3i(x,y,z),"water_source")
	var system=System.new()
	system.configure(model,"debug")
	root.add_child(system)
	Hens.create(model,"bird",Vector3(3.5,35,4.5),Vector3(3.5,35,4.5),"debug",chick)
	system.activate("bird",model.entities.bird)
	var bird=system.active.bird
	bird.position=Vector3(8.1,35,4.5)
	bird.following_seeds=true
	bird.step_from=Vector3(7.5,35,4.5)
	bird.step_to=Vector3(9.5,35,4.5)
	bird.step_time=0.3
	# The old follow step points east, whereas the nearest bank is west.
	bird.simulate(0,null)
	expect(bird.visual.position.y<(-0.12 if chick else -0.25),"Swimming body is immersed for both life stages")
	expect(Hens.valid_home(model,bird.record.home),"Loss of attraction sets a dry home on actual land")
	expect(bird.record.home.x<6,"Nearest bank selected instead of continuing old heading")
	expect(bird.step_to.x<8.1,"Old swimming step is cancelled immediately")
	for frame in range(1000):
		bird.simulate(1.0/60,null)
	expect(not bird.swimming and Hens.valid_home(model,bird.position),"Unlured hen reaches land and does not wander back into water")
	expect(Hens.valid_home(model,bird.record.home),"Home remains dry after landing")
	var restored=Data.new()
	expect(restored.import_state(model.export_state()) and Hens.valid_home(restored,restored.entities.bird.home),"Dry home persists in save")
	# Simulate a legacy bird with a wet home and no follow transition.
	bird.position=Vector3(8.1,35,4.5)
	bird.record.home=bird.position
	bird.step_time=1
	bird.route.clear()
	bird.following_seeds=false
	for frame in range(1000):
		bird.simulate(1.0/60,null)
	expect(Hens.valid_home(model,bird.record.home) and not bird.swimming,"Existing wet home is repaired and hen seeks shore")
	system.queue_free()
	await process_frame
