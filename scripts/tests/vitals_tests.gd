extends SceneTree

const Vitals = preload("res://scripts/core/vitals.gd")
const Zombie = preload("res://scripts/zombie.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)

func run() -> void:
	var vitals := Vitals.new()
	vitals.health = 50
	vitals.satiety = 80
	vitals.tick(59)
	expect(vitals.health == 50, "Passive healing must wait a full minute")
	vitals.tick(1)
	expect(vitals.health == 55 and vitals.satiety == 80, "Passive healing must restore five percent after each minute")
	vitals = Vitals.new()
	vitals.health = 20
	vitals.tick(4.99)
	expect(vitals.health == 20 and vitals.satiety == 100, "Fed healing must wait five full seconds")
	vitals.tick(0.01)
	expect(vitals.health == 40 and vitals.satiety == 95, "First fed healing pulse must restore twenty health and cost five satiety")
	vitals.tick(5)
	expect(vitals.health == 60 and vitals.satiety == 90, "Second fed pulse must lower satiety to ninety")
	vitals.tick(49)
	expect(vitals.health == 60 and vitals.satiety == 90, "Fed healing must stop at ninety satiety")
	vitals.tick(1)
	expect(vitals.health == 65 and vitals.satiety == 90, "Passive minute pulse must continue after fed healing stops")
	vitals = Vitals.new()
	vitals.health = 40
	vitals.tick(4.5)
	var resumed := Vitals.new()
	resumed.restore(vitals.snapshot())
	resumed.tick(0.5)
	expect(resumed.health == 60 and resumed.satiety == 95, "Healing pulse timers must survive save data")
	expect(Vitals.fall_damage(2) == 0 and Vitals.fall_damage(3) == 20 and Vitals.fall_damage(4) == 40 and Vitals.fall_damage(7) == 100, "Fall damage must rise twenty percent per metre beyond two metres")
	vitals.health = 0
	vitals.tick(120)
	expect(vitals.health == 0, "Healing must not revive a dead player")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.vitals.protection = 0
	# Controlled one-block obstacle on the flat starting terrain.
	for z in range(10, 14):
		world.model.set_block(Vector3i(4, 0, z), "stone")
	var record: Dictionary = {"home": Vector3(3, 0, 12), "position": Vector3(3.5, 0, 12.5), "state": {"goal": Vector3(7.5, 0, 12.5)}}
	var zombie := Zombie.new()
	zombie.configure(world.model, record)
	zombie.position = record.position
	root.add_child(zombie)
	var hopped: bool = false
	var descended: bool = false
	var clear: bool = true
	var peak: float = 0
	for frame in range(360):
		zombie.simulate(1.0 / 60.0)
		hopped = hopped or zombie.hopping
		peak = maxf(peak, zombie.position.y)
		clear = clear and zombie.clear_at(zombie.position)
		if zombie.position.x > 5.5 and zombie.position.y < 0.05:
			descended = true
			break
	expect(hopped and peak > 1.2 and descended and clear, "Zombies must visibly hop up and down a one-block obstacle without clipping")
	# Attack range, cooldown and walls.
	zombie.hopping = false
	zombie.position = Vector3(2.5, 0, 10.5)
	world.player.position = Vector3(3.5, 0, 10.5)
	zombie.attack(world.player)
	expect(world.player.vitals.health == 100, "Zombie must visibly wind up before dealing damage")
	zombie.advance_strike(0.35, world.player)
	expect(is_equal_approx(world.player.vitals.health, 100 - 6.0 / 1.4), "Nearby zombie must damage player")
	zombie.attack(world.player)
	expect(is_equal_approx(world.player.vitals.health, 100 - 6.0 / 1.4), "Zombie cooldown must prevent damage every frame")
	zombie.attack_cooldown = 0
	zombie.strike_time = -1
	world.player.vitals.protection = 0
	world.model.set_block(Vector3i(3, 1, 10), "stone")
	zombie.attack(world.player)
	expect(is_equal_approx(world.player.vitals.health, 100 - 6.0 / 1.4), "Zombie must not attack through a solid wall")
	world.model.set_block(Vector3i(3, 1, 10), "air")
	world.player.position = Vector3(9.5, 0, 10.5)
	zombie.attack(world.player)
	expect(is_equal_approx(world.player.vitals.health, 100 - 6.0 / 1.4), "Zombie must not attack from outside reach")
	zombie.queue_free()
	# Real player fall against the generated collision surface.
	world.player.vitals.reset()
	world.player.position = Vector3(0.5, 3, 12.5)
	world.player.velocity = Vector3.ZERO
	world.player.fall_peak = 3
	world.player.airborne = true
	for frame in range(180):
		world.player._physics_process(1.0 / 60.0)
		if world.player.is_on_floor():
			break
	expect(world.player.vitals.health > 79 and world.player.vitals.health < 81, "A real three-metre landing must cause about twenty percent damage")
	# Player stats and fall tracking survive a complete session snapshot.
	world.player.vitals.health = 55
	world.player.vitals.satiety = 85
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and world.player.vitals.health == 55 and world.player.vitals.satiety == 85, "Health and satiety must persist in saves")
	world.game_mode = "debug"
	world.inventory.add_items("wood", 17)
	world.crafting.slots[0] = {"kind": "wood", "count": 2}
	world.stack_cursor.held = {"kind": "planks", "count": 4}
	var kept: int = world.inventory.count_item("wood")
	world.player.vitals.damage(1000)
	expect(world.player.vitals.health == 100 and world.player.vitals.satiety == 100 and world.player.position.distance_to(world.player.respawn_position) < 0.1, "Debug death must restore both stats and return to gathering point")
	expect(world.inventory.count_item("wood") == 0 and world.crafting.slots[0].count == 0 and world.stack_cursor.held.count == 0, "Debug death now clears carried inventory into world drops")
	world.game_mode = "play"
	world.player.vitals.damage(1000)
	var equipment: int = world.stack_cursor.held.count
	for slot in world.inventory.slots + world.crafting.slots:
		equipment += slot.count
	expect(equipment == 0 and world.player.vitals.health == 100 and world.player.vitals.satiety == 100, "Play-mode death must restore health and clear all equipment")
	if "--capture-ui" in OS.get_cmdline_user_args():
		world.player.vitals.health = 55
		world.player.vitals.satiety = 85
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://vitals-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("VITALS TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
