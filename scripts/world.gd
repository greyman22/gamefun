extends "res://scripts/game_ui.gd"
const PerfLog = preload("res://scripts/core/performance_log.gd")
const Furnaces=preload("res://scripts/core/furnaces.gd")
const Farming = preload("res://scripts/core/farming.gd")
var target_plant: Dictionary = {}
const INTERACTION_REACH: float = 5.0

const Surfaces = preload("res://scripts/rendering/surface_textures.gd")
const Cotton=preload("res://scripts/core/cotton.gd")
const Saplings=preload("res://scripts/core/saplings.gd")
const DeathDrops=preload("res://scripts/core/death_drops.gd")
const Boats=preload("res://scripts/core/boats.gd")
var mounted_boat: String=""
const WaterSurface=preload("res://scripts/rendering/water_surface.gd")
const DebugWater=preload("res://scripts/core/debug_water.gd")
const DebugHouse = preload("res://scripts/core/debug_house.gd")
const Doors = preload("res://scripts/core/doors.gd")
const DayCycle = preload("res://scripts/core/day_cycle.gd")
const DayHUD = preload("res://scripts/day_hud.gd")
var day_hud: Control
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var moon_disc: MeshInstance3D
var sun_disc: MeshInstance3D
const SheepLogic=preload("res://scripts/core/sheep.gd")
const Hens = preload("res://scripts/core/hens.gd")
const Chests = preload("res://scripts/core/chests.gd")
const ChestUI = preload("res://scripts/chest_ui.gd")
const Berries = preload("res://scripts/core/berries.gd")
const Combat = preload("res://scripts/core/combat.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CombatDebug = preload("res://scripts/combat_debug.gd")
const WorldData = preload("res://scripts/core/world_data.gd")
const Generator = preload("res://scripts/core/generator.gd")
const Streamer = preload("res://scripts/rendering/streamer.gd")
const Entities = preload("res://scripts/core/entity_system.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const ZombieHouse = preload("res://scripts/core/zombie_house.gd")
const VitalsHUD = preload("res://scripts/vitals_hud.gd")
const HouseMarker = preload("res://scripts/house_marker.gd")
const PlayerScript = preload("res://scripts/player.gd")
var model: RefCounted
var streamer: Node3D
var entity_system: Node3D
const Daylight = preload("res://scripts/core/daylight.gd")
var daylight = Daylight.new()
var sky_environment: Environment
var light_elapsed: float = 1
var daylight_target: float = 1
var daylight_amount: float = 1
var testing: bool = false
const DEFAULT_VIEW_DISTANCE: int=96
var view_distance: int = DEFAULT_VIEW_DISTANCE
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
var game_mode: String = "play"
var mode_selector: OptionButton
var start_panel: PanelContainer
var start_seed: LineEdit
var house_marker: Control
var session_started: bool = false
var combat_feedback: Control
var vitals_hud: Control
var combat_debug: PanelContainer
var combat_previous_paused: bool = false
var attack_cooldown: float = 0
var bow_drawing: bool = false
var bow_charge: float = 0
var attack_animation: float = 0
var target_bush: String = ""
var harvest_target: String = ""
var harvest_press: bool = false
var planting_held: bool = false
var planting_last_key: String = ""
var eating_elapsed: float = 0
var berry_planting: bool = false
var eating_slot: int = -1
var thorn_cooldown: float = 0
var chest_ui: PanelContainer

func _ready() -> void:
	var photo_pause=preload("res://scripts/photo_pause.gd").new()
	photo_pause.name="PhotoPause"
	add_child(photo_pause)
	Registry.initialize()
	Combat.initialize()
	for kind: String in Registry.catalog.blocks:
		if kind == "air":
			continue
		var base := Color(Registry.catalog.blocks[kind].color)
		item_materials[kind] = Surfaces.material(kind,2 if kind=="dirt" else 0)
	for kind: String in Registry.catalog.items:
		item_icons[kind] = ItemVisuals.icon(kind)
	block_dirt = item_materials.dirt
	block_grass = Surfaces.material("dirt",1)
	create_lighting()
	player = PlayerScript.new()
	add_child(player)
	player.vitals.died.connect(respawn_player)
	var hud_canvas := CanvasLayer.new()
	hud_canvas.layer = 1
	add_child(hud_canvas)
	vitals_hud = VitalsHUD.new()
	vitals_hud.vitals = player.vitals
	hud_canvas.add_child(vitals_hud)
	combat_feedback = CombatFeedback.new()
	hud_canvas.add_child(combat_feedback)
	player.vitals.damaged.connect(combat_feedback.on_hurt)
	build_outline()
	build_ui()
	build_pause_menu()
	var day_canvas := CanvasLayer.new()
	day_canvas.layer = 4
	add_child(day_canvas)
	day_hud = DayHUD.new()
	day_hud.world = self
	day_canvas.add_child(day_hud)
	var chest_canvas := CanvasLayer.new()
	chest_canvas.layer = 2
	add_child(chest_canvas)
	chest_ui = ChestUI.new()
	chest_ui.configure(self)
	chest_canvas.add_child(chest_ui)
	var debug_canvas := CanvasLayer.new()
	debug_canvas.layer = 4
	add_child(debug_canvas)
	combat_debug = CombatDebug.new()
	combat_debug.world = self
	debug_canvas.add_child(combat_debug)
	var loaded: bool = false
	if not testing:
		var id: String = SaveStore.last_id()
		if not id.is_empty():
			loaded = restore_snapshot(SaveStore.load_world(id))
	if not loaded:
		new_world(20261030 if testing else int(randi()))
	if not testing:
		get_tree().auto_accept_quit = false
		build_start_menu(loaded)
		player.paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func build_start_menu(has_saved_world: bool) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 4
	add_child(canvas)
	start_panel = PanelContainer.new()
	canvas.add_child(start_panel)
	start_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	start_panel.offset_left = -255
	start_panel.offset_right = 255
	start_panel.offset_top = -225
	start_panel.offset_bottom = 225
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.09, 0.98)
	style.set_content_margin_all(26)
	start_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	start_panel.add_child(column)
	column.add_child(label("GAME FUN", 32))
	column.add_child(label("Välj hur du vill spela", 21))
	if has_saved_world:
		menu_button(column, "Fortsätt sparad värld · " + ("Debugläge" if game_mode == "debug" else "Spelläge"), func() -> void:
			session_started = true
			start_panel.hide()
			resume_game())
	column.add_child(label("Seed för en ny värld (valfritt)", 16))
	start_seed = LineEdit.new()
	start_seed.placeholder_text = "Lämna tomt för slumpad värld"
	column.add_child(start_seed)
	menu_button(column, "Ny värld – Spelläge", func() -> void: start_new_session("play", start_seed.text))
	menu_button(column, "Ny värld – Debugläge", func() -> void: start_new_session("debug", start_seed.text))
	column.add_child(label("Debug: alla material och verktyg från start.\nFölj pilen till Zombie-huset, cirka 40 m bort.\nF3: visa stridsvärden.", 16))

func start_new_session(mode: String, seed_text: String) -> void:
	var text_value: String = seed_text.strip_edges()
	if not text_value.is_empty() and not text_value.is_valid_int():
		message("Seed behöver vara ett heltal")
		return
	if not testing and (session_started or not SaveStore.last_id().is_empty()) and not save_game(false):
		return
	var value: int = int(randi()) if text_value.is_empty() else clampi(int(text_value), -2147483647, 2147483647)
	new_world(value, mode)
	session_started = true
	if is_instance_valid(start_panel):
		start_panel.hide()
	if not testing:
		save_game(false)

func update_house_marker() -> void:
	if not is_instance_valid(house_marker):
		var canvas := CanvasLayer.new()
		canvas.layer = 1
		add_child(canvas)
		house_marker = HouseMarker.new()
		canvas.add_child(house_marker)
	var record: Dictionary = model.landmarks.get("zombie_house", {})
	if record.is_empty():
		house_marker.hide()
		return
	house_marker.update_marker(player.camera, record.marker, game_mode == "debug" and not player.paused and not player.inventory_open)

func create_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.0
	sun.shadow_enabled = false
	sun.shadow_opacity = 0.25
	add_child(sun)
	sun_disc = MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 2.6
	disc.height = 5.2
	sun_disc.mesh = disc
	sun_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.disable_fog = true
	glow.albedo_color = Color(1,0.86,0.53)
	sun_disc.material_override = glow
	add_child(sun_disc)
	sun_disc.hide()
	moon_disc = MeshInstance3D.new()
	moon_disc.mesh = disc
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moon_material := glow.duplicate() as StandardMaterial3D
	moon_material.albedo_color = Color(0.75,0.81,0.92)
	moon_disc.material_override = moon_material
	add_child(moon_disc)
	moon_disc.hide()
	moon_light = DirectionalLight3D.new()
	moon_light.light_energy = 0.0
	moon_light.light_color = Color(0.6,0.7,1)
	moon_light.shadow_enabled = false
	moon_light.shadow_opacity = 0.25
	add_child(moon_light)
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.57, 0.78, 0.93)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.9
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.57, 0.78, 0.93)
	environment.fog_density = 0.002
	sky_environment = environment
	sky.environment = environment
	add_child(sky)

