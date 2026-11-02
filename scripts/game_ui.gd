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
var recipe_search: LineEdit
var recipe_scroll: ScrollContainer
var recipe_empty: Label
var recipe_grid: GridContainer
var recipe_available: CheckBox
var recipe_tabs: Array[Button] = []
var recipe_category: String = "all"
var recipe_toggle: Button
var recipe_panel_open: bool = true
var recipe_panel: PanelContainer
var work_panel: PanelContainer
const ARM_ANCHOR_LOCAL := Vector3(0,-0.305,0.025)
const ARM_ANCHOR_SCREEN := Vector2(1.02,1.08)
const ARM_ANCHOR_DEPTH := 0.24
const HELD_SCALE := 1.2
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
var held_arm_upper: Node3D
var held_arm_fore: Node3D
var arm_shoulder_position := Vector3.ZERO
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
	material.albedo_color = Color(0.76,0.73,0.45,0.42)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	# A square outline in the local XY plane marks only the selected face.
	for axis in range(2):
		for side in [-0.5, 0.5]:
			var center := Vector3.ZERO
			center[1 - axis] = side
			var size := Vector3.ONE * 0.006
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
				var dimensions := Vector3.ONE * 0.006
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

func crafting_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.055,0.085,0.07)
	style.border_color=Color(0.22,0.29,0.24)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",style)
	return panel

func build_inventory_ui(root: Control) -> void:
	inventory_panel=PanelContainer.new()
	root.add_child(inventory_panel)
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.offset_left=-610
	inventory_panel.offset_right=610
	inventory_panel.offset_top=-315
	inventory_panel.offset_bottom=315
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.08,0.12,0.1,1)
	style.set_content_margin_all(18)
	inventory_panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	inventory_panel.add_child(column)
	inventory_title=label("F\u00d6REM\u00c5L \u2014 36 platser",24)
	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	column.add_child(header)
	inventory_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(inventory_title)
	recipe_toggle=Button.new()
	recipe_toggle.toggle_mode=true
	recipe_toggle.button_pressed=recipe_panel_open
	recipe_toggle.add_theme_font_size_override("font_size",15)
	recipe_toggle.custom_minimum_size.x=130
	recipe_toggle.toggled.connect(set_recipe_panel_visible)
	header.add_child(recipe_toggle)
	column.add_child(label("V\u00e4nster: lyft / f\u00f6rdela \u2022 H\u00f6ger: dela stapel \u2022 Shift-klick: flytta",14))
	var content:=HBoxContainer.new()
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	column.add_child(content)
	recipe_panel=crafting_panel()
	content.add_child(recipe_panel)
	build_recipe_list(recipe_panel)
	work_panel=crafting_panel()
	content.add_child(work_panel)
	var work:=VBoxContainer.new()
	work.add_theme_constant_override("separation",12)
	work_panel.add_child(work)
	build_crafting_ui(work)
	work.add_child(label("INVENTARIUM",16))
	var grid:=GridContainer.new()
	grid.columns=9
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	work.add_child(grid)
	for index in range(36):
		var panel:=InventorySlot.new()
		panel.world=self
		panel.slot_index=index
		panel.custom_minimum_size=Vector2(52,52)
		grid.add_child(panel)
		inventory_slots.append(panel)
	column.add_child(label("Nedersta raden = snabbval 1\u20139 \u2022 Tom plats = hand \u2022 E / Esc st\u00e4nger",14))
	set_recipe_panel_visible(recipe_panel_open)
	inventory_panel.visible=false

func set_recipe_panel_visible(opened: bool) -> void:
	recipe_panel_open=opened
	recipe_panel.visible=opened
	recipe_toggle.set_pressed_no_signal(opened)
	recipe_toggle.text="D\u00f6lj recept" if opened else "Visa recept"
	var half_width: float=610 if opened else 350
	inventory_panel.offset_left=-half_width
	inventory_panel.offset_right=half_width

