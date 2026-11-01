extends PanelContainer

const Cycle = preload("res://scripts/core/day_cycle.gd")
var time_pause: Button
var time_sleep: Button
var time_label: Label
const Combat = preload("res://scripts/core/combat.gd")
var world: Node
var content: VBoxContainer
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
	add_label(content, "STRIDSVÄRDEN · DEBUG · F3", 23)
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
	refresh_clock()
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 30)
	table.add_theme_constant_override("v_separation", 8)
	content.add_child(table)
	for title in ["Avatar / vapen", "Försvar", "Anfall", "Slag/s · intervall"]:
		add_label(table, title, 17)
	for actor: Dictionary in Combat.definitions.actors.values():
		for value in [actor.name, str(actor.defense), str(actor.attack), "%.1f/s · %s s" % [1.0 / float(actor.interval), actor.interval]]:
			add_label(table, value)
	for weapon: Dictionary in Combat.definitions.weapons.values():
		for value in [weapon.name, "–", "+%s" % weapon.attack_bonus, "%.1f/s · %s s" % [1.0 / float(weapon.interval), weapon.interval]]:
			add_label(table, value)
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
	time_label.text = "Dygn: %s - %s" % [Cycle.clock_text(world.model),Cycle.phase(world.model)]
	time_pause.text = "Fortsätt tiden" if Cycle.state(world.model).paused else "Pausa tiden"
	time_sleep.disabled = not Cycle.can_sleep(world.model)
