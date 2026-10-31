extends PanelContainer

var world: Node
var slot_index: int = 0
var draggable: bool = true
var result_slot: bool = false
var image: TextureRect
var count_label: Label
var number_label: Label
var current_kind: String = ""
var durability_bar: ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	image = TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	# Insets leave room for the slot key and stack count.
	image.offset_left = 13
	image.offset_right = -13
	image.offset_top = 5
	image.offset_bottom = -14
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 19)
	count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_label.add_theme_constant_override("shadow_offset_x", 2)
	count_label.add_theme_constant_override("shadow_offset_y", 2)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(count_label)
	number_label = Label.new()
	number_label.add_theme_font_size_override("font_size", 14)
	number_label.modulate = Color(0.8, 0.86, 0.8)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(number_label)
	var durability_overlay := Control.new()
	durability_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(durability_overlay)
	durability_bar = ProgressBar.new()
	durability_bar.show_percentage = false
	durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	durability_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	durability_bar.offset_left = 9
	durability_bar.offset_right = -9
	durability_bar.offset_top = -10
	durability_bar.offset_bottom = -5
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.35)
	durability_bar.add_theme_stylebox_override("background", background)
	durability_overlay.add_child(durability_bar)

func refresh(slot: Dictionary, chosen: bool, moving: bool = false) -> void:
	current_kind = slot.kind if slot.count > 0 else ""
	image.texture = world.item_icons.get(current_kind)
	count_label.text = str(slot.count) if slot.count > 0 and not world.Registry.tool(slot.kind) else ""
	number_label.text = str(slot_index - 26) if slot_index >= 27 and slot_index < 36 else ""
	tooltip_text = "%s — %d" % [world.Registry.label(current_kind), slot.count] if slot.count > 0 else "Tom plats"
	durability_bar.visible = false
	if slot.count > 0 and world.Registry.tool(slot.kind):
		var maximum: int = int(slot.get("max_durability", world.Registry.durability_max(slot.kind)))
		var remaining: int = world.Registry.remaining_uses(slot)
		var ratio: float = float(remaining) / maximum
		durability_bar.visible = remaining < maximum
		durability_bar.value = ratio * 100
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1, 0.16, 0.1, 0.8) if ratio < 0.1 else (Color(1, 0.8, 0.1, 0.8) if ratio < 0.3 else Color(0.65, 0.95, 0.75, 0.65))
		durability_bar.add_theme_stylebox_override("fill", fill)
		tooltip_text += "\n%d/%d anv\u00e4ndningar kvar" % [remaining, maximum]
	var description: String = world.Registry.catalog.items.get(current_kind, {}).get("description", "")
	if not description.is_empty():
		tooltip_text += "\n" + description
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.22, 0.19, 0.97) if slot_index < 27 else Color(0.27, 0.29, 0.21, 0.98)
	style.border_color = Color(1, 0.85, 0.35) if chosen else (Color(0.5, 0.85, 1) if moving else Color(0.36, 0.43, 0.36))
	style.set_border_width_all(3 if chosen or moving else 1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if result_slot:
			if event.button_index == MOUSE_BUTTON_LEFT:
				world.craft_result(event.shift_pressed)
			accept_event()
			return
		if world.player.inventory_open:
			world.inventory_pointer_press(slot_index, event.button_index, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT and not draggable:
			world.select_hotbar(slot_index - 27)
		accept_event()

func _get_drag_data(_position: Vector2) -> Variant:
	# A persistent cursor stack handles both click-to-carry and paint dragging.
	return null

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not result_slot and draggable and data is Dictionary and data.get("inventory") == world.get_instance_id() and data.get("source", -1) >= 0 and data.get("source", -1) < 36 + world.crafting.slots.size() and data.get("source", -1) != slot_index

func _drop_data(_position: Vector2, data: Variant) -> void:
	world.move_inventory(data.source, slot_index)

func _get_tooltip(_at_position: Vector2) -> String:
	# Inventory owns a live hover panel so a previous slot tooltip cannot linger.
	return ""
