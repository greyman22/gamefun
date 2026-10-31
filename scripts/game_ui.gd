extends Node3D

const Registry = preload("res://scripts/core/registry.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const HarvestRules = preload("res://scripts/harvest_rules.gd")
const ItemVisuals = preload("res://scripts/item_visuals.gd")
const InventorySlot = preload("res://scripts/inventory_slot.gd")
const CraftingScript = preload("res://scripts/crafting.gd")
const StackCursor = preload("res://scripts/core/stack_cursor.gd")
var stack_cursor = StackCursor.new()
var hover_panel: PanelContainer
var hover_label: Label
var cursor_visual: Control
var cursor_icon: TextureRect
var cursor_count: Label
var cursor_durability: ProgressBar
var result_press_position := Vector2.ZERO
var result_drag_moved: bool = false
var template_buttons: Array[Dictionary] = []
const HELD_ORIGIN := Vector3(0.32, -0.24, -0.65)
const HELD_ROTATION := Vector3(-18, 20, 8) * PI / 180.0
var swing_phase: float = 0
var swing_blend: float = 0
var inventory = InventoryScript.new()
var crafting = CraftingScript.new()
var crafting_slots: Array[PanelContainer] = []
var crafting_output: PanelContainer
var crafting_status: Label
var crafting_title: Label
var crafting_grid: GridContainer
var crafting_help: Label
var inventory_title: Label
var inventory_panel: PanelContainer
var inventory_slots: Array[PanelContainer] = []
var hotbar_slots: Array[PanelContainer] = []
var hotbar: HBoxContainer
var item_icons: Dictionary = {}
var item_materials: Dictionary = {}
var selected_hotbar: int = 0
var move_source: int = -1
var held_item: Node3D
var held_kind: String = "uninitialized"
var active_tool: String = "hand"
var player: CharacterBody3D
var preview: Node3D
var bush_focus: Node3D
var prompt: Label
var block_grass: Material
var block_dirt: Material
var mining_bar: ProgressBar
var mining_label: Label
var mining_held: bool = false
var mining_elapsed: float = 0
var mining_cell := Vector3i(0, -1000, 0)
func make_material(color: Color, noise_scale: float, contrast: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = noise_scale
	var ramp := Gradient.new()
	ramp.set_color(0, contrast)
	ramp.set_color(1, Color.WHITE)
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.color_ramp = ramp
	texture.generate_mipmaps = true
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func box(parent: Node3D, center: Vector3, size: Vector3, material: Material, solid: bool = false) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = center
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return body

func build_outline() -> void:
	preview = Node3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.35)
	# A square outline in the local XY plane marks only the selected face.
	for axis in range(2):
		for side in [-0.5, 0.5]:
			var center := Vector3.ZERO
			center[1 - axis] = side
			var size := Vector3.ONE * 0.012
			size[axis] = 1.0
			var edge := box(preview, center, size, material)
			(edge.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.visible = false
	add_child(preview)
	bush_focus = Node3D.new()
	for axis in range(3):
		for first in [-0.5, 0.5]:
			for second in [-0.5, 0.5]:
				var center := Vector3.ZERO
				center[(axis + 1) % 3] = first
				center[(axis + 2) % 3] = second
				var dimensions := Vector3.ONE * 0.012
				dimensions[axis] = 1
				var edge := box(bush_focus, center, dimensions, material)
				(edge.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bush_focus.hide()
	add_child(bush_focus)

func label(text_value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color.WHITE)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	result.add_theme_constant_override("shadow_offset_x", 2)
	result.add_theme_constant_override("shadow_offset_y", 2)
	return result

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	update_counter()
	# A geometric reticle avoids font baseline offsets; aim is seven pixels above it.
	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -7
	crosshair.offset_right = 7
	crosshair.offset_top = 0
	crosshair.offset_bottom = 14
	for rect in [Rect2(6, 1, 2, 12), Rect2(1, 6, 12, 2)]:
		var shadow := ColorRect.new()
		shadow.position = rect.position + Vector2.ONE
		shadow.size = rect.size
		shadow.color = Color(0, 0, 0, 0.7)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(shadow)
		var line := ColorRect.new()
		line.position = rect.position
		line.size = rect.size
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(line)
	prompt = label("", 19)
	root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -520
	prompt.offset_right = 520
	prompt.offset_top = -187
	prompt.offset_bottom = -152
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mining_bar = ProgressBar.new()
	root.add_child(mining_bar)
	mining_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	mining_bar.offset_left = -180
	mining_bar.offset_right = 180
	mining_bar.offset_top = -222
	mining_bar.offset_bottom = -206
	mining_bar.show_percentage = false
	mining_bar.visible = false
	mining_label = label("", 18)
	root.add_child(mining_label)
	mining_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	mining_label.offset_left = -240
	mining_label.offset_right = 240
	mining_label.offset_top = -257
	mining_label.offset_bottom = -227
	mining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_inventory_ui(root)
	build_hotbar(root)
	build_cursor_visual()
	update_counter()

func build_inventory_ui(root: Control) -> void:
	inventory_panel = PanelContainer.new()
	root.add_child(inventory_panel)
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.offset_left = -610
	inventory_panel.offset_right = 610
	inventory_panel.offset_top = -315
	inventory_panel.offset_bottom = 315
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.1, 1.0)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	inventory_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	inventory_panel.add_child(column)
	inventory_title = label("FÖREMÅL — 36 platser", 26)
	column.add_child(inventory_title)
	column.add_child(label("Vänster: lyft / fördela • Höger: dela stapel • Shift-klick: flytta till arbetsytan", 16))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	column.add_child(content)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for index in range(36):
		var panel := InventorySlot.new()
		panel.world = self
		panel.slot_index = index
		panel.custom_minimum_size = Vector2(68, 68)
		grid.add_child(panel)
		inventory_slots.append(panel)
	build_crafting_ui(content)
	build_recipe_list(content)
	column.add_child(label("Nedersta raden = snabbval 1–9 • Tom plats = hand • E / Esc stänger", 17))
	inventory_panel.visible = false

func build_crafting_ui(parent: Control) -> void:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 200
	side.add_theme_constant_override("separation", 8)
	parent.add_child(side)
	crafting_title = label("TILLVERKA  2 × 2", 20)
	side.add_child(crafting_title)
	crafting_grid = GridContainer.new()
	crafting_grid.add_theme_constant_override("h_separation", 8)
	crafting_grid.add_theme_constant_override("v_separation", 8)
	side.add_child(crafting_grid)
	side.add_child(label("↓  RESULTAT (dra / shift: alla)", 16))
	crafting_output = InventorySlot.new()
	crafting_output.world = self
	crafting_output.result_slot = true
	crafting_output.custom_minimum_size = Vector2(64, 64)
	crafting_output.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(crafting_output)
	crafting_status = label("Lyft en stapel och håll vänster\nför att fördela över flera rutor.", 14)
	crafting_status.custom_minimum_size.x = 200
	crafting_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(crafting_status)
	crafting_help = label("", 14)
	side.add_child(crafting_help)
	rebuild_crafting_slots()

func rebuild_crafting_slots() -> void:
	for slot in crafting_slots:
		crafting_grid.remove_child(slot)
		slot.queue_free()
	crafting_slots.clear()
	crafting_grid.columns = crafting.width
	for index in range(crafting.slots.size()):
		var slot := InventorySlot.new()
		slot.world = self
		slot.slot_index = 36 + index
		slot.custom_minimum_size = Vector2(56, 56)
		crafting_grid.add_child(slot)
		crafting_slots.append(slot)
	crafting_output.slot_index = 36 + crafting.slots.size()
	crafting_title.text = "ARBETSBÄNK  3 × 3" if crafting.width == 3 else "TILLVERKA  2 × 2"
	inventory_title.text = "ARBETSBÄNK OCH INVENTARIUM" if crafting.width == 3 else "FÖREMÅL — 36 platser"
	crafting_help.text = "Välj en receptmall till höger.\nDra resultatet till en ledig plats." if crafting.width == 3 else "1 stam → 4 träklossar\n2 klossar på höjden → 4 pinnar\n4 klossar i fyrkant → arbetsbänk"
	crafting_status.text = "Lyft en stapel och håll vänster\nför att fördela över flera rutor."

func build_cursor_visual() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	cursor_visual = Control.new()
	cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cursor_visual)
	cursor_icon = TextureRect.new()
	cursor_icon.custom_minimum_size = Vector2(48, 48)
	cursor_icon.size = Vector2(48, 48)
	cursor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_visual.add_child(cursor_icon)
	cursor_count = label("", 18)
	cursor_count.position = Vector2(24, 24)
	cursor_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_visual.add_child(cursor_count)
	cursor_durability = ProgressBar.new()
	cursor_durability.position = Vector2(2, 45)
	cursor_durability.size = Vector2(44, 4)
	cursor_durability.show_percentage = false
	cursor_durability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_visual.add_child(cursor_durability)
	cursor_visual.visible = false
	hover_panel = PanelContainer.new()
	hover_panel.name = "InventoryHover"
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.035, 0.05, 0.04, 0.97)
	tooltip_style.border_color = Color(0.5, 0.6, 0.5)
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_content_margin_all(10)
	hover_panel.add_theme_stylebox_override("panel", tooltip_style)
	hover_label = label("", 16)
	hover_label.custom_minimum_size.x = 320
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.add_child(hover_label)
	layer.add_child(hover_panel)
	hover_panel.hide()

