extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Berries = preload("res://scripts/core/berries.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.movement_blocked = false
	var ground := Vector3i(3,34,3)
	world.model.set_block(ground,"dirt")
	world.streamer.build_now(world.model.key(ground))
	world.player.position = Vector3(3.5,35,5.8)
	world.player.camera.look_at(Vector3(3.5,35,3.5))
	world.inventory.slots[27] = Registry.stack("blueberry",4)
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	world._unhandled_input(click)
	assert(Berries.at_cell(world.model,ground+Vector3i.UP).is_empty(),"Left-click must not plant")
	click.button_index = MOUSE_BUTTON_RIGHT
	world._unhandled_input(click)
	assert(not Berries.at_cell(world.model,ground+Vector3i.UP).is_empty(),"Right-click plants on dirt")
	assert(world.inventory.slots[27].count == 3 and world.berry_planting,"Plant uses one berry and blocks eating for current press")
	world.player.vitals.satiety = 50
	world.update_eating(3)
	assert(world.player.vitals.satiety == 50,"Planting must not also eat")
	click.pressed = false
	world._unhandled_input(click)
	assert(not world.berry_planting,"Release resets planting mode")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("BERRY INPUT TESTS: PASS")
	quit()
