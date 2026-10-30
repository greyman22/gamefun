extends "res://scripts/game_ui.gd"

const WorldData = preload("res://scripts/core/world_data.gd")
const Generator = preload("res://scripts/core/generator.gd")
const Streamer = preload("res://scripts/rendering/streamer.gd")
const Entities = preload("res://scripts/core/entity_system.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const PlayerScript = preload("res://scripts/player.gd")
var model: RefCounted
var streamer: Node3D
var entity_system: Node3D
var testing: bool = false
var view_distance: int = 96
var autosave_elapsed: float = 0
var target_cell := Vector3i(0, -1000, 0)
var build_cell := Vector3i.ZERO
var target_point := Vector3.ZERO
var target_normal := Vector3.UP
var can_build: bool = false
var pause_panel: PanelContainer
var world_selector: OptionButton
var distance_selector: OptionButton
var menu_caption: Label
var seed_input: LineEdit
var status: Label
var status_time: float = 0
var menu_was_visible: bool = false

func _ready() -> void:
	Registry.initialize()
	for kind: String in Registry.catalog.blocks:
		if kind == "air":
			continue
		var base := Color(Registry.catalog.blocks[kind].color)
		item_materials[kind] = make_material(base, 0.12, Color(0.55, 0.55, 0.55))
	for kind: String in Registry.catalog.items:
		item_icons[kind] = ItemVisuals.icon(kind)
	block_dirt = item_materials.dirt
	block_grass = make_material(Color(0.36, 0.6, 0.2), 0.15, Color(0.5, 0.65, 0.4))
	create_lighting()
	player = PlayerScript.new()
	add_child(player)
	build_outline()
	build_ui()
	build_pause_menu()
	var loaded: bool = false
	if not testing:
		var id: String = SaveStore.last_id()
		if not id.is_empty():
			loaded = restore_snapshot(SaveStore.load_world(id))
	if not loaded:
		new_world(20261030 if testing else int(randi()))
		if not testing:
			save_game(false)
	if not testing:
		get_tree().auto_accept_quit = false

func create_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.57, 0.78, 0.93)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.9, 1)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.57, 0.78, 0.93)
	environment.fog_density = 0.002
	sky.environment = environment
	add_child(sky)

func install_model(data: RefCounted, position: Vector3) -> void:
	if is_instance_valid(streamer):
		streamer.shutdown()
		remove_child(streamer)
		streamer.queue_free()
	if is_instance_valid(entity_system):
		remove_child(entity_system)
		entity_system.queue_free()
	model = data
	streamer = Streamer.new()
	streamer.configure(model)
	streamer.view_distance = view_distance
	add_child(streamer)
	entity_system = Entities.new()
	entity_system.configure(model)
	add_child(entity_system)
	player.position = position
	player.velocity = Vector3.ZERO
	player.respawn_position = Vector3(0, model.generator.height(0, 12) + 0.05, 12)
	player.bounds_radius = Generator.HALF_WORLD - 1.0
	player.bottom_y = Generator.MIN_Y
	player.camera.far = view_distance + 16
	player.movement_blocked = true
	streamer.warm_start(position)
	entity_system.tick(position, 1)
	player.movement_blocked = false
	player.paused = false
	player.inventory_open = false
	inventory_panel.visible = false
	prompt.visible = true
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	reset_mining()
	autosave_elapsed = 0

func new_world(seed_value: int) -> void:
	stack_cursor.reset()
	var data := WorldData.new(seed_value)
	for index in range(3):
		var kind: String = ItemVisuals.TOOL_KINDS[index]
		data.entities["starter_" + kind] = {"type": "pickup", "kind": kind, "position": Vector3(-2 + index * 2, data.generator.height(-2 + index * 2, 10) + 0.4, 9 if index == 1 else 10), "state": {}}
	inventory = InventoryScript.new()
	inventory.add_items("dirt", 32)
	inventory.add_items("torch", 8)
	crafting = CraftingScript.new()
	rebuild_crafting_slots()
	selected_hotbar = 0
	install_model(data, Vector3(0, data.generator.height(0, 12) + 0.05, 12))
	held_kind = "uninitialized"
	update_counter()