func build_recipe_list(parent: Control) -> void:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 168
	side.add_theme_constant_override("separation", 4)
	parent.add_child(side)
	side.add_child(label("RECEPT", 20))
	var seen: Dictionary = {}
	for recipe: Dictionary in Registry.catalog.recipes:
		if seen.has(recipe.kind):
			continue
		seen[recipe.kind] = true
		var button := Button.new()
		button.custom_minimum_size = Vector2(168, 38)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 7
		row.offset_right = -7
		row.offset_top = 5
		row.offset_bottom = -5
		var icon := TextureRect.new()
		icon.texture = item_icons.get(recipe.kind)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var text := label("%d × %s" % [recipe.count, Registry.label(recipe.kind)], 14)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(text)
		button.tooltip_text = "Klicka för att lägga ingredienserna i arbetsytan"
		button.pressed.connect(func() -> void: fill_recipe_template(recipe))
		side.add_child(button)
		template_buttons.append({"button": button, "recipe": recipe})
	var hint := label("Dimmad = resurser saknas\neller kräver arbetsbänk", 13)
	side.add_child(hint)

func fill_recipe_template(recipe: Dictionary) -> void:
	stack_cursor.bind(inventory, crafting)
	if stack_cursor.fill_template(recipe):
		crafting_status.text = "Ingredienserna är på plats.\nDra resultatet till en ledig plats."
	else:
		crafting_status.text = "Resurser eller ledigt utrymme saknas."
	update_counter()

