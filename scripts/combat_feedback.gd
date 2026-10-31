extends Control

var hurt_time: float = 0
var hit_time: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func on_hurt(_amount: float) -> void:
	hurt_time = 0.4

func _process(delta: float) -> void:
	hurt_time = maxf(0, hurt_time - delta)
	hit_time = maxf(0, hit_time - delta)
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if hurt_time > 0:
		var strength: float = hurt_time / 0.4
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.9, 0.04, 0.02, strength * 0.08))
		var edge := Color(0.9, 0.08, 0.03, strength * 0.4)
		draw_rect(Rect2(0, 0, viewport_size.x, 12), edge)
		draw_rect(Rect2(0, viewport_size.y - 12, viewport_size.x, 12), edge)
		draw_rect(Rect2(0, 0, 12, viewport_size.y), edge)
		draw_rect(Rect2(viewport_size.x - 12, 0, 12, viewport_size.y), edge)
	if hit_time > 0:
		var center: Vector2 = viewport_size * 0.5
		for x in [-1, 1]:
			for y in [-1, 1]:
				draw_line(center + Vector2(x, y) * 7, center + Vector2(x, y) * 14, Color(1, 0.9, 0.5, hit_time / 0.18), 2.5, true)
