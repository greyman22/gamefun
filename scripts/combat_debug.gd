extends PanelContainer

const Combat = preload("res://scripts/core/combat.gd")
var world: Node
var content: VBoxContainer
var summary: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -330
	offset_right = 330
	offset_top = -290
	offset_bottom = 170
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.06, 0.98)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	refresh()
	hide()

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	Combat.initialize()
	add_label(content, "STRIDSVÄRDEN · DEBUG · F3", 23)
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