func update_inventory_hover() -> void:
	if not is_instance_valid(hover_panel):
		return
	hover_panel.hide()
	if not player.inventory_open:
		return
	var point := get_viewport().get_mouse_position()
	var widgets: Array = []
	var storage_ui: Node = get("chest_ui")
	if is_instance_valid(storage_ui) and storage_ui.visible:
		widgets.assign(storage_ui.widgets)
	else:
		widgets.assign(inventory_slots)
		widgets.append_array(crafting_slots)
		widgets.append(crafting_output)
	for widget: Control in widgets:
		if is_instance_valid(widget) and widget.is_visible_in_tree() and widget.get_global_rect().has_point(point):
			hover_label.text = widget.tooltip_text
			hover_panel.reset_size()
			var bounds := get_viewport().get_visible_rect().size
			hover_panel.position = Vector2(clampf(point.x + 18, 0, maxf(0, bounds.x - hover_panel.size.x - 8)), clampf(point.y + 22, 0, maxf(0, bounds.y - hover_panel.size.y - 8)))
			hover_panel.show()
			return

func update_cursor_visual() -> void:
	if not is_instance_valid(cursor_visual):
		return
	update_inventory_hover()
	cursor_visual.visible = player.inventory_open and stack_cursor.held.count > 0
	cursor_visual.position = get_viewport().get_mouse_position() - cursor_icon.size * 0.5
	cursor_icon.texture = item_icons.get(stack_cursor.held.kind)
	var plan: Dictionary = stack_cursor.preview()
	cursor_count.text = str(plan.held.count) if plan.held.count > 0 and not Registry.tool(stack_cursor.held.kind) else ""
	cursor_icon.modulate.a = 0.65 if stack_cursor.left_down and plan.held.count == 0 else 1.0
	cursor_durability.visible = false
	if stack_cursor.held.count > 0 and Registry.tool(stack_cursor.held.kind):
		var maximum: int = int(stack_cursor.held.get("max_durability", Registry.durability_max(stack_cursor.held.kind)))
		var ratio: float = float(Registry.remaining_uses(stack_cursor.held)) / maximum
		cursor_durability.visible = ratio < 1
		cursor_durability.value = ratio * 100
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1, 0.16, 0.1, 0.8) if ratio < 0.1 else (Color(1, 0.8, 0.1, 0.8) if ratio < 0.3 else Color(0.65, 0.95, 0.75, 0.65))
		cursor_durability.add_theme_stylebox_override("fill", fill)

