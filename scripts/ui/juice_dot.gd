class_name JuiceDot
extends Control
## Красная точка с лёгким «дыханием».

var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(20, 20)
	size = Vector2(20, 20)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := 1.0 + sin(_t * 4.0) * 0.12
	draw_rect(Rect2(Vector2(10, 10) - Vector2(9, 9) * s, Vector2(18, 18) * s), Color(0.05, 0.03, 0.03))
	draw_rect(Rect2(Vector2(10, 10) - Vector2(7, 7) * s, Vector2(14, 14) * s), Juice.DOT)
	draw_rect(Rect2(Vector2(10, 10) - Vector2(5, 5) * s, Vector2(4, 4) * s), Color(1, 0.7, 0.6))
