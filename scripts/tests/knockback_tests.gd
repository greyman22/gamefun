extends SceneTree

const Knockback = preload("res://scripts/core/knockback.gd")
const Combat = preload("res://scripts/core/combat.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	for fps in [30, 60, 144]:
		var push := Knockback.new()
		push.start(Vector3.ZERO, Vector3(1, 3, 0), 30)
		var distance := Vector3.ZERO
		for frame in range(fps):
			distance += push.step(1.0 / fps)
		expect(distance.is_equal_approx(Vector3(1.35, 0, 0)), "Thirty damage must push one hundred thirty-five centimetres, independent of frame rate")
	var push := Knockback.new()
	push.start(Vector3.ZERO, Vector3.RIGHT, 10)
	var first: Vector3 = push.step(0.09)
	var restored := Knockback.new()
	restored.restore(push.snapshot())
	expect((first + restored.step(0.09)).is_equal_approx(Vector3(0.45, 0, 0)), "Saved recoil must resume only its remaining displacement")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var id: String = "house_zombie_0"
	world.entity_system.deactivate(id)
	var record: Dictionary = world.model.entities[id]
	record.position = Vector3(0.5, 0, 10.5)
	record.home = record.position
	record.spawn_position = record.position
	record.state = {"health": 100, "wait": 100}
	world.entity_system.activate(id, record)
	var actor = world.entity_system.active[id]
	var amount: float = Combat.damage(25, 30)
	world.entity_system.damage_actor(id, amount, 60, Vector3(0.5, 0, 12.5))
	for frame in range(12):
		world.entity_system.simulate_actors(1.0 / 60.0)
		if not actor.knockback.active():
			break
	expect(absf(actor.position.z - (10.5 - amount * 0.045)) < 0.001, "A real sword hit must push the zombie about eighty-seven centimetres away from attacker")
	for y in range(3):
		world.model.set_block(Vector3i(0, y, 9), "stone")
	actor.position = Vector3(0.5, 0, 10.5)
	actor.health = 100
	world.entity_system.damage_actor(id, amount, 60, Vector3(0.5, 0, 12.5))
	for frame in range(12):
		world.entity_system.simulate_actors(1.0 / 60.0)
	expect(actor.position.z >= 10.28 and actor.position.z < 10.5 and actor.clear_at(actor.position), "A wall must stop zombie knockback without penetration")
	world.player.position = Vector3(3.5, 0.05, 12.5)
	world.player.velocity = Vector3.ZERO
	world.player.reset_fall_tracking()
	world.player.vitals.protection = 0
	world.player.receive_attack(30, Vector3(2.5, 0, 12.5))
	for frame in range(12):
		world.player._physics_process(1.0 / 60.0)
	expect(absf(world.player.position.x - 4.85) < 0.02, "Player must also move away from a hit by four and a half centimetres per actual damage")
	for y in range(3):
		world.model.set_block(Vector3i(4, y, 12), "stone")
	world.streamer.build_now(Vector3i(0, 0, 0))
	await physics_frame
	await physics_frame
	world.player.position = Vector3(3.5, 0.05, 12.5)
	world.player.velocity = Vector3.ZERO
	world.player.reset_fall_tracking()
	world.player.vitals.protection = 0
	world.player.receive_attack(30, Vector3(2.5, 0, 12.5))
	for frame in range(12):
		world.player._physics_process(1.0 / 60.0)
	expect(world.player.position.x >= 3.5 and world.player.position.x <= 3.651, "Player body collision must stop knockback at a wall")
	# Diagonal recoil must retain its free component along a wall.
	for z in range(9, 15):
		for y in range(3):
			world.model.set_block(Vector3i(4, y, z), "stone")
	world.streamer.build_now(Vector3i(0, 0, 0))
	await physics_frame
	await physics_frame
	world.player.position = Vector3(3.5, 0.05, 10.5)
	world.player.velocity = Vector3.ZERO
	world.player.reset_fall_tracking()
	world.player.vitals.reset()
	world.player.vitals.protection = 0
	world.player.receive_attack(30, Vector3(2.5, 0, 9.5))
	for frame in range(12):
		world.player._physics_process(1.0 / 60.0)
	expect(world.player.position.x <= 3.651 and world.player.position.z > 11.3, "Player must slide along wall instead of cancelling diagonal recoil")
	actor.position = Vector3(3.5, 0, 10.5)
	actor.health = 100
	actor.wait = 100
	actor.knockback.stop()
	actor.apply_knockback(Vector3(2.5, 0, 9.5), 30)
	for frame in range(12):
		actor.simulate(1.0 / 60.0)
	expect(actor.position.x <= 3.72 and actor.position.z > 11.3 and actor.clear_at(actor.position), "Zombie must slide along wall on its unblocked axis")
	# A corner blocks both horizontal axes.
	for x in range(2, 6):
		for y in range(3):
			world.model.set_block(Vector3i(x, y, 12), "stone")
	world.streamer.build_now(Vector3i(0, 0, 0))
	await physics_frame
	await physics_frame
	actor.position = Vector3(3.719, 0, 11.719)
	actor.wait = 100
	actor.knockback.stop()
	actor.apply_knockback(Vector3(2.5, 0, 10.5), 30)
	var corner: Vector3 = actor.position
	for frame in range(12):
		actor.simulate(1.0 / 60.0)
	expect(actor.position.distance_to(corner) < 0.01 and actor.clear_at(actor.position), "Zombie must stay in place when both axes are blocked by a corner")
	world.player.position = Vector3(3.649, 0.05, 11.649)
	world.player.velocity = Vector3.ZERO
	world.player.reset_fall_tracking()
	world.player.vitals.reset()
	world.player.vitals.protection = 0
	world.player.receive_attack(30, Vector3(2.5, 0, 10.5))
	corner = world.player.position
	for frame in range(12):
		world.player._physics_process(1.0 / 60.0)
	expect(Vector2(world.player.position.x - corner.x, world.player.position.z - corner.z).length() < 0.02, "Player must stay against a corner when both axes are blocked")
	world.player.knockback.start(Vector3(2.5, 0, 12.5), world.player.position, 10)
	var before: Vector3 = world.player.position
	world.player.paused = true
	world.player._physics_process(1)
	expect(world.player.position == before and world.player.knockback.active(), "Pause must freeze knockback without consuming displacement")
	world.player.paused = false
	var saved: Dictionary = world.snapshot()
	var remaining: Vector3 = world.player.knockback.remaining
	expect(world.restore_snapshot(saved) and world.player.knockback.remaining == remaining, "Player knockback must survive a complete save snapshot")
	world.player.knockback.stop()
	world.player.vitals.protection = 0
	world.player.vitals.health = 5
	world.player.receive_attack(10, Vector3(2.5, 0, 12.5))
	expect(world.player.vitals.health == 100 and not world.player.knockback.active(), "A lethal hit must not push the player after respawning")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("KNOCKBACK TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