func slot_at_pointer(point: Vector2) -> int:
	for slot in inventory_slots + crafting_slots:
		if slot.is_visible_in_tree() and slot.get_global_rect().has_point(point):
			return slot.slot_index
	return -1

func inventory_pointer_press(index: int, button: int, shift: bool) -> void:
	stack_cursor.bind(inventory, crafting)
	stack_cursor.press(index, button, shift)
	update_counter()

func handle_inventory_event(event: InputEvent) -> bool:
	if not player.inventory_open:
		return false
	stack_cursor.bind(inventory, crafting)
	if event is InputEventMouseMotion:
		if stack_cursor.result_drag and event.position.distance_to(result_press_position) > 6:
			result_drag_moved = true
		stack_cursor.touch(slot_at_pointer(event.position))
		refresh_slots()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and stack_cursor.left_down:
		stack_cursor.touch(slot_at_pointer(event.position))
		var cancelled_result: bool = stack_cursor.result_drag and stack_cursor.painted.is_empty() and result_drag_moved
		stack_cursor.finish()
		if cancelled_result and not stack_cursor.store_held():
			crafting_status.text = "Inventariet är fullt. Välj en plats för resultatet."
		update_counter()
		return true
	return false

func slot_data(index: int) -> Dictionary:
	if index >= 36 and index < 36 + crafting.slots.size():
		return crafting.slots[index - 36]
	return inventory.slots[index]

func craft_result(all_batches: bool = false) -> void:
	if not player.inventory_open:
		return
	stack_cursor.bind(inventory, crafting)
	var result: Dictionary = crafting.recipe()
	if stack_cursor.held.count > 0:
		crafting_status.text = "Placera föremålen du håller först."
	elif result.is_empty():
		crafting_status.text = "Lägg ingredienser i tillverkningsrutorna."
	else:
		var amount: int = stack_cursor.take_result(all_batches)
		if amount > 0:
			result_press_position = get_viewport().get_mouse_position()
			result_drag_moved = false
			crafting_status.text = "Tillverkade %d × %s. Välj en plats." % [amount, Registry.label(result.kind)]
		else:
			crafting_status.text = "Resultatet kunde inte tillverkas."
	move_source = -1
	update_counter()

func build_hotbar(root: Control) -> void:
	hotbar = HBoxContainer.new()
	root.add_child(hotbar)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -384
	hotbar.offset_right = 384
	hotbar.offset_top = -96
	hotbar.offset_bottom = -16
	hotbar.add_theme_constant_override("separation", 6)
	for index in range(9):
		var slot := InventorySlot.new()
		slot.world = self
		slot.slot_index = 27 + index
		slot.draggable = false
		slot.custom_minimum_size = Vector2(80, 80)
		hotbar.add_child(slot)
		hotbar_slots.append(slot)