func update_counter() -> void:
	if is_instance_valid(chest_ui) and chest_ui.visible:
		chest_ui.refresh()
		return
	super.update_counter()

func install_model(data: RefCounted, position: Vector3) -> void:
	Boats.leave(self)
	if is_instance_valid(chest_ui) and chest_ui.visible:
		chest_ui.detach()
	if is_instance_valid(streamer):
		streamer.shutdown()
		remove_child(streamer)
		streamer.queue_free()
	if is_instance_valid(entity_system):
		remove_child(entity_system)
		entity_system.queue_free()
	eating_elapsed = 0
	eating_slot = -1
	thorn_cooldown = 0
	target_bush = ""
	harvest_press = false
	model = data
	if game_mode=="debug":
		DebugHouse.upgrade_roof(model)
	player.world_model=model
	daylight.configure(model)
	light_elapsed = 1
	streamer = Streamer.new()
	streamer.configure(model)
	streamer.view_distance = view_distance
	add_child(streamer)
	entity_system = Entities.new()
	entity_system.configure(model, game_mode)
	entity_system.zombie_died.connect(func(_position: Vector3) -> void: message("Zombie besegrad – lämnade en själsrest."))
	add_child(entity_system)
	var water_view=WaterSurface.new()
	water_view.name="WaterSurface"
	water_view.configure(model,player)
	water_view.view_distance=view_distance
	entity_system.add_child(water_view)
	player.position = position
	player.reset_fall_tracking()
	player.velocity = Vector3.ZERO
	player.respawn_position = Vector3(0, model.generator.height(0, 12) + 0.05, 12)
	player.bounds_radius = model.generator.world_limit() - 1.0
	player.bottom_y = Generator.MIN_Y
	player.camera.far = view_distance + 16
	player.movement_blocked = true
	streamer.warm_start(position)
	entity_system.elapsed=1
	entity_system.tick(position, 0)
	player.movement_blocked = false
	player.paused = false
	player.set_process_unhandled_input(true)
	player.inventory_open = false
	inventory_panel.visible = false
	prompt.visible = true
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	reset_mining()
	autosave_elapsed = 0

func new_world(seed_value: int, mode: String = "play") -> void:
	view_distance=DEFAULT_VIEW_DISTANCE
	stack_cursor.reset()
	bow_drawing=false
	bow_charge=0
	attack_cooldown = 0
	attack_animation = 0
	combat_debug.hide()
	player.vitals.reset()
	game_mode = "debug" if mode == "debug" else "play"
	var data := WorldData.new(seed_value)
	ZombieHouse.new().place(data, game_mode == "debug")
	if game_mode == "debug":
		DebugHouse.new().place(data)
		DebugWater.place(data)
	inventory = InventoryScript.new()
	if game_mode == "debug":
		var quickbar: Array[String] = ["stone_sword", "pickaxe", "axe", "shovel", "", "dirt", "wood", "", "torch"]
		for index in range(quickbar.size()):
			var kind: String = quickbar[index]
			if not kind.is_empty():
				inventory.slots[27 + index] = {"kind": kind, "count": 1 if Registry.tool(kind) else mini(64, Registry.stack_limit(kind))}
	crafting = CraftingScript.new()
	rebuild_crafting_slots()
	selected_hotbar = 0
	install_model(data, Vector3(0, data.generator.height(0, 12) + 0.05, 12))
	held_kind = "uninitialized"
	update_counter()

func snapshot() -> Dictionary:
	entity_system.snapshot_active()
	return {"mode": game_mode, "attack_cooldown": attack_cooldown, "world": model.export_state(), "player": {"boat":mounted_boat,"position": player.position, "rotation": player.rotation, "camera": player.camera.rotation, "velocity": player.velocity, "vitals": player.vitals.snapshot(), "knockback": player.knockback.snapshot(), "fall_peak": player.fall_peak, "airborne": player.airborne}, "inventory": inventory.slots.duplicate(true), "crafting": {"width": crafting.width, "slots": crafting.slots.duplicate(true), "open": player.inventory_open}, "cursor": stack_cursor.held.duplicate(), "selected": selected_hotbar, "view_distance": view_distance,"view_distance_policy":1}

func valid_slots(slots: Variant, expected: int, cursor_stack: bool = false) -> bool:
	if not slots is Array or slots.size() != expected:
		return false
	for slot: Variant in slots:
		if not slot is Dictionary or not slot.has_all(["kind", "count"]):
			return false
		if not slot.kind is String or slot.count < 0 or slot.count > maxi(64 if Registry.tool(slot.kind) else 0, Registry.stack_limit(slot.kind) * (32 if cursor_stack else 1)):
			return false
		if slot.count > 0 and not Registry.catalog.items.has(slot.kind):
			return false
	return true

func normalize_tool_stacks(held: Dictionary, data: RefCounted, position: Vector3) -> Dictionary:
	var extra: Array[Dictionary] = []
	for slot: Dictionary in inventory.slots + crafting.slots + [held]:
		if Registry.tool(slot.kind) and slot.count > 1:
			extra.append(Registry.stack(slot.kind, slot.count - 1, slot))
			slot.count = 1
	for entry in extra:
		var kind: String = entry.kind
		var remaining: int = entry.count
		while remaining > 0 and inventory.add_stack(Registry.stack(kind, 1, entry)):
			remaining -= 1
		if remaining > 0:
			var id: String = "tool_overflow_%s_%d" % [kind, Time.get_ticks_usec()]
			data.entities[id] = {"type": "pickup", "kind": kind, "item": Registry.stack(kind, remaining, entry), "position": position + Vector3(0, 0.5, 0), "count": remaining, "ready_at": data.game_time + 0.5, "state": {"falling": true, "velocity_y": 0}}
	return held

