class_name JuiceRays
extends Control
## Вращающиеся лучи и мягкое свечение позади наград.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(size.x, size.y) * 0.62
	for ring in 6:
		var r := radius * (0.18 + ring * 0.09)
		draw_circle(center, r, Color(0.98, 0.84, 0.45, 0.05))
	for i in 12:
		var a := _t * 0.35 + i * TAU / 12.0
		var spread := 0.11
		var points := PackedVector2Array([center, center + Vector2(cos(a - spread), sin(a - spread)) * radius,
				center + Vector2(cos(a + spread), sin(a + spread)) * radius])
		draw_colored_polygon(points, Color(0.98, 0.84, 0.45, 0.09 if i % 2 == 0 else 0.05))
