extends Control

var arrow: Polygon2D
var caption: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-13, -25), Vector2(-5, -25), Vector2(-5, -46), Vector2(5, -46), Vector2(5, -25), Vector2(13, -25), Vector2(0, -7)])
	arrow.color = Color(1, 0.82, 0.2)
	add_child(arrow)
	caption = Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(-145, 5)
	caption.size = Vector2(290, 32)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size", 5)
	add_child(caption)

func update_marker(camera: Camera3D, target: Vector3, enabled: bool) -> void:
	visible = enabled
	if not enabled:
		return
	var viewport_size := get_viewport_rect().size
	var local: Vector3 = camera.to_local(target)
	var behind: bool = local.z > 0
	var point: Vector2
	if behind:
		point = Vector2(viewport_size.x - 160 if local.x >= 0 else 160, viewport_size.y * 0.5)
	else:
		point = camera.unproject_position(target)
	position = point.clamp(Vector2(160, 85), viewport_size - Vector2(160, 90))
	var on_screen: bool = not behind and point == position
	arrow.rotation = 0 if on_screen else (point - viewport_size * 0.5).angle() - PI / 2
	caption.text = "Zombie-huset · %d m%s" % [roundi(camera.global_position.distance_to(target)), " · vänd dig om" if behind else ""]