func restore_snapshot(saved: Dictionary) -> bool:
	if not saved.has_all(["world", "player", "inventory", "crafting", "selected"]):
		return false
	var width: int = int(saved.crafting.get("width", 0))
	if width not in [2, 3] or not (valid_slots(saved.inventory, 36) or valid_slots(saved.inventory, 32)) or not valid_slots(saved.crafting.get("slots"), width * width):
		return false
	if not saved.player.get("position") is Vector3:
		return false
	var held: Dictionary = saved.get("cursor", {"kind": "", "count": 0})
	if not valid_slots([held], 1, true):
		return false
	var data := WorldData.new()
	if not data.import_state(saved.world):
		return false
	game_mode = "debug" if saved.get("mode", "play") == "debug" else "play"
	if not data.landmarks.has("zombie_house"):
		ZombieHouse.new().place(data, game_mode == "debug")
	ZombieHouse.new().ensure_zombies(data)
	for id: String in data.entities.keys():
		if id.begins_with("starter_") and data.entities[id].type=="pickup":
			data.entities.erase(id)
	attack_cooldown = maxf(0, float(saved.get("attack_cooldown", 0)))
	combat_debug.hide()
	view_distance = clampi(int(saved.get("view_distance", DEFAULT_VIEW_DISTANCE)), 32, 192)
	if int(saved.get("view_distance_policy",0))<1:
		view_distance=mini(view_distance,DEFAULT_VIEW_DISTANCE)
	inventory = InventoryScript.new()
	if saved.inventory.size() == 32:
		# Keep every old row and quickbar position, adding an empty ninth cell.
		for index in range(32):
			inventory.slots[(index / 8) * 9 + index % 8] = saved.inventory[index].duplicate(true)
	else:
		inventory.slots.assign(saved.inventory.duplicate(true))
	crafting = CraftingScript.new(width)
	crafting.slots.assign(saved.crafting.slots.duplicate(true))
	if game_mode == "debug":
		for slot: Dictionary in inventory.slots + crafting.slots + [held]:
			if slot.kind == "bedrock":
				Registry.clear_slot(slot)
	held = normalize_tool_stacks(held.duplicate(), data, saved.player.position)
	rebuild_crafting_slots()
	selected_hotbar = clampi(int(saved.selected), 0, 8)
	install_model(data, saved.player.position)
	player.rotation = saved.player.get("rotation", Vector3.ZERO)
	player.camera.rotation = saved.player.get("camera", Vector3.ZERO)
	player.velocity = saved.player.get("velocity", Vector3.ZERO)
	if not str(saved.player.get("boat","")).is_empty():
		Boats.board(self,str(saved.player.boat))
	player.vitals.restore(saved.player.get("vitals", {}))
	player.knockback.restore(saved.player.get("knockback", {}))
	player.fall_peak = saved.player.get("fall_peak", player.position.y)
	player.airborne = saved.player.get("airborne", false)
	stack_cursor.reset()
	stack_cursor.held = held.duplicate()
	held_kind = "uninitialized"
	if saved.crafting.get("open", false) or held.count > 0 or crafting.slots.any(func(slot: Dictionary) -> bool: return slot.count > 0):
		player.inventory_open = true
		inventory_panel.visible = true
		prompt.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_counter()
	if player.vitals.health <= 0:
		respawn_player()
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
	pause_panel.offset_top = -330
	pause_panel.offset_bottom = 330
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
	column.add_child(label("Läge för ny värld", 15))
	mode_selector = OptionButton.new()
	mode_selector.add_item("Spelläge")
	mode_selector.add_item("Debugläge – alla föremål")
	column.add_child(mode_selector)
	column.add_child(label("Seed för ny värld (valfritt)", 15))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Lämna tomt för slumpad värld"
	column.add_child(seed_input)
	menu_button(column, "Skapa ny värld", func() -> void:
		start_new_session("debug" if mode_selector.selected == 1 else "play", seed_input.text))
	column.add_child(label("Siktavstånd", 17))
	distance_selector = OptionButton.new()
	for distance in [48, 64, 96, 128, 192]:
		distance_selector.add_item("%d meter" % distance, distance)
	distance_selector.item_selected.connect(func(index: int) -> void:
		view_distance = distance_selector.get_item_id(index)
		streamer.view_distance = view_distance
		entity_system.get_node("WaterSurface").view_distance=view_distance
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
	menu_caption.text = "%s · Seed: %d" % ["Debugläge" if game_mode == "debug" else "Spelläge", model.seed_value]
	mode_selector.select(1 if game_mode == "debug" else 0)
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.inventory_open else Input.MOUSE_MODE_CAPTURED

func message(text_value: String) -> void:
	status.text = text_value
	status_time = 4

func _measured_process(delta: float) -> void:
	if model == null:
		return
	update_bow_charge(delta)
	update_cursor_visual()
	update_daylight(delta)
	day_hud.refresh(delta)
	update_house_marker()
	streamer.tick(player.position, delta, -player.camera.global_basis.z)
	entity_system.tick(player.position, delta)
	var predicted: Vector3 = player.position + Vector3(player.velocity.x, 0, player.velocity.z) * 0.25
	player.movement_blocked = not streamer.ready_at(player.position) or not streamer.ready_at(predicted)
	if attack_animation <= 0:
		update_hand_animation(delta, mining_held and mining_bar.visible and not player.paused and not player.inventory_open and not player.movement_blocked)
	if attack_animation > 0 and not player.paused and not player.inventory_open:
		var progress: float = 1 - attack_animation / 0.3
		apply_tool_action(progress)
	if is_instance_valid(start_panel) and start_panel.visible:
		player.paused = true
	var visible_menu: bool = player.paused and not player.inventory_open and not combat_debug.visible and not (is_instance_valid(start_panel) and start_panel.visible)
	pause_panel.visible = visible_menu
	if visible_menu and not menu_was_visible:
		refresh_world_list()
	menu_was_visible = visible_menu
	status_time = maxf(0, status_time - delta)
	status.visible = status_time > 0

func _measuredupdate_daylight(delta: float) -> void:
	light_elapsed += delta
	if light_elapsed >= 0.3:
		light_elapsed = 0
		daylight_target = daylight.exposure(player.camera.global_position)
		var point: Vector3 = player.camera.global_position
		var x := floori(point.x)
		var z := floori(point.z)
		var roof_kind: String = model.kind_at(Vector3i(x,daylight.roof(x,z),z))
		if point.y >= model.generator.height(x,z) and roof_kind in ["wood","planks","foliage"]:
			daylight_target = 1.0
		update_torch_lighting()
	daylight_amount = move_toward(daylight_amount, daylight_target, delta * 1.5)
	var daylight_strength: float = DayCycle.daylight(model)
	var sky_color := Color(0.045,0.065,0.13).lerp(Color(0.57,0.78,0.93),daylight_strength)
	sky_environment.background_color = sky_color
	sky_environment.ambient_light_energy = lerpf(0.012, lerpf(0.28, 0.9, daylight_strength), daylight_amount)
	sky_environment.ambient_light_color = Color(0.75,0.8,0.95).lerp(Color.WHITE,daylight_strength)
	sky_environment.fog_light_color = Color(0.005,0.006,0.008).lerp(sky_color,daylight_amount)
	var angle: float = (DayCycle.hour(model) - 4.0) / 18.0 * PI
	var direction := Vector3(cos(angle),sin(angle),-0.35).normalized()
	sun_light.look_at_from_position(player.position + direction * 100,player.position)
	sun_light.light_energy = 0.0 # Sky disc is visual only; ambient light keeps all faces evenly lit.
	sun_light.light_color = Color(1,0.65,0.4).lerp(Color(1,0.97,0.9),daylight_strength)
	# Keep sky bodies safely inside the current camera far plane, even at short view distance.
	var sky_distance: float = minf(100,player.camera.far * 0.7)
	sun_disc.position = player.camera.global_position + direction * sky_distance
	sun_disc.scale = Vector3.ONE * sky_distance / 100.0
	sun_disc.visible = daylight_strength > 0.001
	var night_hour: float = fposmod(DayCycle.hour(model) - 21.0,24)
	var moon_angle: float = night_hour / 7.0 * PI
	var moon_direction := Vector3(cos(moon_angle),sin(moon_angle),-0.35).normalized()
	moon_disc.position = player.camera.global_position + moon_direction * sky_distance
	moon_disc.scale = Vector3.ONE * sky_distance / 100.0
	moon_disc.visible = night_hour < 7
	moon_light.look_at_from_position(player.position + moon_direction * 100,player.position)
	moon_light.light_energy = 0.0
	sky_environment.fog_density = lerpf(0.012, 0.002, daylight_amount)
	sky_environment.fog_light_color=Color(0.57,0.78,0.93)
	if model.water.contains(player.camera.global_position):
		sky_environment.fog_density=0.18
		sky_environment.fog_light_color=Color(0.08,0.28,0.39)

func _measured_physics_process(delta: float) -> void:
	if model == null:
		return
	can_build = false
	preview.visible = false
	bush_focus.visible = false
	if player.inventory_open and not player.paused and not player.movement_blocked:
		Furnaces.tick(model,delta)
	if player.paused or player.inventory_open or player.movement_blocked:
		mining_held = false
		planting_held = false
		planting_last_key = ""
		eating_elapsed = 0
		eating_slot = -1
		reset_mining()
		prompt.text = "Förbereder området…" if player.movement_blocked else ""
		return
	if not mounted_boat.is_empty():
		var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		Boats.move(self,delta,axis)
	model.advance(delta)
	DayCycle.advance(model, delta, game_mode == "debug")
	player.vitals.tick(delta)
	player.vitals.breathe(delta,model.water.contains(player.camera.global_position))
	attack_cooldown = maxf(0, attack_cooldown - delta)
	attack_animation = maxf(0, attack_animation - delta)
	entity_system.simulate_drops(delta)
	entity_system.seed_lure = player.position if selected_kind() == "grass_seed" else null
	entity_system.grain_lure = player.position if selected_kind()=="grain" else null
	entity_system.simulate_actors(delta, player)
	check_bush_contact(delta)
	if entity_system.collect(player.position, inventory):
		update_counter()
	update_build_preview()
	if mining_held:
		var boat_target: String=Boats.pick(self)
		if not boat_target.is_empty():
			reset_mining()
			if attack_cooldown<=0:
				Boats.hit(self,boat_target)
				attack_cooldown=0.5
				attack_animation=0.35
			return
	if update_held_planting():
		reset_mining()
	elif update_eating(delta):
		pass
	elif mining_held and selected_kind() != "blueberry" and try_attack():
		reset_mining()
	elif not target_plant.is_empty():
		update_plant_harvest(delta)
	elif not target_bush.is_empty():
		update_harvest(delta)
	elif harvest_press:
		reset_mining()
	else:
		update_mining(delta)
	if selected_kind() == "blueberry":
		prompt.text = "Håll höger: ät · Höger på jord: plantera"
	elif not target_plant.is_empty():
		prompt.text = "H\u00e5ll v\u00e4nster: sk\u00f6rda " + ("vilt gr\u00e4s" if target_plant.wild else "s\u00e4d")
	elif selected_kind()=="boat":
		prompt.text="Höger på vatten: sjösätt båt"
	elif selected_kind()=="hoe":
		prompt.text = "H\u00f6ger p\u00e5 jord: bered odlingsjord"
	elif selected_kind()=="grass_seed":
		prompt.text = "H\u00f6ger p\u00e5 odlingsjord: s\u00e5"
	elif not target_bush.is_empty():
		prompt.text = "Höger med sax: klipp bomull · Håll vänster utan sax: gräv upp" if model.entities.get(target_bush,{}).get("type","")=="cotton_plant" else "Håll vänster: skörda blåbär"
	elif model.kind_at(target_cell) in Doors.PARTS:
		prompt.text = "H\u00f6ger: \u00f6ppna / st\u00e4ng " + ("grind" if model.kind_at(target_cell) in ["gate","gate_open"] else "d\u00f6rr")
	elif model.kind_at(target_cell) in ["chest","furnace","furnace_lit"]:
		prompt.text = "H\u00f6ger: \u00f6ppna " + ("stenugn" if model.kind_at(target_cell) in Furnaces.PARTS else "kista")
	elif model.kind_at(target_cell) == "workbench":
		prompt.text = "Höger: öppna arbetsbänk • Håll vänster: ta bort"
	elif can_build:
		prompt.text = "Valt: %s • Höger: placera • Håll vänster: bearbeta" % Registry.label(selected_kind())
	else:
		prompt.text = ""
	if not mounted_boat.is_empty():
		prompt.text="W/S: ro | A/D: sväng | Mus: titta | Shift: kliv ur båten"
	if not testing:
		autosave_elapsed += delta
		if autosave_elapsed >= 30:
			autosave_elapsed = 0
			save_game(false)

func respawn_player() -> void:
	var recovered: int=DeathDrops.spill(self,player.position)
	Boats.leave(self)
	inventory = InventoryScript.new()
	crafting = CraftingScript.new()
	stack_cursor.reset()
	rebuild_crafting_slots()
	player.vitals.reset()
	bow_drawing=false
	bow_charge=0
	attack_cooldown = 0
	attack_animation = 0
	combat_debug.hide()
	player.position = player.respawn_position
	# Use the current surface at the gathering point if the player has built or dug there.
	for y in range(model.generator.max_y(), Generator.MIN_Y - 1, -1):
		if Registry.cube(model.block(Vector3i(0, y, 12))):
			player.position.y = y + 1.05
			break
	player.velocity = Vector3.ZERO
	player.reset_fall_tracking()
	player.paused = false
	player.inventory_open = false
	inventory_panel.hide()
	pause_panel.hide()
	reset_mining()
	streamer.warm_start(player.position)
	entity_system.elapsed=1
	entity_system.tick(player.position, 0)
	player.movement_blocked = false
	held_kind = "uninitialized"
	update_counter()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	message("Du återvände utan utrustning. Föremål finns på torr mark nära dödsplatsen." if recovered>0 else "Du återvände utan utrustning. Föremålen gick förlorade.")

func combat_line_clear(from: Vector3, to: Vector3) -> bool:
	var steps: int = maxi(2, ceili(from.distance_to(to) / 0.15))
	for index in range(1, steps):
		if model.kind_at(Vector3i(from.lerp(to,float(index)/steps).floor())) not in ["fence","gate"] and Registry.cube(model.block(Vector3i(from.lerp(to, float(index) / steps).floor()))):
			return false
	return true

func attack_targets(stats: Dictionary) -> Array[String]:
	var targets: Array[String] = []
	var sweep: bool = float(stats.get("sweep_degrees",0)) >= 180
	var from: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	var flat_forward := Vector3(forward.x,0,forward.z).normalized()
	var nearest: float = INF
	for id: String in entity_system.active:
		var record: Dictionary = model.entities[id]
		if record.get("state",{}).get("dead",false):
			continue
		if record.type not in ["zombie","skeleton","sheep"] and not (record.type == "hen" and selected_kind() in ["stone_sword","axe"]):
			continue
		var actor: Node3D = entity_system.active[id]
		var zombie: bool = record.type in ["zombie","skeleton"]
		# Use body extent, not feet/centre alone, for forgiving melee selection.
		var radius: float = 0.55 if zombie else 0.35
		var height: float = 1.95 if zombie else (0.95 if Hens.adult(record,model.game_time) else 0.5)
		var offset: Vector3 = actor.position-player.position
		if absf(offset.y)>2.2:
			continue
		var flat := Vector3(offset.x,0,offset.z)
		if flat.length()>float(stats.reach)+radius or flat_forward.dot(flat)<0:
			continue
		if not sweep:
			var bounds := AABB(actor.position-Vector3(radius,0.15,radius),Vector3(radius*2,height+0.3,radius*2))
			if bounds.intersects_segment(from,from+forward*(float(stats.reach)+radius)) == null:
				continue
		var visible: bool = false
		for fraction in [0.8,0.55,0.3]:
			if combat_line_clear(from,actor.position+Vector3(0,height*fraction,0)):
				visible = true
				break
		if not visible:
			continue
		if sweep:
			targets.append(id)
		elif offset.length_squared()<nearest:
			nearest = offset.length_squared()
			targets.assign([id])
	return targets

func try_attack() -> bool:
	if selected_kind()=="bow":
		return false
	var stats: Dictionary = Combat.stats("player", selected_kind())
	var targets: Array[String] = attack_targets(stats)
	if targets.is_empty():
		return false
	if attack_cooldown <= 0:
		var total: float = 0
		var defeated: int = 0
		var zombie_defeated: int = 0
		for id in targets:
			var record: Dictionary = model.entities[id]
			var defense: float = float(Combat.stats("zombie").defense)
			if record.type == "hen":
				defense = float(record.get("defense", Combat.stats("hen").defense)) if Hens.adult(record, model.game_time) else float(Combat.stats("chick").defense)
			if record.type=="sheep":
				defense=float(Combat.stats("sheep" if Hens.adult(record,model.game_time) else "lamb").defense)
			if record.type=="skeleton":
				defense=float(record.get("defense",Combat.stats("skeleton").defense))
			var amount: float = Combat.damage(float(stats.attack), defense)
			total += entity_system.damage_actor(id, amount, Combat.respawn_seconds(game_mode), player.position)
			if not model.entities.has(id) or model.entities[id].state.get("dead", false):
				defeated += 1
				if record.type == "zombie":
					zombie_defeated += 1
		if total > 0:
			attack_cooldown = float(stats.interval)
			attack_animation = 0.3
			combat_feedback.hit_time = 0.18
			if zombie_defeated > 0:
				message("Besegrade %d - l\u00e4mnade sj\u00e4lsrester." % zombie_defeated)
			elif defeated > 0:
				message("Besegrade %d." % defeated)
			elif targets.size() > 1:
				message("Träffade %d · %.1f skada sammanlagt" % [targets.size(), total])
			else:
				message("Träff: %.1f skada" % total)
			wear_selected_tool()
	return true

func toggle_combat_debug() -> void:
	if game_mode != "debug" or player.inventory_open:
		return
	if combat_debug.visible:
		combat_debug.hide()
		player.paused = combat_previous_paused
		player.set_process_unhandled_input(true)
	else:
		combat_previous_paused = player.paused
		player.paused = true
		player.set_process_unhandled_input(false)
		combat_debug.refresh()
		combat_debug.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.paused else Input.MOUSE_MODE_CAPTURED

func valid_build_cell(cell: Vector3i) -> bool:
	if model.kind_at(cell+Vector3i.DOWN)=="fence":
		return false
	if selected_kind()=="fence" and (model.block(cell+Vector3i.UP)!=0 or not Registry.cube(model.block(cell+Vector3i.DOWN))):
		return false
	if entity_system.creature_occupies(cell,2 if selected_kind() in ["door","fence"] else 1):
		return false
	if absi(cell.x) >= model.generator.world_limit() - 1 or absi(cell.z) >= model.generator.world_limit() - 1 or cell.y < Generator.MIN_Y or cell.y > model.generator.max_y():
		return false
	if selected_kind() in ["door","gate"]:
		if not Doors.can_place(model,cell,selected_kind()) or not Berries.at_cell(model,cell+Vector3i.UP).is_empty():
			return false
		if absf(player.position.x-cell.x-0.5) < 0.85 and absf(player.position.z-cell.z-0.5) < 0.85 and player.position.y < cell.y+2 and player.position.y+1.8 > cell.y:
			return false
	if selected_kind() == "chest" and not Chests.can_place(model, cell):
		return false
	if model.block(cell) != 0 or not Berries.at_cell(model, cell).is_empty() or not Farming.crop_at(model,cell).is_empty():
		return false
	var center := Vector3(cell) + Vector3.ONE * 0.5
	var feet: Vector3 = player.position
	return not (absf(center.x - feet.x) < 0.86 and absf(center.z - feet.z) < 0.86 and center.y + 0.5 > feet.y and center.y - 0.5 < feet.y + 1.8)

func torch_position(cell: Vector3i, _point: Vector3, normal: Vector3) -> Vector3:
	return ItemVisuals.torch_anchor(cell,normal)

func valid_torch_cell(cell: Vector3i, point: Vector3, normal: Vector3) -> bool:
	if entity_system.creature_occupies(cell):
		return false
	if model.block(cell) != 0 or not Berries.at_cell(model, cell).is_empty() or cell.y < Generator.MIN_Y or cell.y > model.generator.max_y():
		return false
	var center := torch_position(cell, point, normal)
	var feet: Vector3 = player.position
	return not (absf(center.x - feet.x) < 0.41 and absf(center.z - feet.z) < 0.41 and center.y + 0.3 > feet.y and center.y - 0.3 < feet.y + 1.8)

func update_build_preview() -> void:
	bush_focus.visible = false
	target_bush = ""
	target_plant = {}
	target_cell = Vector3i(0, -1000, 0)
	can_build = false
	preview.visible = false
	var start: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - player.camera.global_transform.basis.z * INTERACTION_REACH, 21, [player.get_rid()])
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = start-player.camera.global_basis.z*INTERACTION_REACH if hit.is_empty() else hit.position
	target_plant = Farming.pick(model,start,end)
	if not target_plant.is_empty():
		var height: float = Farming.wild_height(model,target_plant.cell) if target_plant.wild else [0.2,0.4,0.7,1.05][Farming.stage(model.entities[target_plant.id],model.game_time)]
		bush_focus.position = Vector3(target_plant.cell)+Vector3(0.5,height*0.5,0.5)
		var width: float=Farming.wild_width(model,target_plant.cell) if target_plant.wild else 0.72
		bush_focus.scale = Vector3(width,height,width)
		bush_focus.show()
		return
	if not hit.is_empty() and hit.collider is Area3D and hit.collider.has_meta("berry_bush"):
		target_bush = hit.collider.get_parent().get_meta("entity_id")
		show_bush_focus()
		return
	if hit.is_empty() or not hit.collider.has_meta("build_surface"):
		return
	target_point = hit.position
	target_normal = hit.normal
	target_cell = Vector3i((target_point - target_normal * 0.01).floor())
	if hit.collider.has_meta("cell"):
		target_cell = hit.collider.get_meta("cell")
	if target_normal.y > 0.5:
		var above: String = Berries.at_cell(model, target_cell + Vector3i.UP)
		if not above.is_empty():
			target_bush = above
			target_cell = Vector3i(0, -1000, 0)
			show_bush_focus()
			return
	build_cell = Vector3i((target_point + target_normal * 0.01).floor())
	can_build = valid_torch_cell(build_cell, target_point, target_normal) if selected_kind() == "torch" else valid_build_cell(build_cell)
	preview.visible = true
	preview.position = Vector3(build_cell) + Vector3.ONE * 0.5 - target_normal * 0.485
	preview.quaternion = Quaternion(Vector3.BACK, target_normal)