func selected_kind() -> String:
	var slot: Dictionary = inventory.slots[27 + selected_hotbar]
	return slot.kind if slot.count > 0 else ""

func select_hotbar(index: int) -> void:
	selected_hotbar = posmod(index, 9)
	reset_mining()
	update_counter()

func inventory_slot_clicked(index: int, movable: bool) -> void:
	if not movable:
		select_hotbar(index - 27)
		return
	if move_source >= 0:
		move_inventory(move_source, index)
	else:
		if index >= 27 and index < 36:
			select_hotbar(index - 27)
		if slot_data(index).count > 0:
			move_source = index
		refresh_slots()

func move_inventory(source: int, destination: int) -> void:
	crafting.transfer(inventory, source, destination)
	move_source = -1
	reset_mining()
	update_counter()

func refresh_slots() -> void:
	stack_cursor.bind(inventory, crafting)
	var planned: Dictionary = stack_cursor.preview().slots
	var kind := selected_kind()
	active_tool = kind if Registry.tool(kind) else "hand"
	for index in range(inventory_slots.size()):
		inventory_slots[index].refresh(planned.get(index, inventory.slots[index]), index == selected_hotbar + 27, stack_cursor.painted.has(index))
	for index in range(hotbar_slots.size()):
		hotbar_slots[index].refresh(planned.get(index + 27, inventory.slots[index + 27]), index == selected_hotbar)
	for index in range(crafting_slots.size()):
		crafting_slots[index].refresh(planned.get(index + 36, crafting.slots[index]), false, stack_cursor.painted.has(index + 36))
	if is_instance_valid(crafting_output):
		var result: Dictionary = crafting.recipe()
		crafting_output.refresh(result if not result.is_empty() else {"kind": "", "count": 0}, not result.is_empty())
		crafting_output.tooltip_text += "\nDra till valfri plats. Shift: tillverka alla."
	if is_instance_valid(hotbar):
		hotbar.visible = not player.inventory_open
	update_held_item()
	for entry: Dictionary in template_buttons:
		var enabled: bool = stack_cursor.can_fill(entry.recipe)
		entry.button.disabled = not enabled
		entry.button.modulate = Color(1, 1, 1, 1 if enabled else 0.4)
		var needed: Dictionary = stack_cursor.requirements(entry.recipe)
		var tooltip: String = "Kräver arbetsbänk\n" if int(entry.recipe.width) > crafting.width else "Klicka för att fylla arbetsytan\n"
		for ingredient: String in needed:
			tooltip += "%d × %s\n" % [needed[ingredient], Registry.label(ingredient)]
		entry.button.tooltip_text = tooltip.strip_edges()
	update_cursor_visual()