func build_crafting_ui(parent: Control) -> void:
	crafting_title=label("TILLVERKA  2 \u00d7 2",19)
	parent.add_child(crafting_title)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	parent.add_child(row)
	crafting_grid=GridContainer.new()
	crafting_grid.add_theme_constant_override("h_separation",6)
	crafting_grid.add_theme_constant_override("v_separation",6)
	row.add_child(crafting_grid)
	var result:=VBoxContainer.new()
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("separation",6)
	row.add_child(result)
	result.add_child(label("RESULTAT",15))
	crafting_output=InventorySlot.new()
	crafting_output.world=self
	crafting_output.result_slot=true
	crafting_output.custom_minimum_size=Vector2(56,56)
	crafting_output.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	result.add_child(crafting_output)
	crafting_status=label("",13)
	crafting_status.custom_minimum_size.x=210
	crafting_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.add_child(crafting_status)
	crafting_help=label("",13)
	crafting_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.add_child(crafting_help)
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
		slot.custom_minimum_size = Vector2(50, 50)
		crafting_grid.add_child(slot)
		crafting_slots.append(slot)
	crafting_output.slot_index = 36 + crafting.slots.size()
	crafting_title.text = "ARBETSBÄNK  3 × 3" if crafting.width == 3 else "TILLVERKA  2 × 2"
	inventory_title.text = "ARBETSBÄNK OCH INVENTARIUM" if crafting.width == 3 else "FÖREMÅL — 36 platser"
	crafting_help.text = "Shift-klick p\u00e5 resultatet: tillverka alla."
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
	var layout:=HBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	parent.add_child(layout)
	var tabs:=VBoxContainer.new()
	tabs.custom_minimum_size.x=80
	tabs.add_theme_constant_override("separation",8)
	layout.add_child(tabs)
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=68
	tabs.add_child(spacer)
	var group:=ButtonGroup.new()
	var categories: Array[String]=["all","tools","materials","food","reserved"]
	var titles: Array[String]=["Alla","Verktyg","Material","Mat","..."]
	for i in range(categories.size()):
		var tab:=Button.new()
		tab.text=titles[i]
		tab.custom_minimum_size=Vector2(80,48)
		tab.add_theme_font_size_override("font_size",14)
		tab.toggle_mode=true
		tab.button_group=group
		tab.button_pressed=i==0
		tab.disabled=i>=4
		tab.tooltip_text="Fler kategorier kommer senare" if i>=4 else titles[i]
		var category: String=categories[i]
		tab.pressed.connect(func() -> void: select_recipe_category(category))
		tabs.add_child(tab)
		recipe_tabs.append(tab)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	layout.add_child(body)
	body.add_child(label("RECEPT",20))
	var filters:=HBoxContainer.new()
	filters.add_theme_constant_override("separation",8)
	body.add_child(filters)
	recipe_available=CheckBox.new()
	recipe_available.text="Visa bara tillverkningsbara"
	recipe_available.add_theme_font_size_override("font_size",14)
	recipe_available.toggled.connect(func(_value: bool) -> void: apply_recipe_filters(true))
	recipe_search=LineEdit.new()
	recipe_search.placeholder_text="S\u00f6k recept..."
	recipe_search.clear_button_enabled=true
	recipe_search.add_theme_font_size_override("font_size",15)
	recipe_search.text_changed.connect(filter_recipes)
	recipe_search.custom_minimum_size.x=160
	recipe_search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	filters.add_child(recipe_search)
	filters.add_child(recipe_available)
	recipe_scroll=ScrollContainer.new()
	recipe_scroll.custom_minimum_size=Vector2(424,300)
	recipe_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	recipe_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	recipe_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(recipe_scroll)
	recipe_grid=GridContainer.new()
	recipe_grid.columns=4
	recipe_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation",8)
	recipe_grid.add_theme_constant_override("v_separation",8)
	recipe_scroll.add_child(recipe_grid)
	var seen: Dictionary={}
	for recipe: Dictionary in Registry.catalog.recipes:
		if seen.has(recipe.kind):
			continue
		seen[recipe.kind]=true
		var button:=Button.new()
		button.custom_minimum_size=Vector2(96,80)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var icon:=TextureRect.new()
		icon.texture=item_icons.get(recipe.kind)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left=16
		icon.offset_right=-16
		icon.offset_top=8
		icon.offset_bottom=-12
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var count:=label(str(int(recipe.count)) if int(recipe.count)>1 else "",16)
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_right=-6
		count.offset_bottom=-3
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
		count.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		button.pressed.connect(func() -> void: fill_recipe_template(recipe))
		recipe_grid.add_child(button)
		template_buttons.append({"button":button,"recipe":recipe})
	recipe_empty=label("Inga recept matchar dina val",14)
	recipe_empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(recipe_empty)
	recipe_empty.hide()
	body.add_child(label("H\u00e5ll musen \u00f6ver en ikon f\u00f6r namn och ingredienser",12))