func show_bush_focus() -> void:
	preview.hide()
	can_build = false
	if not model.entities.has(target_bush) or not entity_system.active.has(target_bush):
		return
	var bush: Node3D = entity_system.active[target_bush]
	var dimensions: Vector3 = bush.collision.shape.size
	bush_focus.position = bush.position + Vector3(0, dimensions.y * 0.5, 0)
	bush_focus.scale = dimensions + Vector3.ONE * 0.02
	bush_focus.show()

func place_block() -> void:
	if player.paused or player.inventory_open or player.movement_blocked:
		return
	update_build_preview()
	var kind := selected_kind()
	if not can_build or not Registry.catalog.items.get(kind, {}).has("block"):
		return
	if not inventory.take_from_slot(27 + selected_hotbar):
		return
	if kind in ["door","gate"]:
		var facing: Vector3 = -player.global_basis.z
		Doors.place(model,build_cell,PI/2 if absf(facing.x) > absf(facing.z) else 0.0,kind)
		entity_system.elapsed = 1
	else:
		model.set_block(build_cell, kind)
	if kind == "fence":
		model.entities["fence_"+model.text_key(build_cell)]={"type":"fence","kind":"fence","cell":build_cell,"position":Vector3(build_cell)+Vector3(0.5,0,0.5),"state":{}}
		entity_system.elapsed=1
	if kind == "furnace":
		Furnaces.contents(model,build_cell)
	if kind == "chest":
		Chests.contents(model, build_cell)
	if kind == "torch":
		model.entities["torch_" + model.text_key(build_cell)] = {"type": "torch", "kind": "torch", "cell": build_cell, "position": torch_position(build_cell, target_point, target_normal), "normal": target_normal, "state": {}}
		entity_system.elapsed = 1
	update_counter()

