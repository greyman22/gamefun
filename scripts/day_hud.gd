extends Control
const Cycle = preload("res://scripts/core/day_cycle.gd")
var world: Node
var clock: Label
var pause_button: Button
var night_button: Button
var sleep_button: Button
var strip: Control
var indicators: Array[Label] = []
var indicator_panels: Array[PanelContainer] = []
var definitions: Array = []
var flash: float = 0
var threats: Dictionary = {}

class Timeline extends Control:
	var minute: float = 480
	func _draw() -> void:
		for segment in [[0,4,Color("263451")],[4,5,Color("dca269")],[5,21,Color("d6c87a")],[21,22,Color("b0758e")],[22,24,Color("263451")]]:
			draw_rect(Rect2(float(segment[0])/24 * size.x,0,float(segment[1]-segment[0])/24*size.x,5),segment[2])
		var x := minute / 1440.0 * size.x
		draw_line(Vector2(x,-1),Vector2(x,7),Color.WHITE,2)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.anchor_left = 1.0/3
	panel.anchor_right = 2.0/3
	panel.offset_top = 6
	panel.offset_bottom = 30
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.075,0.88)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",8)
	panel.add_child(row)
	clock = Label.new()
	clock.text="--:--"
	clock.add_theme_font_size_override("font_size",13)
	clock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(clock)
	pause_button = Button.new()
	pause_button.text = "Paus"
	pause_button.add_theme_font_size_override("font_size",13)
	pause_button.tooltip_text = "P: pausa bara dygnsklockan. E frigör muspekaren."
	pause_button.pressed.connect(toggle_pause)
	row.add_child(pause_button)
	pause_button.hide()
	sleep_button = Button.new()
	sleep_button.text = "Sov"
	sleep_button.add_theme_font_size_override("font_size",13)
	sleep_button.tooltip_text = "N: hoppa till gryning 04:00. Tillgänglig 21:00-03:59."
	sleep_button.pressed.connect(sleep)
	row.add_child(sleep_button)
	sleep_button.hide()
	night_button = Button.new()
	night_button.text = "Natt"
	night_button.add_theme_font_size_override("font_size",13)
	night_button.pressed.connect(night)
	row.add_child(night_button)
	night_button.hide()
	strip = Timeline.new()
	strip.custom_minimum_size = Vector2(100,7)
	strip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	strip.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)
	var monsters := HBoxContainer.new()
	monsters.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	monsters.offset_left = -235
	monsters.offset_right = -12
	monsters.offset_top = 8
	monsters.offset_bottom = 50
	monsters.add_theme_constant_override("separation",5)
	add_child(monsters)
	for definition: Dictionary in definitions:
		var icon := Label.new()
		icon.text = "" if definition.type in ["zombie","skeleton"] else definition.symbol
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.custom_minimum_size = Vector2(38,42)
		icon.add_theme_font_size_override("font_size",22)
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(38,42)
		monsters.add_child(frame)
		frame.add_child(icon)
		if definition.type in ["zombie","skeleton"]:
			var zombie := TextureRect.new()
			var picture := Image.new()
			picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" shape-rendering="crispEdges"><path d="M9 2H23V15H9Z" fill="#71a54b"/><path d="M11 6H15V9H11ZM19 6H22V9H19ZM16 12H21V14H16Z" fill="#203426"/><path d="M8 16H24V29H8Z" fill="#34716a"/><path d="M1 17H8V23H1ZM24 17H31V23H24Z" fill="#71a54b"/><path d="M8 29H15V39H8ZM17 29H24V39H17Z" fill="#62618b"/></svg>')
			if definition.type=="skeleton":
				picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" shape-rendering="crispEdges"><path d="M9 1H23V14H9Z" fill="#e9e3d0"/><path d="M11 5H15V9H11ZM18 5H22V9H18ZM15 11H18V14H15Z" fill="#30343a"/><path d="M14 14H18V29H14ZM9 17H23V20H9ZM9 23H23V26H9ZM8 28H24V31H8ZM9 31H13V40H9ZM19 31H23V40H19ZM4 17H8V29H4ZM24 17H28V29H24Z" fill="#d5cfba"/><path d="M28 14Q36 24 28 34" fill="none" stroke="#9d7142" stroke-width="2"/><path d="M28 14V34" stroke="#f0dfb9"/></svg>')
			zombie.texture = ImageTexture.create_from_image(picture)
			zombie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			zombie.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			zombie.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			zombie.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(zombie)
		indicator_panels.append(frame)
		indicators.append(icon)
	refresh(0)

func toggle_pause() -> void:
	if world.game_mode != "debug":
		return
	var value := Cycle.state(world.model)
	value.paused = not bool(value.paused)
	refresh(0)

func sleep() -> void:
	if world.game_mode == "debug":
		Cycle.sleep_to_dawn(world.model)
		world.update_daylight(0)
		refresh(0)

func night() -> void:
	if world.game_mode == "debug":
		Cycle.state(world.model).minute = 1320.0
		world.update_daylight(0)
		refresh(0)

func refresh(delta: float) -> void:
	if world.model == null:
		return
	flash += delta
	clock.text = "%s  %s" % [Cycle.clock_text(world.model),Cycle.phase(world.model)]
	pause_button.visible = false
	sleep_button.visible = false
	night_button.visible = false
	pause_button.text = "Fortsätt" if bool(Cycle.state(world.model).paused) else "Paus"
	sleep_button.disabled = not Cycle.can_sleep(world.model)
	strip.minute = float(Cycle.state(world.model).minute)
	strip.queue_redraw()
	threats.clear()
	if is_instance_valid(world.entity_system):
		for id: String in world.entity_system.active:
			var record: Dictionary = world.model.entities.get(id,{})
			var actor: Node = world.entity_system.active[id]
			if record.get("state",{}).get("dead",false):
				continue
			var behavior: Variant = actor.get("behavior") if record.get("type","") in ["zombie","skeleton"] else record.get("state",{}).get("behavior","")
			if behavior == "chase":
				threats[record.type] = int(threats.get(record.type,0)) + 1
	for index in range(indicators.size()):
		var definition: Dictionary = definitions[index]
		var count: int = int(threats.get(definition.type,0))
		var icon := indicators[index]
		icon.modulate = Color(definition.color) if count > 0 else Color(0.38,0.4,0.43,0.7)
		icon.modulate.a = (1.0 if sin(flash * TAU * 1.5) >= 0 else 0.35) if count > 0 else 0.7
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.025,0.04,0.055,0.9)
		frame_style.border_color = Color(1,0.43,0.2,icon.modulate.a) if count > 0 else Color(0.26,0.29,0.32,0.8)
		frame_style.set_border_width_all(2 if count > 0 else 1)
		indicator_panels[index].add_theme_stylebox_override("panel",frame_style)
		icon.tooltip_text = "%s: %d förföljer dig" % [definition.name,count]