func snapshot() -> Dictionary:
	entity_system.snapshot_active()
	return {"world": model.export_state(), "player": {"position": player.position, "rotation": player.rotation, "camera": player.camera.rotation, "velocity": player.velocity}, "inventory": inventory.slots.duplicate(true), "crafting": {"width": crafting.width, "slots": crafting.slots.duplicate(true), "open": player.inventory_open}, "cursor": stack_cursor.held.duplicate(), "selected": selected_hotbar, "view_distance": view_distance}

func valid_slots(slots: Variant, expected: int) -> bool:
	if not slots is Array or slots.size() != expected:
		return false
	for slot: Variant in slots:
		if not slot is Dictionary or not slot.has_all(["kind", "count"]):
			return false
		if not slot.kind is String or slot.count < 0 or slot.count > Registry.stack_limit(slot.kind):
			return false
		if slot.count > 0 and not Registry.catalog.items.has(slot.kind):
			return false
	return true

func restore_snapshot(saved: Dictionary) -> bool:
	if not saved.has_all(["world", "player", "inventory", "crafting", "selected"]):
		return false
	var width: int = int(saved.crafting.get("width", 0))
	if width not in [2, 3] or not valid_slots(saved.inventory, 32) or not valid_slots(saved.crafting.get("slots"), width * width):
		return false
	if not saved.player.get("position") is Vector3:
		return false
	var held: Dictionary = saved.get("cursor", {"kind": "", "count": 0})
	if not valid_slots([held], 1):
		return false
	var data := WorldData.new()
	if not data.import_state(saved.world):
		return false
	view_distance = clampi(int(saved.get("view_distance", 96)), 32, 192)
	inventory = InventoryScript.new()
	inventory.slots.assign(saved.inventory.duplicate(true))
	crafting = CraftingScript.new(width)
	crafting.slots.assign(saved.crafting.slots.duplicate(true))
	rebuild_crafting_slots()
	selected_hotbar = clampi(int(saved.selected), 0, 7)
	install_model(data, saved.player.position)
	player.rotation = saved.player.get("rotation", Vector3.ZERO)
	player.camera.rotation = saved.player.get("camera", Vector3.ZERO)
	player.velocity = saved.player.get("velocity", Vector3.ZERO)
	stack_cursor.reset()
	stack_cursor.held = held.duplicate()
	held_kind = "uninitialized"
	if saved.crafting.get("open", false) or held.count > 0 or crafting.slots.any(func(slot: Dictionary) -> bool: return slot.count > 0):
		player.inventory_open = true
		inventory_panel.visible = true
		prompt.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_counter()
	return true

func save_game(show_message: bool = true) -> bool:
	if testing:
		return false
	var error: Error = SaveStore.save(snapshot())
	if show_message or error != OK:
		message("Världen är sparad" if error == OK else "Kunde inte spara: " + error_string(error))
	return error == OK

func load_game(id: String) -> bool:
	var saved: Dictionary = SaveStore.load_world(id)
	if saved.is_empty() or not restore_snapshot(saved):
		message("Kunde inte läsa världen. Nuvarande spel finns kvar.")
		return false
	message("Världen är laddad")
	return true

func build_pause_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 3
	add_child(canvas)
	status = label("", 18)
	status.position = Vector2(24, 18)
	canvas.add_child(status)
	pause_panel = PanelContainer.new()
	canvas.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -230
	pause_panel.offset_right = 230
	pause_panel.offset_top = -290
	pause_panel.offset_bottom = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.12, 0.1, 0.98)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	pause_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	pause_panel.add_child(column)
	column.add_child(label("PAUS", 28))
	menu_caption = label("", 16)
	column.add_child(menu_caption)
	menu_button(column, "Fortsätt", func() -> void: resume_game())
	menu_button(column, "Spara världen", func() -> void: save_game())
	world_selector = OptionButton.new()
	column.add_child(world_selector)
	menu_button(column, "Ladda vald värld", func() -> void:
		if world_selector.selected >= 0:
			load_game(world_selector.get_item_metadata(world_selector.selected)))
	column.add_child(label("Seed för ny värld (valfritt)", 15))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Lämna tomt för slumpad värld"
	column.add_child(seed_input)
	menu_button(column, "Skapa ny värld", func() -> void:
		var text_value: String = seed_input.text.strip_edges()
		if not text_value.is_empty() and not text_value.is_valid_int():
			message("Seed behöver vara ett heltal")
			return
		var value: int = int(randi()) if text_value.is_empty() else clampi(int(text_value), -2147483647, 2147483647)
		if save_game(false):
			new_world(value)
			save_game(false))
	column.add_child(label("Siktavstånd", 17))
	distance_selector = OptionButton.new()
	for distance in [48, 64, 96, 128, 192]:
		distance_selector.add_item("%d meter" % distance, distance)
	distance_selector.item_selected.connect(func(index: int) -> void:
		view_distance = distance_selector.get_item_id(index)
		streamer.view_distance = view_distance
		streamer.refresh_desired(player.position)
		player.camera.far = view_distance + 16)
	column.add_child(distance_selector)
	menu_button(column, "Spara och avsluta", func() -> void:
		if save_game(false):
			streamer.shutdown()
			get_tree().quit())
	column.add_child(label("Sparas automatiskt var 30:e sekund", 15))
	pause_panel.visible = false