func recipe_category_for(kind: String) -> String:
	if Registry.tool(kind):
		return "tools"
	if Registry.catalog.items.get(kind,{}).get("category","") in ["food","tools"]:
		return Registry.catalog.items[kind].category
	return "materials"

func recipe_matches_category(kind: String) -> bool:
	return recipe_category=="all" or recipe_category_for(kind)==recipe_category

func select_recipe_category(category: String) -> void:
	recipe_category=category
	var categories: Array[String]=["all","tools","materials","food","reserved"]
	for i in range(recipe_tabs.size()):
		recipe_tabs[i].set_pressed_no_signal(categories[i]==category)
	apply_recipe_filters(true)

func filter_recipes(query: String) -> void:
	# Also supports callers that pass a query directly, without a text event.
	if recipe_search.text!=query:
		recipe_search.set_block_signals(true)
		recipe_search.text=query
		recipe_search.set_block_signals(false)
	apply_recipe_filters(true,query)

func apply_recipe_filters(reset_scroll: bool=false, query: Variant=null) -> void:
	if not is_instance_valid(recipe_search) or not is_instance_valid(recipe_empty):
		return
	var term: String=(recipe_search.text if query==null else str(query)).strip_edges().to_lower()
	var count: int=0
	for entry: Dictionary in template_buttons:
		var matches: bool=(term.is_empty() or Registry.label(entry.recipe.kind).to_lower().contains(term)) and recipe_matches_category(entry.recipe.kind)
		if recipe_available.button_pressed and not stack_cursor.can_fill(entry.recipe):
			matches=false
		entry.button.visible=matches
		if matches:
			count+=1
	recipe_empty.visible=count==0
	if reset_scroll:
		recipe_scroll.scroll_vertical=0

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
		var tooltip: String = "%s \u00d7 %d\n"%[Registry.label(entry.recipe.kind),int(entry.recipe.count)]
		tooltip += "Kräver arbetsbänk\n" if int(entry.recipe.width) > crafting.width else "Klicka för att fylla arbetsytan\n"
		for ingredient: String in needed:
			tooltip += "%d × %s\n" % [needed[ingredient], Registry.label(ingredient)]
		entry.button.tooltip_text = tooltip.strip_edges()
	apply_recipe_filters()
	update_cursor_visual()

func update_held_item() -> void:
	var kind := selected_kind()
	if kind != held_kind:
		if is_instance_valid(held_item):
			held_item.free()
		held_item = Node3D.new()
		held_item.scale = Vector3.ONE*HELD_SCALE
		player.camera.add_child(held_item)
		held_arm_upper = null
		held_arm_fore = null
		swing_phase = 0
		swing_blend = 0
		if kind=="furnace":
			ItemVisuals.furnace_model(held_item)
		elif kind=="boat":
			ItemVisuals.boat_model(held_item,0.12)
		elif kind=="sapling":
			ItemVisuals.sapling_model(held_item)
		elif kind in ["bucket","water_bucket"]:
			ItemVisuals.bucket_model(held_item,kind=="water_bucket")
		elif kind=="coal":
			ItemVisuals.coal_model(held_item)
		elif kind == "gate":
			ItemVisuals.gate_model(held_item,0.15)
		elif kind == "fence":
			ItemVisuals.fence_model(held_item,0.15)
		elif kind == "foliage":
			ItemVisuals.branch_model(held_item)
		elif kind == "planks":
			ItemVisuals.plank_model(held_item)
		elif kind == "door":
			ItemVisuals.door_model(held_item,0.13)
		elif kind == "raw_chicken":
			ItemVisuals.raw_chicken_model(held_item)
		elif kind == "egg":
			ItemVisuals.egg_model(held_item)
		elif kind in ["grass_seed","grain","bread"]:
			ItemVisuals.farm_item_model(held_item,kind)
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
			if kind == "wood":
				ItemVisuals.log_details(held_item,0.2)
			elif kind == "soul_block":
				ItemVisuals.soul_block_details(held_item,0.2)
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
		held_arm_upper = box(held_item,Vector3.ZERO,Vector3(0.075,1,0.07),arm_skin)
		held_arm_fore = box(held_item,Vector3.ZERO,Vector3(0.065,1,0.06),arm_skin)
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
		reset_held_pose()
	if is_instance_valid(held_item):
		held_item.visible = not player.inventory_open