func update_mining(delta: float) -> void:
	if harvest_press:
		reset_mining()
		return
	harvest_target = ""
	if not mining_held or player.paused or player.inventory_open or target_cell.y == -1000:
		reset_mining()
		return
	var kind: String = model.kind_at(target_cell)
	if kind in Furnaces.PARTS:
		kind="furnace"
	if kind in Doors.PARTS:
		kind = "gate" if kind in ["gate","gate_open"] else "door"
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
		if kind == "furnace":
			for item in Furnaces.remove(model,mining_cell):
				var drop: String=entity_system.spawn_drop(item.kind,Vector3(mining_cell)+Vector3.ONE*0.5,item.count)
				model.entities[drop].item=item
		if kind == "chest":
			for item: Dictionary in Chests.remove(model, mining_cell):
				var drop: String = entity_system.spawn_drop(item.kind, Vector3(mining_cell) + Vector3.ONE * 0.5, item.count)
				model.entities[drop].item = item
		if kind == "fence":
			var fence_id: String = "fence_"+model.text_key(mining_cell)
			entity_system.deactivate(fence_id)
			model.entities.erase(fence_id)
		if kind in ["door","gate"]:
			Doors.remove(entity_system,mining_cell)
		model.set_block(mining_cell, "air")
		var id: String = "torch_" + model.text_key(mining_cell)
		if model.entities.has(id):
			model.entities.erase(id)
			entity_system.deactivate(id)
		if kind == "foliage":
			entity_system.spawn_drop(Saplings.foliage_drop(),Vector3(mining_cell)+Vector3.ONE*0.5)
		elif gives_drop:
			entity_system.spawn_drop("dirt" if kind in ["farmland","lakebed"] else kind, Vector3(mining_cell) + Vector3.ONE * 0.5)
		wear_selected_tool()
		reset_mining()
		update_counter()

