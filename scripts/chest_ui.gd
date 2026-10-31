extends PanelContainer

const Registry = preload("res://scripts/core/registry.gd")
const Chests = preload("res://scripts/core/chests.gd")
const InventorySlot = preload("res://scripts/inventory_slot.gd")
const Cursor = preload("res://scripts/core/storage_cursor.gd")

class Storage extends RefCounted:
	var slots: Array[Dictionary] = []
	var width: int = 9

var game: Node
var player: CharacterBody3D
var item_icons: Dictionary
var cursor = Cursor.new()
var previous_cursor: RefCounted
var storage = Storage.new()
var widgets: Array[PanelContainer] = []
var title: Label
var caption: Label
var content: VBoxContainer
var open_cell := Vector3i.ZERO

func configure(world: Node) -> void:
	game = world
	player = world.player
	item_icons = world.item_icons

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.105, 0.085, 1)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	hide()

func text(value: String, size_value: int = 16) -> Label:
	return game.label(value, size_value)

func grid(parent: Control, columns: int, indices: Array[int]) -> void:
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(center)
	var cells := GridContainer.new()
	cells.columns = columns
	cells.add_theme_constant_override("h_separation", 4)
	cells.add_theme_constant_override("v_separation", 4)
	center.custom_minimum_size.x = 410
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	center.add_child(cells)
	for index in indices:
		var widget := InventorySlot.new()
		widget.world = self
		widget.slot_index = index
		widget.custom_minimum_size = Vector2(42, 42)
		cells.add_child(widget)
		widget.image.offset_left = 6
		widget.image.offset_right = -6
		widgets.append(widget)

func open(cell: Vector3i) -> void:
	open_cell = cell
	storage.slots = Chests.combined(game.model, cell)
	previous_cursor = game.stack_cursor
	cursor.reset()
	cursor.bind(game.inventory, storage)
	game.stack_cursor = cursor
	for child in get_children():
		remove_child(child)
		child.queue_free()
	widgets.clear()
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var double: bool = storage.slots.size() > 27
	title = text("DUBBELKISTA · 9 × 6 · 54 platser" if double else "KISTA · 9 × 3 · 27 platser", 22)
	content.add_child(title)
	content.add_child(text("Dra föremål · Höger: dela · Shift-vänster: flytta", 14))
	var chest_indices: Array[int] = []
	for index in range(storage.slots.size()):
		chest_indices.append(36 + index)
	grid(content, 9, chest_indices)
	content.add_child(text("INVENTARIUM", 17))
	var backpack: Array[int] = []
	for index in range(27):
		backpack.append(index)
	grid(content, 9, backpack)
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	content.add_child(gap)
	var hotbar: Array[int] = []
	for index in range(27, 36):
		hotbar.append(index)
	grid(content, 9, hotbar)
	caption = text("Nedersta raden fylls först · E / Esc stänger", 14)
	content.add_child(caption)
	offset_left = -255
	offset_right = 255
	offset_top = -310 if double else -240
	offset_bottom = 310 if double else 240
	player.inventory_open = true
	player.jump_requested = false
	game.inventory_panel.hide()
	game.hotbar.hide()
	if is_instance_valid(game.held_item):
		game.held_item.hide()
	game.prompt.hide()
	game.mining_held = false
	game.reset_mining()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	refresh()

func refresh() -> void:
	var plan: Dictionary = cursor.preview().slots
	for widget in widgets:
		widget.refresh(plan.get(widget.slot_index, cursor.slot(widget.slot_index)), false, cursor.painted.has(widget.slot_index))
	game.update_cursor_visual()

func pointer_slot(point: Vector2) -> int:
	for widget in widgets:
		if widget.get_global_rect().has_point(point):
			return widget.slot_index
	return -1

func inventory_pointer_press(index: int, button: int, shift: bool) -> void:
	cursor.press(index, button, shift)
	refresh()

func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		cursor.touch(pointer_slot(event.position))
		refresh()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and cursor.left_down:
		cursor.touch(pointer_slot(event.position))
		cursor.finish()
		refresh()
		return true
	return false

func close() -> bool:
	if not cursor.return_all():
		caption.text = "Placera föremålet du håller innan du stänger."
		refresh()
		return false
	detach()
	player.inventory_open = false
	game.prompt.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.update_counter()
	return true

func detach() -> void:
	hide()
	if previous_cursor != null:
		game.stack_cursor = previous_cursor
		previous_cursor = null
	storage.slots.clear()