func menu_button(parent: Control, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)

func refresh_world_list() -> void:
	menu_caption.text = "Seed: %d" % model.seed_value
	world_selector.clear()
	for entry: Dictionary in SaveStore.worlds():
		var index: int = world_selector.item_count
		world_selector.add_item("Seed %d" % entry.seed)
		world_selector.set_item_metadata(index, entry.id)
		if entry.id == model.world_id:
			world_selector.select(index)
	for index in range(distance_selector.item_count):
		if distance_selector.get_item_id(index) == view_distance:
			distance_selector.select(index)

func resume_game() -> void:
	player.paused = false
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func message(text_value: String) -> void:
	status.text = text_value
	status_time = 4

func _process(delta: float) -> void:
	if model == null:
		return
	update_cursor_visual()
	streamer.tick(player.position, delta)
	entity_system.tick(player.position, delta)
	var predicted: Vector3 = player.position + Vector3(player.velocity.x, 0, player.velocity.z) * 0.25
	player.movement_blocked = not streamer.ready_at(player.position) or not streamer.ready_at(predicted)
	var visible_menu: bool = player.paused and not player.inventory_open
	pause_panel.visible = visible_menu
	if visible_menu and not menu_was_visible:
		refresh_world_list()
	menu_was_visible = visible_menu
	status_time = maxf(0, status_time - delta)
	status.visible = status_time > 0

func _physics_process(delta: float) -> void:
	if model == null:
		return
	can_build = false
	preview.visible = false
	if player.paused or player.inventory_open or player.movement_blocked:
		mining_held = false
		reset_mining()
		prompt.text = "Förbereder området…" if player.movement_blocked else ""
		return
	model.advance(delta)
	entity_system.simulate_drops(delta)
	if entity_system.collect(player.position, inventory):
		update_counter()
	update_build_preview()
	update_mining(delta)
	if model.kind_at(target_cell) == "workbench":
		prompt.text = "Höger: öppna arbetsbänk • Håll vänster: ta bort"
	elif can_build:
		prompt.text = "Valt: %s • Höger: placera • Håll vänster: bearbeta" % Registry.label(selected_kind())
	else:
		prompt.text = "E: föremål • Esc: spara, ladda och siktavstånd"
	if not testing:
		autosave_elapsed += delta
		if autosave_elapsed >= 30:
			autosave_elapsed = 0
			save_game(false)

func valid_build_cell(cell: Vector3i) -> bool:
	if absi(cell.x) >= Generator.HALF_WORLD - 1 or absi(cell.z) >= Generator.HALF_WORLD - 1 or cell.y < Generator.MIN_Y or cell.y > Generator.MAX_Y:
		return false
	if model.block(cell) != 0:
		return false
	var center := Vector3(cell) + Vector3.ONE * 0.5
	var feet: Vector3 = player.position
	return not (absf(center.x - feet.x) < 0.86 and absf(center.z - feet.z) < 0.86 and center.y + 0.5 > feet.y and center.y - 0.5 < feet.y + 1.8)

func torch_position(cell: Vector3i, point: Vector3, normal: Vector3) -> Vector3:
	return point + normal * 0.07 if absf(normal.y) < 0.5 else Vector3(cell) + Vector3(0.5, 0.3, 0.5)