func wear_selected_tool() -> void:
	var kind: String = selected_kind()
	if not Registry.tool(kind):
		return
	if inventory.wear(27 + selected_hotbar):
		message("%s gick sönder." % Registry.label(kind))
	update_counter()

func try_plant_berry() -> bool:
	if selected_kind() != "blueberry" or target_cell.y == -1000 or target_normal.y < 0.5 or model.kind_at(target_cell) != "dirt" or not valid_build_cell(build_cell):
		return false
	var id: String = Berries.plant(model, build_cell)
	if id.is_empty():
		return false
	inventory.take_from_slot(27 + selected_hotbar)
	entity_system.elapsed = 1
	update_counter()
	return true

func update_harvest(delta: float) -> void:
	if not mining_held or not model.entities.has(target_bush):
		reset_mining()
		return
	if model.entities[target_bush].type=="cotton_plant":
		update_cotton_harvest(delta)
		return
	harvest_press = true
	if harvest_target != target_bush:
		reset_mining()
		harvest_target = target_bush
	var record: Dictionary = model.entities[target_bush]
	if not Berries.ripe(record, model.game_time):
		reset_mining()
		mining_label.text = "Bärbusken har inga mogna bär ännu."
		return
	mining_elapsed += delta
	mining_bar.visible = true
	var seconds: float = Berries.harvest_seconds(selected_kind())
	mining_bar.value = minf(100, mining_elapsed / seconds * 100)
	mining_label.text = "Skördar blåbär: %.1f / %.1f s" % [minf(seconds, mining_elapsed),seconds]
	if mining_elapsed >= seconds:
		var count: int = Berries.harvest(model, target_bush)
		for index in range(count):
			var drop: String = entity_system.spawn_drop("blueberry", record.position + Vector3(0, 0.6, 0))
			model.entities[drop].needs_approach = true
			model.entities[drop].collection_origin = player.position
		if count > 0:
			entity_system.deactivate(target_bush)
			target_bush = ""
			harvest_target = ""
			bush_focus.hide()
		reset_mining()

func update_held_planting() -> bool:
	if not planting_held:
		return false
	if selected_kind() not in ["hoe","grass_seed","blueberry","sapling","cotton_shoot"]:
		planting_held=false
		return false
	update_build_preview()
	var cell: Vector3i=target_plant.cell if not target_plant.is_empty() else target_cell
	var key: String=selected_kind()+":"+model.text_key(cell)
	if key!=planting_last_key:
		planting_last_key=key
		if selected_kind()=="blueberry":
			try_plant_berry()
		else:
			try_farm_action()
	return true

func try_farm_action() -> bool:
	update_build_preview()
	var soil: Vector3i = target_cell
	if not target_plant.is_empty():
		if not target_plant.wild:
			return false
		soil = target_plant.cell+Vector3i.DOWN
	elif target_normal.y<0.5:
		return false
	if selected_kind()=="cotton_shoot":
		var id: String=Cotton.plant(model,soil+Vector3i.UP,game_mode)
		if not id.is_empty():
			inventory.take_from_slot(27+selected_hotbar)
			entity_system.activate(id,model.entities[id])
			update_counter()
			return true
	elif selected_kind()=="sapling":
		var id: String=Saplings.plant(model,soil+Vector3i.UP,game_mode)
		if not id.is_empty():
			inventory.take_from_slot(27+selected_hotbar)
			entity_system.activate(id,model.entities[id])
			update_counter()
			return true
	elif selected_kind()=="hoe":
		if Farming.till(model,soil):
			wear_selected_tool()
			entity_system.grass_field.invalidate(soil)
			attack_animation=0.3
			update_counter()
			return true
	elif selected_kind()=="grass_seed":
		var id: String = Farming.plant(model,soil+Vector3i.UP,game_mode)
		if not id.is_empty():
			inventory.take_from_slot(27+selected_hotbar)
			entity_system.activate(id,model.entities[id])
			update_counter()
			return true
	return false

func update_plant_harvest(delta: float) -> void:
	if not mining_held:
		reset_mining()
		return
	harvest_press=true
	var key: String = "plant_"+model.text_key(target_plant.cell)
	if harvest_target!=key:
		reset_mining()
		harvest_target=key
	if not target_plant.wild and not Farming.ripe(model.entities[target_plant.id],model.game_time):
		mining_label.text="S\u00e4den \u00e4r inte mogen \u00e4n"
		return
	var seconds: float = Farming.harvest_seconds(target_plant,selected_kind())
	mining_elapsed+=delta
	mining_bar.visible=true
	mining_bar.value=minf(100,mining_elapsed/seconds*100)
	mining_label.text="Sk\u00f6rdar: %.1f / %.1f s"%[mining_elapsed,seconds]
	if mining_elapsed>=seconds:
		var target: Dictionary = target_plant.duplicate()
		var drops: Dictionary = Farming.harvest(model,target)
		if not target.wild:
			entity_system.deactivate(target.id)
		for kind: String in drops:
			entity_system.spawn_drop(kind,Vector3(target.cell)+Vector3(0.5,0.5,0.5),drops[kind])
		entity_system.grass_field.invalidate(target.cell)
		target_plant={}
		bush_focus.hide()
		reset_mining()

func update_eating(delta: float) -> bool:
	if berry_planting or selected_kind() != "blueberry" or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or player.vitals.satiety >= 100:
		if eating_elapsed > 0:
			reset_mining()
		eating_elapsed = 0
		eating_slot = -1
		return false
	if eating_slot != selected_hotbar:
		eating_elapsed = 0
		eating_slot = selected_hotbar
		reset_mining()
	eating_elapsed += delta
	mining_bar.visible = true
	mining_bar.value = minf(100, eating_elapsed / 2.0 * 100)
	mining_label.text = "Äter blåbär: %.1f / 2,0 s" % minf(2, eating_elapsed)
	if eating_elapsed >= 2:
		if inventory.take_from_slot(27 + selected_hotbar):
			player.vitals.satiety = minf(100, player.vitals.satiety + 5)
		eating_elapsed = 0
		update_counter()
		if player.vitals.satiety >= 100 or selected_kind() != "blueberry":
			reset_mining()
	return true

func check_bush_contact(delta: float) -> void:
	thorn_cooldown = maxf(0, thorn_cooldown - delta)
	for id: String in entity_system.active.keys():
		if not model.entities.has(id) or model.entities[id].type != "berry_bush":
			continue
		var record: Dictionary = model.entities[id]
		if model.kind_at(record.cell + Vector3i.DOWN) != "dirt":
			model.entities.erase(id)
			entity_system.deactivate(id)
			continue
		if thorn_cooldown <= 0 and absf(player.position.y - record.position.y) < 1.2 and Vector2(player.position.x - record.position.x, player.position.z - record.position.z).length() < 0.7:
			player.receive_thorns(record.position)
			thorn_cooldown = 1
			return

