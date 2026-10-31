extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Chests = preload("res://scripts/core/chests.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.inventory.slots[27] = Registry.stack("soul_remnant", 9)
	world.inventory.slots[28] = Registry.stack("stone", 17)
	world.inventory.slots[29] = Registry.stack("axe", 1)
	world.select_hotbar(0)
	world.toggle_inventory()
	await process_frame
	await process_frame
	for index in [27,28,29]:
		Input.warp_mouse(world.inventory_slots[index].get_global_rect().get_center())
		await process_frame
		world.update_inventory_hover()
		var slot: Dictionary = world.inventory.slots[index]
		expect(world.hover_panel.visible and world.hover_label.text.contains(Registry.label(slot.kind)) and world.hover_label.text.contains(str(slot.count)), "Hover follows pointed item name and count")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://inventory-hover-preview.png")
	world.toggle_inventory()
	world.update_inventory_hover()
	expect(not world.hover_panel.visible,"Tooltip hides when inventory closes")
	var cell := Vector3i(3,35,3)
	world.model.set_block(cell,"chest")
	Chests.contents(world.model,cell)[0].merge(Registry.stack("raw_chicken",7),true)
	world.chest_ui.open(cell)
	await process_frame
	await process_frame
	Input.warp_mouse(world.chest_ui.widgets[0].get_global_rect().get_center())
	await process_frame
	world.update_inventory_hover()
	expect(world.hover_label.text.contains(Registry.label("raw_chicken")) and world.hover_label.text.contains("7"),"Chest hover follows its own item")
	world.chest_ui.close()
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("INVENTORY HOVER TESTS: ","PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
