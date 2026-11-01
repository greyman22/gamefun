extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const Hens = preload("res://scripts/core/hens.gd")
const Hen = preload("res://scripts/hen.gd")
const Navigation = preload("res://scripts/core/zombie_navigation.gd")
const Space = preload("res://scripts/core/actor_space.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var data := Data.new()
	for x in range(0,8):
		for z in range(0,8):
			data.set_block(Vector3i(x,34,z),"dirt")
	data.set_block(Vector3i(3,42,3),"planks")
	var start := Vector3(3.5,43,3.5)
	var target := Vector3(4.5,35,3.5)
	var nav := Navigation.new()
	nav.model=data
	expect(nav.path(start,target).is_empty(),"Ordinary navigation cannot descend an eight-metre ledge")
	nav.max_drop=8
	expect(not nav.path(start,target).is_empty() and nav.reached,"Hen navigation finds landing eight metres below")
	Hens.create(data,"flyer",start,Vector3(3.5,35,3.5),"debug")
	var hen := Hen.new()
	hen.configure(data,data.entities.flyer)
	hen.position=start
	root.add_child(hen)
	hen.simulate(0.01,target)
	expect(hen.gliding and hen.step_to.y==35,"Hen chooses to leave roof and glide")
	var elapsed: float = 0
	var preserved: bool = false
	for frame in range(450):
		data.advance(1.0/60)
		hen.simulate(1.0/60,target)
		elapsed+=1.0/60
		expect(Space.clear(data,hen.position,0.25,0.9),"Glide clears roof edge and solid terrain")
		if frame==60:
			expect(hen.position.y>41,"Hen floats rather than dropping like a stone")
			data.entities.flyer.position=hen.position
			data.entities.flyer.state=hen.serialize_state()
			var imported := Data.new()
			expect(imported.import_state(data.export_state()),"Mid-glide state saves")
			var restored := Hen.new()
			restored.configure(imported,imported.entities.flyer)
			expect(restored.gliding and is_equal_approx(restored.step_time,hen.step_time),"Mid-glide animation restores")
			restored.free()
			preserved=true
		expect(hen.health==24,"Gliding does not damage hen")
		expect(hen.position.y>=35-0.001,"Hen never sinks under landing surface")
	expect(preserved and absf(hen.position.y-35)<0.01,"Hen lands safely on ground")
	expect(not hen.gliding,"Gliding ends after landing")
	data.set_block(Vector3i(3,43,3),"planks")
	expect(nav.path(Vector3(3.5,44,3.5),target).is_empty(),"Hen does not choose drops higher than eight metres")
	hen.queue_free()
	await process_frame
	print("HEN GLIDE TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