func _input(event: InputEvent) -> void:
	if is_instance_valid(start_panel) and start_panel.visible:
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Q:
		if not get_viewport().gui_get_focus_owner() is LineEdit and not combat_debug.visible and (player.inventory_open or not player.paused):
			drop_selected_stack(event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
	if chest_ui.visible:
		if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_ESCAPE):
			chest_ui.close()
			get_viewport().set_input_as_handled()
		elif chest_ui.handle_event(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and ((event.physical_keycode == KEY_F3 and game_mode == "debug") or (event.keycode == KEY_ESCAPE and combat_debug.visible)):
		toggle_combat_debug()
		get_viewport().set_input_as_handled()
		return
	if combat_debug.visible:
		return
	if game_mode == "debug" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_P:
			day_hud.toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_N:
			day_hud.sleep()
			get_viewport().set_input_as_handled()
			return
	if handle_inventory_event(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			select_hotbar(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_E or (event.keycode == KEY_ESCAPE and player.inventory_open):
			toggle_inventory()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and not player.inventory_open and not player.paused:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			select_hotbar(selected_hotbar + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			get_viewport().set_input_as_handled()

func feed_hen() -> bool:
	if selected_kind() not in ["grass_seed","grain","stone_shears"]:
		return false
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 3.0, 9, [player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is Area3D:
		return false
	var actor: Node = hit.collider.get_parent()
	if not actor.has_meta("entity_id"):
		return false
	var id: String = actor.get_meta("entity_id")
	if not model.entities.has(id) or model.entities[id].type not in ["hen","sheep"]:
		return false
	if not combat_line_clear(from, actor.global_position + Vector3(0, 0.4, 0)):
		return false
	var species: String=model.entities[id].type
	if species=="sheep" and selected_kind()=="stone_shears":
		if SheepLogic.shear(entity_system,id,player.position):
			var wool_count: int=int(model.entities[id].get("last_shear_yield",0))
			message("Fåret klippt: %d ullblock föll till marken."%wool_count)
			wear_selected_tool()
			update_counter()
		return true
	if (species=="hen" and selected_kind()!="grass_seed") or (species=="sheep" and selected_kind()!="grain"):
		return false
	if Hens.feed(model, id):
		inventory.take_from_slot(27 + selected_hotbar)
		update_counter()
		message("Fåret söker en partner." if species=="sheep" else "Hönan fick ett gräsfrö och söker en partner.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.physical_keycode==KEY_SHIFT or event.keycode==KEY_SHIFT) and not mounted_boat.is_empty() and not player.paused and not player.inventory_open:
		Boats.leave(self)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		if bow_drawing:
			shoot_bow(bow_charge)
			bow_drawing=false
			bow_charge=0
		berry_planting = false
		planting_held=false
		planting_last_key=""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not player.paused and not player.inventory_open:
			update_build_preview()
			harvest_press = not target_bush.is_empty() or not target_plant.is_empty()
		elif not event.pressed:
			harvest_press = false
		mining_held = event.pressed and not player.paused and not player.inventory_open
		if not mining_held:
			reset_mining()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if player.paused or player.inventory_open or player.movement_blocked:
			return
		var boat_id: String=Boats.pick(self)
		if not boat_id.is_empty():
			Boats.board(self,boat_id)
			return
		if selected_kind()=="boat":
			launch_boat()
			return
		if selected_kind()=="bow":
			begin_bow_draw()
			return
		if selected_kind() in ["bucket","water_bucket"]:
			use_bucket()
			return
		if shear_cotton():
			return
		if feed_hen():
			planting_held=false
			return
		var from: Vector3 = player.camera.global_position
		var door_cell: Variant = Doors.pick(entity_system,from,from-player.camera.global_basis.z*INTERACTION_REACH,[player.get_rid()])
		if door_cell != null:
			Doors.toggle(entity_system,door_cell,player)
			return
		update_build_preview()
		if model.kind_at(target_cell) in Furnaces.PARTS:
			chest_ui.open(target_cell)
			return
		if selected_kind() in ["hoe","grass_seed","sapling","cotton_shoot"]:
			planting_held=true
			planting_last_key=""
			update_held_planting()
			return
		if selected_kind() == "blueberry":
			update_build_preview()
			berry_planting = target_bush.is_empty() and model.kind_at(target_cell) == "dirt" and target_normal.y > 0.5
			if berry_planting:
				planting_held=true
				planting_last_key=""
				update_held_planting()
			return
		update_build_preview()
		if model.kind_at(target_cell) in Doors.PARTS:
			Doors.toggle(entity_system,target_cell,player)
		elif model.kind_at(target_cell) in ["chest","furnace","furnace_lit"]:
			chest_ui.open(target_cell)
		elif model.kind_at(target_cell) == "workbench":
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

func use_bucket() -> bool:
	var start: Vector3=player.camera.global_position
	var finish: Vector3=start-player.camera.global_basis.z*INTERACTION_REACH
	var query:=PhysicsRayQueryParameters3D.create(start,finish,1,[player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		finish=hit.position
	var success: bool=false
	if selected_kind()=="bucket":
		var liquid: Dictionary=model.water.pick(start,finish,true)
		if not liquid.is_empty():
			success=model.water.take(liquid.cell)
	else:
		var liquid: Dictionary=model.water.pick(start,finish)
		if not liquid.is_empty():
			success=model.water.source(liquid.cell)
		elif not hit.is_empty():
			var cell:=Vector3i((hit.position+hit.normal*0.02).floor())
			success=model.water.source(cell)
	if success:
		inventory.slots[27+selected_hotbar]=Registry.stack("water_bucket" if selected_kind()=="bucket" else "bucket",1)
		update_counter()
	return success

func launch_boat() -> bool:
	var start: Vector3=player.camera.global_position
	var finish: Vector3=start-player.camera.global_basis.z*INTERACTION_REACH
	var query:=PhysicsRayQueryParameters3D.create(start,finish,1,[player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		finish=hit.position
	var water_hit: Dictionary=model.water.pick(start,finish)
	if water_hit.is_empty():
		return false
	var point: Vector3=Vector3(water_hit.cell)+Vector3(0.5,1,0.5)
	var id: String=Boats.launch(entity_system,point,player.rotation.y)
	if id.is_empty():
		return false
	inventory.take_from_slot(27+selected_hotbar)
	update_counter()
	return true

func update_torch_lighting() -> void:
	var sun: float=DayCycle.daylight(model)
	for node in get_tree().get_nodes_in_group("torch_lights"):
		if not is_ancestor_of(node):
			continue
		var exposed: float=daylight.exposure(node.global_position)
		# Daylight washes out the local glow outdoors; roofs and tunnels keep it.
		node.light_energy=0.36*lerpf(1.0,0.035,clampf(sun*exposed,0,1))

func debug_visit_terrain(kind: int, cave: bool=false) -> bool:
	if game_mode!="debug" or model.generator.version<4:
		message("Starta en ny debugvärld för att besöka terrängzonerna.")
		return false
	var rect: Rect2i=model.generator.zones.nearest_rect(Vector2(player.position.x,player.position.z),kind)
	var center: Vector2i=rect.get_center()
	var destination:=Vector3.ZERO
	var found: bool=false
	var cave_direction:=Vector3.FORWARD
	if cave:
		var tile:=Vector2i(floori(float(center.x)/64),floori(float(center.y)/64))
		for radius in range(17):
			for dx in range(-radius,radius+1):
				for dz in range(-radius,radius+1):
					if maxi(absi(dx),absi(dz))!=radius:
						continue
					var feature: Dictionary=model.generator.cave_for_tile(tile.x+dx,tile.y+dz)
					if not feature.is_empty():
						destination=Vector3(feature.center.x+0.5,feature.floor+0.05,feature.center.y+0.5)
						var look: Vector2=feature.get("look_direction",Vector2(feature.axis))
						cave_direction=Vector3(look.x,0,look.y)
						found=true
						break
				if found:
					break
			if found:
				break
	else:
		# A region centre may be a lake. Search its nearby dry terrain rather
		# than treating that as an unavailable biome.
		for radius in range(0,325,12):
			for i in range(16):
				var angle: float=TAU*i/16
				var x: int=center.x+roundi(cos(angle)*radius)
				var z: int=center.y+roundi(sin(angle)*radius)
				var y: int=model.generator.height(x,z)
				if y>=model.generator.SEA_LEVEL and model.kind_at(Vector3i(x,y,z))=="air" and model.kind_at(Vector3i(x,y+1,z))=="air":
					destination=Vector3(x+0.5,y+0.05,z+0.5)
					found=true
					break
			if found:
				break
	if not found:
		message("Hittade ingen lämplig besöksplats i zonen.")
		return false
	Boats.leave(self)
	if combat_debug.visible:
		toggle_combat_debug()
	player.position=destination
	if cave:
		player.rotation.y=atan2(-cave_direction.x,-cave_direction.z)
		player.camera.rotation=Vector3.ZERO
	player.velocity=Vector3.ZERO
	player.vitals.reset()
	player.reset_fall_tracking()
	player.movement_blocked=true
	streamer.warm_start(destination)
	entity_system.elapsed=1
	entity_system.tick(destination,0)
	player.movement_blocked=false
	light_elapsed=1
	if cave:
		for index in range(27,36):
			if inventory.slots[index].kind=="torch":
				selected_hotbar=index-27
				update_counter()
				break
	message("Besöker bergsgrotta." if cave else "Besöker %s."%model.generator.zones.NAMES[kind].to_lower())
	return true

func debug_return_home() -> bool:
	if game_mode!="debug":
		return false
	var points: Array[Vector3]=DeathDrops.land_points(model,player.respawn_position,5)
	if points.is_empty():
		message("Hittade ingen ledig, torr plats vid starten.")
		return false
	points.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.distance_squared_to(player.respawn_position)<b.distance_squared_to(player.respawn_position))
	Boats.leave(self)
	if combat_debug.visible:
		toggle_combat_debug()
	player.position=points[0]-Vector3.UP*0.11
	player.velocity=Vector3.ZERO
	player.vitals.reset()
	player.reset_fall_tracking()
	player.movement_blocked=true
	streamer.warm_start(player.position)
	entity_system.elapsed=1
	entity_system.tick(player.position,0)
	player.movement_blocked=false
	light_elapsed=1
	message("Tillbaka vid starten.")
	return true

func _process(delta: float) -> void:
	var stamp: int=PerfLog.begin()
	_measured_process(delta)
	PerfLog.finish("world_frame",stamp)
	if PerfLog.active and model!=null:
		PerfLog.frame({"position":[player.position.x,player.position.y,player.position.z],"view_distance":view_distance,"chunks":streamer.chunks.size(),"pending_chunks":streamer.tasks.size(),"mode":game_mode,"paused":player.paused,"inventory_open":player.inventory_open,"ai_searches":entity_system.ai_budget.total_searches,"ai_deferred":entity_system.ai_budget.total_deferred,"terrain_installs":streamer.last_installs,"nearby_zombies":entity_system.night_population.nearby_count,"night_target":entity_system.night_population.target_count})

func _physics_process(delta: float) -> void:
	var stamp: int=PerfLog.begin()
	_measured_physics_process(delta)
	PerfLog.finish("world_physics",stamp)

func update_daylight(delta: float) -> void:
	var stamp: int=PerfLog.begin()
	_measuredupdate_daylight(delta)
	PerfLog.finish("lighting",stamp)

# Used by Q and by inventory/storage dialogs when closing with an outside cursor.
func toss_stack(source: Dictionary, amount: int) -> bool:
	if source.get("count",0)<=0 or amount<=0:
		return false
	amount=mini(amount,int(source.count))
	var item: Dictionary=Registry.stack(source.kind,amount,source)
	var forward: Vector3=-player.camera.global_basis.z
	forward.y=0
	forward=forward.normalized()
	if forward.length_squared()<0.01:
		forward=-player.global_basis.z
	var origin: Vector3=player.position+Vector3.UP*0.8
	var point: Vector3=origin
	# Stop before walls instead of placing discarded items through them.
	for step in range(1,21):
		var candidate: Vector3=origin+forward*(step*0.1)
		if entity_system.drop_overlaps_block(candidate,0.16):
			break
		point=candidate
	var id: String=entity_system.spawn_drop(item.kind,point,amount)
	var record: Dictionary=model.entities[id]
	record.item=item
	record.ready_at=model.game_time+1.0
	record.ground_before_pickup=true
	record.needs_approach=true
	record.collection_origin=player.position
	record.state.velocity_x=forward.x*0.5
	record.state.velocity_z=forward.z*0.5
	source.count-=amount
	if source.count==0:
		Registry.clear_slot(source)
	return true

func drop_selected_stack(all_items: bool=false) -> bool:
	var target: Dictionary
	if player.inventory_open:
		if stack_cursor.held.count>0:
			target=stack_cursor.held
		else:
			var point: Vector2=get_viewport().get_mouse_position()
			var index: int=chest_ui.pointer_slot(point) if chest_ui.visible else slot_at_pointer(point)
			if index<0:
				return false
			target=stack_cursor.slot(index)
	else:
		target=inventory.slots[27+selected_hotbar]
	stack_cursor.cancel_paint()
	var dropped: bool=toss_stack(target,int(target.count) if all_items else 1)
	if dropped:
		update_counter()
	return dropped

func drop_outside_cursor(panel: Control) -> void:
	if stack_cursor.held.count>0 and not panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		stack_cursor.cancel_paint()
		toss_stack(stack_cursor.held,int(stack_cursor.held.count))

func begin_bow_draw() -> void:
	if player.paused or player.inventory_open or player.movement_blocked:
		return
	if inventory.count_item("arrow")<=0:
		message("Du saknar pilar.")
		return
	bow_drawing=true
	bow_charge=0

func update_bow_charge(delta: float) -> void:
	if selected_kind()!="bow" or player.paused or player.inventory_open or player.movement_blocked:
		bow_drawing=false
		bow_charge=0
	elif bow_drawing:
		bow_charge=minf(1,bow_charge+delta)

func shoot_bow(charge: float=1.0) -> bool:
	if selected_kind()!="bow" or player.paused or player.inventory_open or player.movement_blocked:
		return false
	if not inventory.take_item("arrow"):
		message("Du saknar pilar.")
		return false
	var stats: Dictionary=Combat.stats("player","bow")
	var direction: Vector3=-player.camera.global_basis.z
	var origin: Vector3=player.camera.global_position+direction*0.35
	entity_system.Arrows.spawn(entity_system,"player",origin,direction*lerpf(8,28,clampf(charge,0,1)),float(stats.attack)*lerpf(0.25,1,clampf(charge,0,1)),"player",6)
	attack_cooldown=0
	wear_selected_tool()
	update_counter()
	return true

func update_cotton_harvest(delta: float) -> void:
	if selected_kind()=="stone_shears":
		reset_mining()
		return
	harvest_press=true
	var record: Dictionary=model.entities[target_bush]
	if harvest_target!=target_bush:
		reset_mining()
		harvest_target=target_bush
	var shearing: bool=selected_kind()=="stone_shears"
	if shearing and model.game_time<float(record.ripe_at):
		reset_mining()
		mining_label.text="Bomullen är inte mogen ännu."
		return
	var seconds: float=0.7 if selected_kind() in ["shovel","stone_shears"] else 3.0
	mining_elapsed+=delta
	mining_bar.show()
	mining_bar.value=minf(100,mining_elapsed/seconds*100)
	mining_label.text="Klipper bomull" if shearing else "Gräver upp bomullsplanta"
	if mining_elapsed<seconds:
		return
	finish_cotton_harvest()

func shear_cotton() -> bool:
	if selected_kind()!="stone_shears":
		return false
	update_build_preview()
	if not model.entities.has(target_bush) or model.entities[target_bush].type!="cotton_plant":
		return false
	if model.game_time<float(model.entities[target_bush].ripe_at):
		message("Bomullen är inte mogen ännu.")
		return true
	finish_cotton_harvest()
	attack_animation=0.3
	return true

func finish_cotton_harvest() -> void:
	var record: Dictionary=model.entities[target_bush]
	var shearing: bool=selected_kind()=="stone_shears"
	var drops: Dictionary=Cotton.harvest(model,target_bush,selected_kind())
	for kind: String in drops:
		var drop: String=entity_system.spawn_drop(kind,record.position+Vector3(0,0.5,0),int(drops[kind]))
		model.entities[drop].ground_before_pickup=true
		model.entities[drop].needs_approach=true
		model.entities[drop].collection_origin=player.position
	if selected_kind() in ["shovel","stone_shears"]:
		wear_selected_tool()
	if shearing:
		entity_system.active[target_bush].refresh()
	else:
		entity_system.deactivate(target_bush)
		target_bush=""
		bush_focus.hide()
	harvest_target=""
	reset_mining()
	update_counter()
