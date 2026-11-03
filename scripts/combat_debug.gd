extends PanelContainer

const Cycle = preload("res://scripts/core/day_cycle.gd")
var time_pause: Button
var time_sleep: Button
var time_label: Label
const Combat = preload("res://scripts/core/combat.gd")
var world: Node
var content: VBoxContainer
var terrain_label: Label
var measurement_button: Button
var measurement_label: Label
var summary: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -330
	offset_right = 330
	offset_top = -320
	offset_bottom = 320
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.06, 0.98)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	refresh()
	hide()

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	Combat.initialize()
	add_label(content, "DEBUG · TERRÄNG OCH STRID · F3", 23)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size",16)
	content.add_child(time_label)
	var time_row := HBoxContainer.new()
	content.add_child(time_row)
	time_pause = Button.new()
	time_pause.pressed.connect(func() -> void: world.day_hud.toggle_pause())
	time_row.add_child(time_pause)
	time_sleep = Button.new()
	time_sleep.text = "Sov till gryning"
	time_sleep.pressed.connect(func() -> void: world.day_hud.sleep())
	time_row.add_child(time_sleep)
	var night := Button.new()
	night.text = "Natt"
	night.pressed.connect(func() -> void: world.day_hud.night())
	time_row.add_child(night)
	measurement_button=Button.new()
	measurement_button.name="PerformanceToggle"
	measurement_button.pressed.connect(toggle_measurement)
	content.add_child(measurement_button)
	measurement_label=Label.new()
	measurement_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	measurement_label.add_theme_font_size_override("font_size",14)
	content.add_child(measurement_label)
	var reports_button:=Button.new()
	reports_button.text="Öppna mapp med prestandarapporter"
	reports_button.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute("user://performance")
		OS.shell_open(ProjectSettings.globalize_path("user://performance")))
	content.add_child(reports_button)
	refresh_measurement()
	refresh_clock()
	terrain_label=Label.new()
	terrain_label.add_theme_font_size_override("font_size",14)
	content.add_child(terrain_label)
	var terrain_row:=HBoxContainer.new()
	terrain_row.name="TerrainButtons"
	terrain_row.add_theme_constant_override("separation",8)
	content.add_child(terrain_row)
	for index in range(5):
		var button:=Button.new()
		button.name=["Home","Grassland","Hills","Mountains","Caves"][index]
		button.custom_minimum_size=Vector2(108,86)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.tooltip_text=["Tillbaka till startplatsen","Hoppa till gräsmark","Hoppa till kuperad terräng","Hoppa till berg","Hoppa till en bergsgrotta"][index]
		button.disabled=world.model==null or (index>0 and world.model.generator.version<4)
		var picture:=TextureRect.new()
		picture.texture=terrain_icon(index)
		picture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		picture.offset_left=20
		picture.offset_right=-20
		picture.offset_top=8
		picture.offset_bottom=54
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		var title:=Label.new()
		title.text=["Hem","Gräsmark","Kuperad","Berg","Berggrottor"][index]
		title.add_theme_font_size_override("font_size",14)
		title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		title.offset_top=-27
		title.offset_bottom=-5
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(title)
		if index==0:
			button.pressed.connect(world.debug_return_home)
		else:
			button.pressed.connect(world.debug_visit_terrain.bind(mini(index-1,2),index==4))
		terrain_row.add_child(button)
	var table := GridContainer.new()
	table.columns = 5
	table.add_theme_constant_override("h_separation", 30)
	table.add_theme_constant_override("v_separation", 8)
	content.add_child(table)
	for title in ["Avatar / vapen", "Max liv", "Försvar", "Anfall", "Slag/s · intervall"]:
		add_label(table, title, 17)
	for actor: Dictionary in Combat.definitions.actors.values():
		for value in [actor.name, str(actor.get("health",100)), ("%s–%s"%[actor.defense_min,actor.defense_max] if actor.has("defense_min") else str(actor.defense)), ("%s–%s"%[actor.attack_min,actor.attack_max] if actor.has("attack_min") else str(actor.attack)), "%.1f/s · %s s" % [1.0 / float(actor.interval), actor.interval]]:
			add_label(table, value)
	for weapon: Dictionary in Combat.definitions.weapons.values():
		for value in [weapon.name, "–", "–", "+%s" % weapon.attack_bonus, "%.1f/s · %s s" % [1.0 / float(weapon.interval), weapon.interval]]:
			add_label(table, value)
	add_label(content, "Pilbåge: 1 s till full laddning, ingen väntetid efter skott.",15)
	add_label(content, "Nya djur och monster börjar med 80–100 % av max liv.",15)
	add_label(content, "Skada = anfall × %s / (%s + försvar)" % [Combat.definitions.defense_scale, Combat.definitions.defense_scale])
	var player: Dictionary = Combat.stats("player", "stone_sword")
	add_label(content, "Spelare med stensvärd: %s anfall, ett slag var %s sekund." % [player.attack, player.interval])
	add_label(content, "Zombies återkommer efter %s s i debug / %s s i spelläge." % [Combat.respawn_seconds("debug"), Combat.respawn_seconds("play")])
	add_label(content, "Jakt: %s m för att upptäcka / %s m för att släppa. Fart: %.1f m/s." % [Combat.stats("zombie").get("aggro_start", 10), Combat.stats("zombie").get("aggro_break", 20), world.player.SPEED / 3.0])
	add_label(content, "Ändra värdena i data/combat.json och läs in dem här.", 15)
	var reload_button := Button.new()
	reload_button.text = "Läs in ändrade stridsvärden"
	reload_button.pressed.connect(func() -> void:
		if Combat.reload_data():
			refresh()
		else:
			world.message("Ogiltiga stridsvärden. Tidigare värden används."))
	content.add_child(reload_button)
	var close_button := Button.new()
	close_button.text = "Stäng (F3 / Esc)"
	close_button.pressed.connect(func() -> void: world.toggle_combat_debug())
	content.add_child(close_button)

