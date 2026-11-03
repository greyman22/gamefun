extends Control

var vitals: RefCounted
var hearts: Array[Texture2D] = []
var food: Array[Texture2D] = []
var bubbles: Array[Texture2D]=[]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for active in [false, true]:
		hearts.append(icon(false, active))
		food.append(icon(true, active))
		var image:=Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="13" fill="%s" stroke="#7cc5ee" stroke-width="2"/><path d="M8 14C8 10 11 7 15 7" fill="none" stroke="#def4ff" stroke-width="3" stroke-linecap="round"/></svg>'%["#63b2df" if active else "#233541"])
		bubbles.append(ImageTexture.create_from_image(image))

func icon(is_food: bool, active: bool) -> Texture2D:
	var shape: String = '<path d="M16 28L4 17C-5 5 8 -2 16 7C24 -2 37 5 28 17Z"/>'
	if is_food:
		shape = '<path d="M9 20L3 26L1 25L0 28L4 32L7 30L6 28L12 22Z"/><path d="M10 21C-2 10 15 -3 25 2C37 9 25 29 15 23Z"/>'
	var color: String = ("#eaaa4e" if is_food else "#ee555d") if active else "#343d38"
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="34"><g fill="%s" stroke="#111915" stroke-width="2">%s</g></svg>' % [color, shape])
	return ImageTexture.create_from_image(image)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if vitals == null or hearts.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var origin := Vector2((viewport_size.x - 682) * 0.5, viewport_size.y - 134)
	draw_style_box(panel_style(), Rect2(origin, Vector2(682, 32)))
	var font: Font = ThemeDB.fallback_font
	for group in range(2):
		var value: float = vitals.health if group == 0 else vitals.satiety
		var textures: Array[Texture2D] = hearts if group == 0 else food
		var start: Vector2 = origin + Vector2(10 + group * 341, 0)
		draw_string(font, start + Vector2(0, 21), "Hälsa" if group == 0 else "Mättnad", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		for index in range(10):
			var point := start + Vector2(66 + index * 21, 5)
			var rect := Rect2(point, Vector2(19, 22))
			draw_texture_rect(textures[0], rect, false)
			var amount: float = value - index * 10
			if amount > 0:
				var fraction: float = 1 if amount > 5 else 0.5
				draw_texture_rect_region(textures[1], Rect2(point, Vector2(19 * fraction, 22)), Rect2(0, 0, 32 * fraction, 34))
		draw_string(font, start + Vector2(280, 21), "%d %%" % ceili(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.9, 0.86))

	if vitals.submerged or vitals.air<10:
		var start: Vector2=origin+Vector2(682-174,-31)
		draw_style_box(panel_style(),Rect2(start,Vector2(174,28)))
		draw_string(font,start+Vector2(8,19),"Luft",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		var units: int=ceili(vitals.air-0.0001)
		for i in range(5):
			var point: Vector2=start+Vector2(47+i*24,3)
			draw_texture_rect(bubbles[0],Rect2(point,Vector2(22,22)),false)
			var fraction: float=clampf(float(units-i*2)/2,0,1)
			if fraction>0:
				draw_texture_rect_region(bubbles[1],Rect2(point,Vector2(22*fraction,22)),Rect2(0,0,32*fraction,32))

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.045, 0.8)
	style.set_corner_radius_all(8)
	return style
