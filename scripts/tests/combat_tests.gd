extends SceneTree

const Combat = preload("res://scripts/core/combat.gd")
const Registry = preload("res://scripts/core/registry.gd")
const Crafting = preload("res://scripts/crafting.gd")
const Inventory = preload("res://scripts/inventory.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	Registry.initialize()
	Combat.initialize()
	var hand: Dictionary = Combat.stats("player")
	var sword: Dictionary = Combat.stats("player", "stone_sword")
	var monster: Dictionary = Combat.stats("zombie")
	expect(hand.defense == 40 and hand.attack == 10 and hand.interval == 0.5, "Player unarmed combat values must match table")
	expect(monster.defense == 30 and monster.attack == 6 and monster.interval == 1, "Zombie unarmed combat values must match table")
	expect(sword.attack == 25 and sword.interval == 0.5 and sword.defense == 40, "Stone sword must add fifteen attack and allow two hits per second")
	expect(Combat.damage(25, 30) > Combat.damage(10, 30) and Combat.damage(6, 40) < 6, "Defense must reduce damage and sword must increase it")
	Combat.definitions.actors.player.attack = 123
	expect(Combat.reload_data() and Combat.stats("player").attack == 10, "Reload button source must reread editable combat data")
	var table := Crafting.new(3)
	table.slots[0] = {"kind": "stone", "count": 1}
	table.slots[3] = {"kind": "stone", "count": 1}
	table.slots[6] = {"kind": "stick", "count": 1}
	var bag := Inventory.new()
	expect(table.recipe().get("kind") == "stone_sword" and table.craft(bag) and bag.count_item("stone_sword") == 1, "Workbench must craft a sword from stone, stone, stick vertically")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.new_world(42, "debug")
	for kind in ["axe", "pickaxe", "shovel"]:
		expect(not world.model.entities.has("starter_" + kind), "Debug worlds must not have loose starter tools")
	# Bring one existing zombie onto the flat starting terrain for actual ray hits.
	var id: String = "house_zombie_0"
	world.entity_system.deactivate(id)
	var record: Dictionary = world.model.entities[id]
	record.position = Vector3(0.5, 0, 10.5)
	record.home = record.position
	record.spawn_position = record.position
	record.state = {"health": 100, "wait": 100}
	world.entity_system.activate(id, record)
	world.player.position = Vector3(0.5, 0.05, 12.2)
	world.player.camera.look_at(Vector3(0.5, 1.4, 10.5))
	world.inventory.slots[24] = {"kind": "", "count": 0}
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	expect(world.try_attack(), "Player must hit a nearby aimed zombie through the real physics ray")
	var after_hand: float = world.entity_system.active[id].health
	expect(is_equal_approx(after_hand, 100 - Combat.damage(10, 30)) and world.attack_cooldown == 0.5, "Unarmed hit must use player attack and zombie defense")
	world.try_attack()
	expect(world.entity_system.active[id].health == after_hand, "Held attacks must respect cooldown")
	world.inventory.slots[24] = {"kind": "stone_sword", "count": 1}
	world.update_counter()
	world.attack_cooldown = 0
	world.try_attack()
	expect(is_equal_approx(world.entity_system.active[id].health, after_hand - Combat.damage(25, 30)) and world.attack_cooldown == 0.5, "Sword hit must use bonus attack and half-second cooldown")
	world.model.set_block(Vector3i(0, 1, 11), "stone")
	world.streamer.build_now(Vector3i(0, 0, 0))
	await physics_frame
	await physics_frame
	world.attack_cooldown = 0
	var before_wall: float = world.entity_system.active[id].health
	expect(not world.try_attack() and world.entity_system.active[id].health == before_wall, "Player must not strike through a block wall")
	world.model.set_block(Vector3i(0, 1, 11), "air")
	# Death is data-only while absent and persists across a save.
	world.entity_system.damage_actor(id, 1000, Combat.respawn_seconds("debug"))
	expect(not world.entity_system.active.has(id) and record.state.dead, "Dead zombie must disappear immediately")
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and world.model.entities[id].state.dead, "Dead zombie and respawn deadline must survive loading")
	world.model.advance(59.9)
	world.entity_system.respawn_zombies()
	expect(world.model.entities[id].state.dead, "Debug zombie must stay dead before sixty seconds")
	world.model.advance(0.1)
	world.entity_system.respawn_zombies()
	world.entity_system.tick(world.player.position, 1)
	expect(world.entity_system.active.has(id) and world.entity_system.active[id].health == 100, "Debug zombie must return fully healed after one minute")
	world.entity_system.damage_actor(id, 1000, Combat.respawn_seconds("play"))
	world.model.advance(179)
	world.entity_system.respawn_zombies()
	expect(world.model.entities[id].state.dead, "Play-mode zombie must stay dead before three minutes")
	world.model.advance(1)
	world.entity_system.respawn_zombies()
	expect(not world.model.entities[id].state.get("dead", false), "Play-mode zombie must return after three minutes")
	world.game_mode = "debug"
	world.toggle_combat_debug()
	expect(world.combat_debug.visible and world.player.paused, "F3 table must pause debug play")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://combat-debug-preview.png")
	world.toggle_combat_debug()
	expect(not world.combat_debug.visible and not world.player.paused and world.player.is_processing_unhandled_input(), "Closing F3 must restore play")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://stone-sword-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("COMBAT TESTS: failures=", failures)
	quit(0 if failures == 0 else 1)
