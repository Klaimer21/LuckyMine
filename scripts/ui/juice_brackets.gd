class_name JuiceBrackets
extends Control
## Уголки-скобки: четыре «Г» по углам, плавно сходятся и расходятся.

var color := UiTheme.BRASS
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := (sin(_t * 5.0) * 0.5 + 0.5) * 6.0
	var r := Rect2(Vector2.ZERO, size).grow(4.0 + pulse)
	var arm := minf(28.0, minf(r.size.x, r.size.y) * 0.3)
	var w := 5.0
	var corners := [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]
	for corner in corners:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_rect(Rect2(p + Vector2(minf(0.0, d.x * arm), minf(0.0, d.y * w)), Vector2(arm, w)), color)
		draw_rect(Rect2(p + Vector2(minf(0.0, d.x * w), minf(0.0, d.y * arm)), Vector2(w, arm)), color)