func update_held_item() -> void:
	var kind := selected_kind()
	if kind != held_kind:
		if is_instance_valid(held_item):
			held_item.free()
		held_item = Node3D.new()
		player.camera.add_child(held_item)
		held_item.position = HELD_ORIGIN
		held_item.rotation = HELD_ROTATION
		swing_phase = 0
		swing_blend = 0
		if kind == "raw_chicken":
			ItemVisuals.raw_chicken_model(held_item)
		elif kind == "egg":
			ItemVisuals.egg_model(held_item)
		elif kind == "blueberry":
			ItemVisuals.blueberry_model(held_item)
		elif kind == "soul_remnant":
			ItemVisuals.soul_remnant_model(held_item)
		elif Registry.tool(kind):
			ItemVisuals.tool_model(held_item, kind)
		elif kind == "torch":
			ItemVisuals.torch_model(held_item)
		elif kind == "stick":
			ItemVisuals.stick_model(held_item)
		elif kind != "":
			var material: Material = item_materials.get(kind, block_dirt)
			box(held_item, Vector3.ZERO, Vector3.ONE * 0.2, material)
			if kind == "workbench":
				ItemVisuals.workbench_details(held_item, 0.2)
			if kind == "dirt":
				var visual := held_item.get_child(0).get_child(0) as MeshInstance3D
				(visual.mesh as BoxMesh).size.y = 0.176
				visual.position.y = -0.012
				box(held_item, Vector3(0, 0.088, 0), Vector3(0.2, 0.024, 0.2), block_grass)
		else:
			var skin := StandardMaterial3D.new()
			skin.albedo_color = Color(0.83, 0.6, 0.42)
			skin.roughness = 0.9
			box(held_item, Vector3.ZERO, Vector3(0.09, 0.11, 0.055), skin)
			box(held_item, Vector3(0, -0.08, 0.01), Vector3(0.065, 0.08, 0.055), skin)
			for finger in range(4):
				box(held_item, Vector3(-0.033 + finger * 0.022, 0.068, 0), Vector3(0.018, 0.045, 0.045), skin)
			var thumb := box(held_item, Vector3(-0.057, -0.005, 0), Vector3(0.035, 0.055, 0.045), skin)
			thumb.rotation.z = -0.5
		var arm_skin := StandardMaterial3D.new()
		arm_skin.albedo_color = Color(0.83, 0.6, 0.42)
		arm_skin.roughness = 0.9
		box(held_item, Vector3(0, -0.2, 0.025), Vector3(0.075, 0.21, 0.07), arm_skin)
		if kind != "":
			box(held_item, Vector3(0, -0.085, 0.015), Vector3(0.085, 0.075, 0.075), arm_skin)
		for part in held_item.find_children("*", "MeshInstance3D", true, false):
			(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Render equipment over the world so close tunnel walls cannot hide it.
			var held_material := (part as MeshInstance3D).get_active_material(0).duplicate() as StandardMaterial3D
			held_material.no_depth_test = true
			held_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			held_material.render_priority = 127
			(part as MeshInstance3D).material_override = held_material
		held_kind = kind
	if is_instance_valid(held_item):
		held_item.visible = not player.inventory_open

func update_hand_animation(delta: float, working: bool) -> void:
	if not is_instance_valid(held_item):
		return
	swing_blend = move_toward(swing_blend, 1.0 if working else 0.0, delta * 7.0)
	if working or swing_blend > 0:
		swing_phase += delta * 11.0
	else:
		swing_phase = 0
	var stroke: float = sin(swing_phase)
	var motion := Vector3(-0.012 * (1 - cos(swing_phase)), stroke * 0.045, -0.02 * (1 - cos(swing_phase))) * swing_blend
	var rotation_offset := Vector3(stroke * 0.23, 0, cos(swing_phase) * 0.07) * swing_blend
	var weight: float = 1.0 - exp(-18.0 * delta)
	held_item.position = held_item.position.lerp(HELD_ORIGIN + motion, weight)
	held_item.rotation = held_item.rotation.lerp(HELD_ROTATION + rotation_offset, weight)

func toggle_inventory(workbench: bool = false) -> void:
	stack_cursor.bind(inventory, crafting)
	if player.inventory_open and not stack_cursor.return_all():
		crafting_status.text = "Materialen får inte plats.\nFrigör plats innan du stänger."
		move_source = -1
		update_counter()
		return
	if not player.inventory_open:
		var grid_width: int = 3 if workbench else 2
		if crafting.width != grid_width:
			crafting = CraftingScript.new(grid_width)
			rebuild_crafting_slots()
	player.inventory_open = not player.inventory_open
	inventory_panel.visible = player.inventory_open
	prompt.visible = not player.inventory_open
	move_source = -1
	player.jump_requested = false
	mining_held = false
	reset_mining()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.inventory_open or player.paused else Input.MOUSE_MODE_CAPTURED
	update_counter()

func update_counter() -> void:
	var kind := selected_kind()
	active_tool = kind if Registry.tool(kind) else "hand"
	refresh_slots()

func reset_mining() -> void:
	mining_elapsed = 0.0
	mining_cell = Vector3i(0, -100, 0)
	mining_bar.visible = false
	mining_label.text = ""
