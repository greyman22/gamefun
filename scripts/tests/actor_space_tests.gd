extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const Registry = preload("res://scripts/core/registry.gd")
const Hens = preload("res://scripts/core/hens.gd")
const System = preload("res://scripts/core/entity_system.gd")
const Space = preload("res://scripts/core/actor_space.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var data := Data.new(123)
	for x in range(-5, 8):
		for z in range(-5, 8):
			data.set_block(Vector3i(x, 34, z), "dirt")
	var system := System.new()
	system.configure(data, "debug")
	root.add_child(system)
	for id: String in ["a", "b", "c"]:
		Hens.create(data, id, Vector3(1.5, 35, 1.5), Vector3(1.5, 35, 1.5), "debug", id == "c")
		system.activate(id, data.entities[id])
	data.entities.z = {"type":"zombie", "position":Vector3(1.5, 35, 1.5), "home":Vector3(1.5, 35, 1.5), "state":{}}
	system.activate("z", data.entities.z)
	for frame in range(5):
		Space.separate(system)
	for i in range(4):
		for j in range(i + 1, 4):
			var a: Node3D = system.active[["a","b","c","z"][i]]
			var b: Node3D = system.active[["a","b","c","z"][j]]
			var ra: float = Space.radius(data.entities[["a","b","c","z"][i]].type, a)
			var rb: float = Space.radius(data.entities[["a","b","c","z"][j]].type, b)
			expect(a.position.distance_to(b.position) >= ra + rb - 0.01, "Hens, chicks and zombies must occupy separate space")
	var hen: Node3D = system.active.a
	hen.position = Vector3(3.5, 35, 3.5)
	hen.step_from = hen.position
	hen.step_to = hen.position + Vector3.RIGHT
	hen.step_time = 0
	for frame in range(40):
		hen.simulate(1.0/60)
		expect(absf(hen.position.y - 35) < 0.001, "Flat-ground walking must not bounce upward")
	expect(absf(hen.legs[0].rotation.x) > 0.01, "Walking animates legs")
	hen.step_from = Vector3(3.5, 35, 3.5)
	hen.step_to = Vector3(4.5, 36, 3.5)
	hen.step_time = 0
	hen.simulate(0.3)
	expect(hen.position.y > 35.5, "Height changes still use a hop")
	var spawn: Variant = Hens.birth_position(system, Vector3(1.5, 35, 1.5), Vector3(1.5, 35, 1.5))
	expect(spawn is Vector3, "New chick finds free ground beside parents")
	if spawn is Vector3:
		for record: Dictionary in data.entities.values():
			expect(Vector2(record.position.x-spawn.x, record.position.z-spawn.z).length() >= 0.6, "Newborn avoids existing bodies")
	var player := CharacterBody3D.new()
	root.add_child(player)
	player.position = system.active.b.position
	Space.separate(system, player)
	expect(system.active.b.position.distance_to(player.position) >= 0.65, "Creatures cannot occupy player body")
	data.set_block(Vector3i(6, 35, 3), "stone")
	data.set_block(Vector3i(6, 36, 3), "stone")
	hen.step_time = 1
	hen.position = Vector3(5.65, 35, 3.5)
	player.position = Vector3(5.1, 35, 3.5)
	Space.separate(system, player)
	expect(hen.position.x < 5.8 and hen.position.distance_to(player.position) >= 0.66, "Wall-pinned hen blocks player without entering terrain")
	player.queue_free()
	system.queue_free()
	await process_frame
	print("ACTOR SPACE TESTS: ", "PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
