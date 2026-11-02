extends PanelContainer

const Furnaces=preload("res://scripts/core/furnaces.gd")
const FurnaceCursor=preload("res://scripts/core/furnace_cursor.gd")
var furnace_mode: bool=false
var furnace_progress: ProgressBar
var fuel_progress: ProgressBar
var furnace_status: Label
var refresh_elapsed: float=0
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
	furnace_mode=game.model.kind_at(cell) in Furnaces.PARTS
	storage.slots.assign(Furnaces.contents(game.model,cell) if furnace_mode else Chests.combined(game.model,cell))
	cursor=FurnaceCursor.new() if furnace_mode else Cursor.new()
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
	title = text("STENUGN" if furnace_mode else ("DUBBELKISTA · 9 × 6 · 54 platser" if double else "KISTA · 9 × 3 · 27 platser"), 22)
	content.add_child(title)
	content.add_child(text("Dra föremål · Höger: dela · Shift-vänster: flytta", 14))
	var chest_indices: Array[int] = []
	for index in range(storage.slots.size()):
		chest_indices.append(36 + index)
	if furnace_mode:
		build_furnace_area()
	else:
		grid(content,9,chest_indices)
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
	offset_top = -310 if double else (-320 if furnace_mode else -240)
	offset_bottom = 310 if double else (320 if furnace_mode else 240)
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

func furnace_slot(parent: Control, index: int) -> void:
	var widget:=InventorySlot.new()
	widget.world=self
	widget.slot_index=36+index
	widget.custom_minimum_size=Vector2(56,56)
	widget.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	parent.add_child(widget)
	widgets.append(widget)

func furnace_meter(size: Vector2, colour: Color) -> ProgressBar:
	var meter:=ProgressBar.new()
	meter.custom_minimum_size=size
	meter.show_percentage=false
	var background:=StyleBoxFlat.new()
	background.bg_color=Color(0.14,0.19,0.16)
	var fill:=StyleBoxFlat.new()
	fill.bg_color=colour
	meter.add_theme_stylebox_override("background",background)
	meter.add_theme_stylebox_override("fill",fill)
	return meter

func build_furnace_area() -> void:
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",30)
	content.add_child(row)
	var inputs:=VBoxContainer.new()
	inputs.add_theme_constant_override("separation",4)
	row.add_child(inputs)
	inputs.add_child(text("MATERIAL",14))
	furnace_slot(inputs,0)
	fuel_progress=furnace_meter(Vector2(110,10),Color("ec923b"))
	inputs.add_child(fuel_progress)
	inputs.add_child(text("BR\u00c4NSLE",14))
	furnace_slot(inputs,1)
	var middle:=VBoxContainer.new()
	middle.custom_minimum_size.x=125
	middle.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(middle)
	middle.add_child(text("\u2192",26))
	furnace_progress=furnace_meter(Vector2(125,16),Color("d1b45a"))
	middle.add_child(furnace_progress)
	furnace_status=text("",13)
	middle.add_child(furnace_status)
	var output:=VBoxContainer.new()
	output.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(output)
	output.add_child(text("RESULTAT",14))
	furnace_slot(output,2)
	var legend: PackedStringArray=[]
	for kind in ["foliage","stick","planks","wood","coal"]:
		legend.append("%s: %s s"%[Registry.label(kind),str(Furnaces.fuel_seconds(kind))])
	var help:=text(" \u00b7 ".join(legend),12)
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x=410
	content.add_child(help)

func refresh_furnace_status() -> void:
	var value: Dictionary=Furnaces.state(game.model,open_cell)
	var target: float=100*float(value.burn_left)/maxf(0.001,float(value.burn_total))
	if target>fuel_progress.value:
		fuel_progress.value=target
	var rule: Dictionary=Furnaces.recipe(value.slots[0].kind)
	furnace_progress.value=100*float(value.progress)/float(rule.get("seconds",3.0))
	furnace_status.text="Brinner: %.1f s\nTillagning: %.1f / 3 s"%[value.burn_left,value.progress] if float(value.burn_left)>0 else ("Elden falnar" if fuel_progress.value>0.01 else "Elden slocknad")

func update_fire_display(delta: float) -> void:
	var value: Dictionary=Furnaces.state(game.model,open_cell)
	var target: float=100*float(value.burn_left)/maxf(0.001,float(value.burn_total))
	# A newly ignited fuel item may raise the flame immediately. Lower values
	# are approached smoothly, including residual visual fading after expiry.
	fuel_progress.value=target if target>=fuel_progress.value else move_toward(fuel_progress.value,target,delta*(100.0/1.5))

func _process(delta: float) -> void:
	if not visible or not furnace_mode:
		return
	update_fire_display(delta)
	refresh_elapsed+=delta
	if refresh_elapsed>=0.1:
		refresh_elapsed=0
		refresh()

func refresh() -> void:
	var plan: Dictionary = cursor.preview().slots
	for widget in widgets:
		widget.refresh(plan.get(widget.slot_index, cursor.slot(widget.slot_index)), false, cursor.painted.has(widget.slot_index))
	if furnace_mode:
		refresh_furnace_status()
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