func add_label(parent: Node, text_value: String, font_size: int = 16) -> void:
	var text := Label.new()
	text.text = text_value
	text.add_theme_font_size_override("font_size", font_size)
	parent.add_child(text)

func _process(_delta: float) -> void:
	if visible:
		refresh_clock()

func refresh_clock() -> void:
	if world.model == null or not is_instance_valid(time_pause):
		return
	if is_instance_valid(terrain_label):
		if world.model.generator.version>=4:
			var zone: Dictionary=world.model.generator.zones.info(floori(world.player.position.x),floori(world.player.position.z))
			terrain_label.text="Terräng: %s · Zon: %d × %d m"%[zone.name,zone.rect.size.x,zone.rect.size.y]
		else:
			terrain_label.text="Terrängzoner finns i nya världar."
	if is_instance_valid(terrain_label) and is_instance_valid(world.entity_system):
		terrain_label.text+="\nMonster nära: %d"%world.entity_system.night_population.nearby_count
		if world.entity_system.night_population.target_count>0:
			terrain_label.text+=" · nattmål %d"%world.entity_system.night_population.target_count
	time_label.text = "Dygn: %s - %s" % [Cycle.clock_text(world.model),Cycle.phase(world.model)]
	time_pause.text = "Fortsätt tiden" if Cycle.state(world.model).paused else "Pausa tiden"
	time_sleep.disabled = not Cycle.can_sleep(world.model)

func terrain_icon(index: int) -> Texture2D:
	var pictures: Array[String]=[
		'<path d="M16 30L48 7L80 30V58H16Z" fill="#b88751" stroke="#573c28" stroke-width="3"/><path d="M9 31L48 3L87 31" fill="none" stroke="#9b513d" stroke-width="8"/><path d="M40 58V36H57V58" fill="#60422e"/><path d="M23 36H33V46H23Z" fill="#a8d7e6"/>',
		'<path d="M5 35Q28 28 50 34T91 33V60H5Z" fill="#9d7246"/><path d="M5 35Q28 28 50 34T91 33V42Q67 44 50 42T5 43Z" fill="#6da341"/><path d="M22 33L19 23M23 33L29 25M64 33L62 22M65 33L72 26" stroke="#4c7e30" stroke-width="3"/>',
		'<path d="M2 58Q14 8 37 24Q62 -2 94 58Z" fill="#537a35"/><path d="M0 60Q28 10 54 37Q72 16 96 60Z" fill="#82a64c"/><path d="M46 30L54 19L65 24L62 33Z" fill="#9c9f96"/>',
		'<path d="M3 60L34 12L51 36L67 3L94 60Z" fill="#8b9298" stroke="#505d63" stroke-width="2"/><path d="M34 12L44 29L26 26ZM67 3L78 24L58 21Z" fill="#d2d6d4"/><path d="M34 12L29 60M67 3L60 60" stroke="#6b767e" stroke-width="3"/>',
		'<path d="M4 60L17 26L36 9L66 14L86 35L94 60Z" fill="#8c9498" stroke="#535e64" stroke-width="3"/><path d="M27 60L29 37L40 26L60 28L71 41L73 60Z" fill="#16252c"/><path d="M32 60L41 39L56 34L66 59Z" fill="#0b151b"/><path d="M15 34L29 29M68 21L74 30" stroke="#b5baba" stroke-width="4"/>'
	]
	var image:=Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="64">'+pictures[index]+'</svg>')
	return ImageTexture.create_from_image(image)

func toggle_measurement() -> void:
	if world.PerfLog.active:
		var path: String=world.PerfLog.stop()
		measurement_label.text="Rapport sparad: "+path if not path.is_empty() else "Kunde inte spara rapporten."
	else:
		world.PerfLog.start()
		measurement_label.text="Mätning pågår. Stäng F3 och spela som vanligt. Öppna F3 för att stoppa."
	refresh_measurement()

func refresh_measurement() -> void:
	measurement_button.text="Stoppa och spara prestandamätning" if world.PerfLog.active else "Starta prestandamätning"
	if world.PerfLog.active:
		measurement_label.text="Mätning pågår. Stäng F3 och spela som vanligt."
	elif not world.PerfLog.last_path.is_empty():
		measurement_label.text="Senaste rapport: "+world.PerfLog.last_path
