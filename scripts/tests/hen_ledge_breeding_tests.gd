extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const Hens = preload("res://scripts/core/hens.gd")
const System = preload("res://scripts/core/entity_system.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var model := Data.new(123)
	for x in range(-3,6):
		for z in range(-3,6):
			model.set_block(Vector3i(x,34,z),"dirt")
	model.set_block(Vector3i(2,35,1),"dirt")
	var system := System.new()
	system.configure(model,"debug")
	root.add_child(system)
	Hens.create(model,"low",Vector3(1.5,35,1.5),Vector3(1.5,35,1.5),"debug")
	Hens.create(model,"high",Vector3(2.2,36,1.5),Vector3(1.5,35,1.5),"debug")
	for id: String in ["low","high"]:
		system.activate(id,model.entities[id])
		Hens.feed(model,id)
	Hens.tick(system,0)
	expect(model.entities.low.birth_at == 3,"Adjacent ledge levels start birth countdown")
	model.advance(3.1)
	Hens.tick(system,0)
	var chicks: Array = model.entities.values().filter(func(r: Dictionary) -> bool: return r.type == "hen" and not Hens.adult(r,model.game_time))
	expect(chicks.size() == 1,"Ledge pair produces exactly one chick")
	expect(model.entities.low.partner == "" and model.entities.high.partner == "", "Parents leave mating state")
	expect(not Hens.feed(model,"low") and not Hens.feed(model,"high"), "Parents reject souls immediately after successful mating")
	expect(is_equal_approx(float(model.entities.low.breed_ready_at),63.1), "Debug parents rest for exactly one minute")
	system.active.low.simulate(0)
	expect(system.active.low.resting, "Resting adult uses alternate appearance")
	var restored := Data.new(0)
	expect(restored.import_state(model.export_state()) and restored.entities.low.breed_ready_at == model.entities.low.breed_ready_at, "Rest cooldown persists in save")
	model.game_time = 63.09
	expect(not Hens.feed(model,"low"), "Cooldown does not end early")
	model.game_time = 63.1
	expect(Hens.feed(model,"low"), "Adult accepts souls after one minute")
	system.active.low.simulate(0)
	expect(not system.active.low.resting, "Ready adult restores ordinary appearance")
	expect(Hens.breeding_cooldown("play") == 180, "Play cooldown is three minutes")
	Hens.tick(system,0)
	expect(model.entities.values().filter(func(r: Dictionary) -> bool: return r.type == "hen" and not Hens.adult(r,model.game_time)).size() == 1,"No duplicate chick on next frame")
	# Only upper-level ground available: birth must search above the averaged level.
	for x in range(8,16):
		for z in range(8,16):
			model.set_block(Vector3i(x,36,z),"dirt")
	var point: Variant = Hens.birth_position(system,Vector3(11.5,36.5,11.5),Vector3(11.5,37,11.5))
	expect(point is Vector3 and point.y == 37,"Birth finds upper surface instead of only checking averaged height")
	expect(not Hens.mating_close(Vector3.ZERO,Vector3(0,2,0)),"Two-level separation is not close mating")
	system.game_mode = "play"
	Hens.feed(model,"high")
	Hens.tick(system,0)
	model.advance(3.1)
	Hens.tick(system,0)
	expect(is_equal_approx(float(model.entities.low.breed_ready_at),model.game_time + 180), "Successful play mating starts three-minute cooldown")
	model.advance(179.9)
	expect(not Hens.feed(model,"low"), "Play parents still rest just before three minutes")
	model.advance(0.11)
	expect(Hens.feed(model,"low"), "Play parents ready after three minutes")
	system.queue_free()
	await process_frame
	print("HEN LEDGE BREEDING TESTS: ","PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
