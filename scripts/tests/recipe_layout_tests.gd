extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func shown(world: Node) -> Array[String]:
	var kinds: Array[String]=[]
	for entry in world.template_buttons:
		if entry.button.visible:
			kinds.append(entry.recipe.kind)
	return kinds
func run() -> void:
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.player.paused=false
	world.toggle_inventory(true)
	await process_frame
	await process_frame
	expect(world.recipe_grid.columns==4,"Recipes use four icon columns")
	expect(world.recipe_tabs.size()==5 and not world.recipe_tabs[3].disabled and world.recipe_tabs[4].disabled,"Five tabs including Food and one reserved")
	var left: Rect2=world.recipe_panel.get_global_rect()
	var right: Rect2=world.work_panel.get_global_rect()
	expect(left.end.x<=right.position.x and absf(left.size.x-right.size.x)<50,"Recipe panel on left and work panel on right have roughly equal width")
	expect(world.inventory_panel.get_global_rect().end.x<=root.get_visible_rect().size.x and world.inventory_panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"Dialog fits screen")
	var original_grid=world.crafting
	var expanded_width: float=world.inventory_panel.size.x
	world.recipe_toggle.button_pressed=false
	await process_frame
	await process_frame
	expect(not world.recipe_panel.visible and world.recipe_toggle.text=="Visa recept","Toggle hides only recipe panel")
	expect(world.work_panel.visible and world.crafting==original_grid and world.inventory_panel.size.x<expanded_width,"Collapsed dialog retains work and inventory in a narrower panel")
	world.toggle_inventory()
	world.toggle_inventory(true)
	expect(not world.recipe_panel.visible,"Recipe visibility survives closing and reopening dialog")
	world.recipe_toggle.button_pressed=true
	await process_frame
	await process_frame
	expect(world.recipe_panel.visible and world.recipe_toggle.text=="D\u00f6lj recept","Toggle restores browser")
	var extra: Array[Button]=[]
	for i in range(20):
		var button:=Button.new()
		button.custom_minimum_size=Vector2(96,80)
		world.recipe_grid.add_child(button)
		extra.append(button)
	await process_frame
	await process_frame
	expect(world.recipe_scroll.get_v_scroll_bar().max_value>world.recipe_scroll.size.y,"Recipe grid scrolls when more rows are added")
	world.recipe_scroll.scroll_vertical=10000
	await process_frame
	expect(extra[-1].get_global_rect().intersects(world.recipe_scroll.get_global_rect()),"Last icon in long recipe grid remains reachable")
	for button in extra:
		world.recipe_grid.remove_child(button)
		button.queue_free()
	world.recipe_scroll.scroll_vertical=0
	world.select_recipe_category("tools")
	expect(not shown(world).is_empty(),"Tools tab has entries")
	for kind in shown(world):
		expect(Registry.tool(kind),"Tools tab excludes materials")
	world.select_recipe_category("materials")
	for kind in shown(world):
		expect(not Registry.tool(kind) and kind!="bread","Material tab excludes tools and food")
	world.select_recipe_category("food")
	expect(shown(world)==["bread"],"Food category includes bread")
	var classified: Dictionary={}
	for category in ["tools","materials","food"]:
		world.select_recipe_category(category)
		for kind in shown(world):
			classified[kind]=true
	world.select_recipe_category("all")
	for entry in world.template_buttons:
		expect(classified.has(entry.recipe.kind),"Every recipe belongs to a named category")
		expect(entry.button.get_child(0).texture==world.item_icons[entry.recipe.kind],"Every recipe icon depicts its output item")
	expect(world.recipe_search.get_parent()==world.recipe_available.get_parent(),"Search and availability filter share a row")
	world.filter_recipes("br\u00f6d")
	expect(shown(world)==["bread"],"Search combines with all category")
	world.filter_recipes("")
	for slot in world.inventory.slots:
		slot.kind=""
		slot.count=0
	world.recipe_available.button_pressed=true
	world.update_counter()
	expect(shown(world).is_empty() and world.recipe_empty.visible,"Availability filter hides recipes without ingredients")
	world.inventory.add_items("wood",1)
	world.update_counter()
	expect(shown(world)==["planks"],"Availability filter updates when resources arrive")
	world.inventory.add_items("grain",3)
	world.update_counter()
	expect(shown(world).has("bread"),"Workbench-only recipe available in 3x3")
	world.toggle_inventory()
	world.toggle_inventory(false)
	world.update_counter()
	expect(not shown(world).has("bread"),"Availability respects 2x2 work surface")
	world.toggle_inventory()
	world.toggle_inventory(true)
	world.recipe_available.button_pressed=false
	world.filter_recipes("")
	for kind in ["stone","stick","planks","soul_remnant"]:
		world.inventory.add_items(kind,64)
	world.update_counter()
	for entry in world.template_buttons:
		if entry.recipe.kind=="hoe":
			entry.button.pressed.emit()
	expect(world.crafting.recipe().get("kind","")=="hoe" and world.crafting.slots[0].count==0,"Icon recipe still fills shifted hoe template")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://workbench-recipes-preview.png")
		world.toggle_inventory()
		world.toggle_inventory(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://inventory-recipes-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("RECIPE LAYOUT TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