# All tools and the forearm share one camera-space diagonal swing.
# Tip offsets describe model geometry only; animation has no tool/target branches.
func held_tip_local() -> Vector3:
	return ItemVisuals.TOOL_TIPS.get(selected_kind(),Vector3(0,0.09,0))

func camera_point(screen: Vector2, depth: float) -> Vector3:
	var size: Vector2 = player.camera.get_viewport().get_visible_rect().size
	return player.camera.to_local(player.camera.project_position(size*screen,depth))

func pose_arm_segment(segment: Node3D, start: Vector3, finish: Vector3) -> void:
	if not is_instance_valid(segment):
		return
	# The tool has its own wrist rotation. Arm bones are independently posed
	# in camera space, then converted to the tool parent's local space.
	var direction: Vector3 = finish-start
	var camera_pose := Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized())).scaled(Vector3(1,direction.length(),1)),(start+finish)*0.5)
	segment.transform = held_item.transform.affine_inverse()*camera_pose

func apply_tool_action(progress: float, blend: float = 1.0) -> void:
	var sweep: float = clampf((progress-0.08)/0.84,0,1)
	var extension: float = (1.0-cos(sweep*TAU))*0.5*blend
	var grip_local := Vector3(0,-0.075,0)
	var rest_rotation := Quaternion.from_euler(Vector3(-0.1,0.1,-0.3))
	var impact_rotation := Quaternion.from_euler(Vector3(-1.0,0.5,0.3))
	var rest_grip: Vector3 = camera_point(Vector2(0.91,1.30),0.36)
	var impact_tip := Vector3(0,0,-1.0)
	var impact_grip: Vector3 = impact_tip-Basis(impact_rotation)*(held_tip_local()-grip_local)*HELD_SCALE
	held_item.quaternion = rest_rotation.slerp(impact_rotation,extension)
	var wrist: Vector3 = rest_grip.lerp(impact_grip,extension)
	held_item.position = wrist-held_item.basis*grip_local
	arm_shoulder_position = camera_point(ARM_ANCHOR_SCREEN,ARM_ANCHOR_DEPTH)
	var rest_elbow: Vector3 = camera_point(Vector2(1.12,1.5),0.3)
	var extended_elbow: Vector3 = arm_shoulder_position.lerp(wrist,0.5)+Vector3(0.04,-0.025,0.02)
	var elbow: Vector3 = rest_elbow.lerp(extended_elbow,extension)
	pose_arm_segment(held_arm_upper,arm_shoulder_position,elbow)
	pose_arm_segment(held_arm_fore,elbow,wrist)
	if is_instance_valid(held_arm_upper):
		held_arm_upper.visible = extension>0.02
		held_arm_fore.visible = extension>0.02

func reset_held_pose() -> void:
	apply_tool_action(0)

func update_hand_animation(delta: float, working: bool) -> void:
	if not is_instance_valid(held_item):
		return
	swing_blend = move_toward(swing_blend,1.0 if working else 0.0,delta*7.0)
	if working or swing_blend>0:
		swing_phase += delta*11.0
		apply_tool_action(fmod(swing_phase/TAU,1.0),swing_blend)
	else:
		swing_phase = 0
		reset_held_pose()

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