func valid_torch_cell(cell: Vector3i, point: Vector3, normal: Vector3) -> bool:
	if model.block(cell) != 0 or cell.y < Generator.MIN_Y or cell.y > Generator.MAX_Y:
		return false
	var center := torch_position(cell, point, normal)
	var feet: Vector3 = player.position
	return not (absf(center.x - feet.x) < 0.41 and absf(center.z - feet.z) < 0.41 and center.y + 0.3 > feet.y and center.y - 0.3 < feet.y + 1.8)

func update_build_preview() -> void:
	target_cell = Vector3i(0, -1000, 0)
	can_build = false
	preview.visible = false
	var start: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - player.camera.global_transform.basis.z * 6, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("build_surface"):
		return
	target_point = hit.position
	target_normal = hit.normal
	target_cell = Vector3i((target_point - target_normal * 0.01).floor())
	if hit.collider.has_meta("cell"):
		target_cell = hit.collider.get_meta("cell")
	build_cell = Vector3i((target_point + target_normal * 0.01).floor())
	can_build = valid_torch_cell(build_cell, target_point, target_normal) if selected_kind() == "torch" else valid_build_cell(build_cell)
	preview.visible = true
	preview.position = Vector3(build_cell) + Vector3.ONE * 0.5 - target_normal * 0.485
	preview.quaternion = Quaternion(Vector3.BACK, target_normal)

func place_block() -> void:
	if player.paused or player.inventory_open or player.movement_blocked:
		return
	update_build_preview()
	var kind := selected_kind()
	if not can_build or not Registry.catalog.items.get(kind, {}).has("block"):
		return
	if not inventory.take_from_slot(24 + selected_hotbar):
		return
	model.set_block(build_cell, kind)
	if kind == "torch":
		model.entities["torch_" + model.text_key(build_cell)] = {"type": "torch", "kind": "torch", "cell": build_cell, "position": torch_position(build_cell, target_point, target_normal), "normal": target_normal, "state": {}}
		entity_system.elapsed = 1
	update_counter()

func update_mining(delta: float) -> void:
	if not mining_held or player.paused or player.inventory_open or target_cell.y == -1000:
		reset_mining()
		return
	var kind: String = model.kind_at(target_cell)
	if kind == "air" or not Registry.breakable(kind):
		reset_mining()
		if kind == "bedrock":
			mining_label.text = "Berggrund — kan inte bearbetas"
		return
	if mining_cell != target_cell:
		reset_mining()
		mining_cell = target_cell
	active_tool = selected_kind() if Registry.tool(selected_kind()) else "hand"
	var seconds: float = Registry.seconds(active_tool, kind)
	mining_elapsed += delta
	mining_bar.visible = true
	mining_bar.value = minf(100, mining_elapsed / seconds * 100)
	mining_label.text = "%s — %s: %.1f / %.1f s" % [Registry.label(active_tool) if active_tool != "hand" else "För hand", Registry.label(kind), minf(mining_elapsed, seconds), seconds]
	if not Registry.drops(active_tool, kind) and kind == "stone":
		mining_label.text += " • förstörs utan utbyte"
	if mining_elapsed >= seconds:
		var gives_drop: bool = Registry.drops(active_tool, kind)
		model.set_block(mining_cell, "air")
		var id: String = "torch_" + model.text_key(mining_cell)
		if model.entities.has(id):
			model.entities.erase(id)
			entity_system.deactivate(id)
		if gives_drop:
			entity_system.spawn_drop(kind, Vector3(mining_cell) + Vector3.ONE * 0.5)
		reset_mining()
		update_counter()

func _input(event: InputEvent) -> void:
	if handle_inventory_event(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
			select_hotbar(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_E or (event.keycode == KEY_ESCAPE and player.inventory_open):
			toggle_inventory()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and not player.inventory_open and not player.paused:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			select_hotbar(selected_hotbar + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mining_held = event.pressed and not player.paused and not player.inventory_open
		if not mining_held:
			reset_mining()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if player.paused or player.inventory_open or player.movement_blocked:
			return
		update_build_preview()
		if model.kind_at(target_cell) == "workbench":
			toggle_inventory(true)
		else:
			place_block()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not testing and model != null:
		save_game(false)
		streamer.shutdown()
		get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(streamer):
		streamer.shutdown()
