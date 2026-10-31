extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const System = preload("res://scripts/core/entity_system.gd")
const Inventory = preload("res://scripts/inventory.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var model := Data.new(123)
	var system := System.new()
	system.configure(model)
	root.add_child(system)
	model.set_block(Vector3i(2, 35, 2), "dirt")
	var player := Vector3(1.7, 35, 2.1)
	for point: Vector3 in [Vector3(2.1, 36.125, 2.1),Vector3(2.85, 36.125, 2.85),Vector3(2.15, 36.125, 2.85)]:
		var id: String = system.spawn_drop("stone", point, 3)
		model.entities[id].state.grounded = true
		system.activate(id, model.entities[id])
	model.game_time = 1
	var bag := Inventory.new()
	expect(system.collect(player, bag) and bag.count_item("stone") == 9, "All stacks across neighbouring block top collect")
	var record := {"position":Vector3(2.85,36.125,2.85), "state":{"grounded":true}}
	expect(not system.within_pickup_reach(Vector3(0.8,35,2.1),record), "Player must stand right beside support block")
	record.state.grounded = false
	expect(not system.within_pickup_reach(player,record), "Extended block reach requires landed item")
	model.set_block(Vector3i(2, 37, 2), "stone")
	record = {"position":Vector3(2.85,38.125,2.85), "state":{"grounded":true}}
	expect(not system.within_pickup_reach(player,record), "Items several blocks overhead stay out of reach")
	system.queue_free()
	await process_frame
	print("PICKUP REACH TESTS: ", "PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
