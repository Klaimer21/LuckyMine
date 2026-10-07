class_name Icon
extends Control
## Простые векторные иконки (рисуются кодом): монета, алмаз, замок, сундук и т.д.

var kind := "coin"
var color := UiTheme.TEXT
var width := 2.0
var tier := 0                          # облик машины: 1 — латунные заклёпки, 2 — ещё и золотой ободок
var follow: BaseButton                 # кнопка, на которой лежит значок: отключённая кнопка красит значок приглушённым цветом
var _enabled_color := Color.WHITE
var outline := Color(0, 0, 0, 0)       # контур алмаза (если задан): виден и на светлой латуни

## Пиксельные значки (assets/pixel/icons, 24x24): вид значка -> имя файла. Остальные виды рисуются кодом.
const SPRITES := {
	"coin": "coin", "gem": "gem", "lock": "lock", "chest": "chest", "crown": "crown", "back": "back", "spark": "spark",
	"bag": "bag", "gear": "gear", "clock": "clock", "check": "check", "rock": "rock", "dynamite": "dynamite",
	"journal": "journal", "cross": "close", "star": "star",
	"ore_copper": "../ores/copper", "ore_iron": "../ores/iron", "ore_gold": "../ores/gold", "ore_diamond": "../ores/diamond",
}
static var _sprite_cache := {}


func setup(p_kind: String, p_color: Color, px: float) -> Icon:
	kind = p_kind
	color = p_color
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	width = maxf(2.0, px / 12.0)
	queue_redraw()
	return self


## Значок на кнопке: пока кнопка отключена, он серый (иначе тёмный значок на тёмной кнопке пропадает).
func follow_button(button: BaseButton) -> Icon:
	follow = button
	_enabled_color = color
	button.draw.connect(_sync_with_button)
	_sync_with_button()
	return self


func _sync_with_button() -> void:
	var wanted := UiTheme.MUTE if follow.disabled else _enabled_color
	if color != wanted:
		color = wanted
		queue_redraw()


## Пиксельный спрайт значка или null (тогда значок рисуется кодом).
static func sprite_for(p_kind: String) -> Texture2D:
	if not _sprite_cache.has(p_kind):
		var path := ""
		if SPRITES.has(p_kind):
			path = "res://assets/pixel/icons/%s.png" % SPRITES[p_kind]
		elif p_kind.begins_with("px_"):                  # px_<имя>: любой значок из assets/pixel/icons
			path = "res://assets/pixel/icons/%s.png" % p_kind.substr(3)
		elif p_kind.begins_with("trip_"):                # trip_<имя>: значки экспедиций, 48x48
			path = "res://assets/pixel/trips/%s.png" % p_kind.substr(5)
		elif p_kind.begins_with("find_"):                # find_<имя>: находки экспедиций
			path = "res://assets/pixel/finds/%s.png" % p_kind.substr(5)
		_sprite_cache[p_kind] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _sprite_cache[p_kind]


func _draw() -> void:
	var s := minf(size.x, size.y)
	var sprite := sprite_for(kind)
	if sprite != null:
		var tint := Color(1, 1, 1, color.a)
		if follow != null and follow.disabled:
			tint = Color(0.55, 0.55, 0.55, color.a)
		draw_texture_rect(sprite, Rect2(Vector2.ZERO, Vector2(s, s)), false, tint)
		return
	match kind:
		"coin":
			draw_circle(Vector2(s, s) / 2.0, s * 0.46, color)
			draw_arc(Vector2(s, s) / 2.0, s * 0.3, 0.0, TAU, 24, UiTheme.DARK_ON_BRASS, width * 0.6)
		"gem":
			draw_colored_polygon(_pts(s, [[0.5, 0.06], [0.92, 0.38], [0.5, 0.94], [0.08, 0.38]]), color)
			draw_polyline(_pts(s, [[0.08, 0.38], [0.92, 0.38]]), UiTheme.BG, width * 0.5)
			if outline.a > 0.0:
				draw_polyline(_pts(s, [[0.5, 0.06], [0.92, 0.38], [0.5, 0.94], [0.08, 0.38], [0.5, 0.06]]), outline, width * 0.8)
		"lock":
			draw_rect(Rect2(s * 0.2, s * 0.45, s * 0.6, s * 0.45), color, false, width)
			draw_arc(Vector2(s * 0.5, s * 0.45), s * 0.2, PI, TAU, 16, color, width)
		"chest":
			draw_rect(Rect2(s * 0.12, s * 0.45, s * 0.76, s * 0.4), color, false, width)
			draw_arc(Vector2(s * 0.5, s * 0.45), s * 0.38, PI, TAU, 20, color, width)
			draw_line(Vector2(s * 0.5, s * 0.5), Vector2(s * 0.5, s * 0.64), color, width)
		"crown":
			draw_polyline(_pts(s, [[0.1, 0.78], [0.04, 0.3], [0.32, 0.5], [0.5, 0.16], [0.68, 0.5],
					[0.96, 0.3], [0.9, 0.78], [0.1, 0.78]]), color, width)
		"back":
			draw_polyline(_pts(s, [[0.65, 0.15], [0.3, 0.5], [0.65, 0.85]]), color, width)
		"swords":
			draw_line(Vector2(s * 0.15, s * 0.85), Vector2(s * 0.85, s * 0.15), color, width)
			draw_line(Vector2(s * 0.15, s * 0.15), Vector2(s * 0.85, s * 0.85), color, width)
		"cube":
			draw_polyline(_pts(s, [[0.5, 0.08], [0.9, 0.3], [0.9, 0.7], [0.5, 0.92], [0.1, 0.7],
					[0.1, 0.3], [0.5, 0.08]]), color, width)
			draw_polyline(_pts(s, [[0.1, 0.3], [0.5, 0.52], [0.9, 0.3]]), color, width)
			draw_line(Vector2(s * 0.5, s * 0.52), Vector2(s * 0.5, s * 0.92), color, width)
		"spark":
			draw_polyline(_pts(s, [[0.5, 0.08], [0.6, 0.4], [0.92, 0.5], [0.6, 0.6], [0.5, 0.92],
					[0.4, 0.6], [0.08, 0.5], [0.4, 0.4], [0.5, 0.08]]), color, width)
		"tower":
			draw_polyline(_pts(s, [[0.22, 0.92], [0.22, 0.3], [0.78, 0.3], [0.78, 0.92]]), color, width)
			draw_polyline(_pts(s, [[0.14, 0.3], [0.14, 0.12], [0.34, 0.12], [0.34, 0.2], [0.66, 0.2],
					[0.66, 0.12], [0.86, 0.12], [0.86, 0.3]]), color, width)
		"bag":
			draw_polyline(_pts(s, [[0.22, 0.32], [0.78, 0.32], [0.86, 0.9], [0.14, 0.9], [0.22, 0.32]]),
					color, width)
			draw_arc(Vector2(s * 0.5, s * 0.32), s * 0.18, PI, TAU, 12, color, width)
		"gear":
			draw_arc(Vector2(s, s) / 2.0, s * 0.2, 0.0, TAU, 20, color, width)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(Vector2(s, s) / 2.0 + Vector2(cos(a), sin(a)) * s * 0.32,
						Vector2(s, s) / 2.0 + Vector2(cos(a), sin(a)) * s * 0.46, color, width)
		"clock":
			draw_arc(Vector2(s, s) / 2.0, s * 0.44, 0.0, TAU, 24, color, width)
			draw_polyline(_pts(s, [[0.5, 0.25], [0.5, 0.5], [0.68, 0.6]]), color, width)
		"check":
			draw_polyline(_pts(s, [[0.15, 0.55], [0.4, 0.8], [0.88, 0.25]]), color, width * 1.3)
		"sword":
			draw_line(Vector2(s * 0.2, s * 0.8), Vector2(s * 0.8, s * 0.2), color, width)
			draw_line(Vector2(s * 0.3, s * 0.45), Vector2(s * 0.55, s * 0.7), color, width)
		"rain":
			for k in [-1, 0, 1]:
				var x: float = s * (0.5 + k * 0.22)
				var off: float = absf(k) * s * 0.08
				draw_line(Vector2(x, s * 0.12 + off), Vector2(x, s * 0.52 + off), color, width)
			draw_rect(Rect2(s * 0.34, s * 0.7, s * 0.32, s * 0.2), color, false, width)
		"tap":
			draw_arc(Vector2(s * 0.5, s * 0.34), s * 0.2, PI, TAU, 14, color, width)
			draw_polyline(_pts(s, [[0.3, 0.34], [0.3, 0.84], [0.7, 0.84], [0.7, 0.34]]), color, width)
		"rock":
			draw_polyline(_pts(s, [[0.08, 0.78], [0.14, 0.46], [0.36, 0.2], [0.62, 0.16], [0.86, 0.4],
					[0.92, 0.78], [0.08, 0.78]]), color, width)
			draw_polyline(_pts(s, [[0.36, 0.2], [0.44, 0.5], [0.62, 0.16]]), color, width)
			draw_line(Vector2(s * 0.44, s * 0.5), Vector2(s * 0.5, s * 0.78), color, width)
		"crusher":
			draw_polyline(_pts(s, [[0.12, 0.18], [0.88, 0.18], [0.62, 0.58], [0.38, 0.58], [0.12, 0.18]]), color, width)
			draw_rect(Rect2(s * 0.42, s * 0.58, s * 0.16, s * 0.16), color, false, width)
			draw_rect(Rect2(s * 0.30, s * 0.82, s * 0.1, s * 0.1), color)
			draw_rect(Rect2(s * 0.50, s * 0.86, s * 0.1, s * 0.1), color)
			draw_rect(Rect2(s * 0.68, s * 0.80, s * 0.1, s * 0.1), color)
		"conveyor":
			draw_rect(Rect2(s * 0.08, s * 0.46, s * 0.84, s * 0.22), color, false, width)
			draw_circle(Vector2(s * 0.2, s * 0.57), s * 0.07, color)
			draw_circle(Vector2(s * 0.8, s * 0.57), s * 0.07, color)
			draw_rect(Rect2(s * 0.3, s * 0.3, s * 0.12, s * 0.12), color)
			draw_rect(Rect2(s * 0.54, s * 0.26, s * 0.14, s * 0.16), color)
			draw_polyline(_pts(s, [[0.36, 0.82], [0.64, 0.82], [0.56, 0.76]]), color, width)
		"blaster":
			draw_rect(Rect2(s * 0.14, s * 0.5, s * 0.72, s * 0.36), color, false, width)
			draw_line(Vector2(s * 0.5, s * 0.5), Vector2(s * 0.5, s * 0.22), color, width)
			draw_line(Vector2(s * 0.32, s * 0.2), Vector2(s * 0.68, s * 0.2), color, width * 1.4)
			draw_line(Vector2(s * 0.14, s * 0.66), Vector2(s * 0.86, s * 0.66), color, width)
		"winch":
			draw_arc(Vector2(s * 0.5, s * 0.3), s * 0.2, 0.0, TAU, 24, color, width)
			draw_circle(Vector2(s * 0.5, s * 0.3), s * 0.05, color)
			draw_line(Vector2(s * 0.3, s * 0.3), Vector2(s * 0.3, s * 0.76), color, width)
			draw_polyline(_pts(s, [[0.3, 0.76], [0.3, 0.9], [0.4, 0.9], [0.4, 0.84]]), color, width)
			draw_line(Vector2(s * 0.12, s * 0.08), Vector2(s * 0.88, s * 0.08), color, width)
		"lab":
			draw_polyline(_pts(s, [[0.42, 0.12], [0.42, 0.42], [0.18, 0.84], [0.82, 0.84], [0.58, 0.42], [0.58, 0.12]]), color, width)
			draw_line(Vector2(s * 0.34, s * 0.12), Vector2(s * 0.66, s * 0.12), color, width)
			draw_line(Vector2(s * 0.26, s * 0.66), Vector2(s * 0.74, s * 0.66), color, width)
			draw_circle(Vector2(s * 0.5, s * 0.76), s * 0.05, color)
		"cart":
			draw_polyline(_pts(s, [[0.12, 0.38], [0.88, 0.38], [0.78, 0.7], [0.22, 0.7], [0.12, 0.38]]), color, width)
			draw_circle(Vector2(s * 0.3, s * 0.82), s * 0.08, color)
			draw_circle(Vector2(s * 0.7, s * 0.82), s * 0.08, color)
			draw_polyline(_pts(s, [[0.26, 0.38], [0.34, 0.24], [0.5, 0.3], [0.62, 0.2], [0.74, 0.38]]), color, width)
		"dynamite":
			draw_rect(Rect2(s * 0.3, s * 0.38, s * 0.4, s * 0.52), color, false, width)
			draw_line(Vector2(s * 0.3, s * 0.56), Vector2(s * 0.7, s * 0.56), color, width)
			draw_line(Vector2(s * 0.5, s * 0.38), Vector2(s * 0.5, s * 0.24), color, width)
			draw_polyline(_pts(s, [[0.5, 0.24], [0.62, 0.14], [0.76, 0.18]]), color, width)
		"journal":
			draw_rect(Rect2(s * 0.2, s * 0.14, s * 0.6, s * 0.72), color, false, width)
			draw_line(Vector2(s * 0.34, s * 0.14), Vector2(s * 0.34, s * 0.86), color, width)
			draw_line(Vector2(s * 0.48, s * 0.36), Vector2(s * 0.68, s * 0.36), color, width)
			draw_line(Vector2(s * 0.48, s * 0.52), Vector2(s * 0.68, s * 0.52), color, width)
		"cross":
			draw_line(Vector2(s * 0.22, s * 0.22), Vector2(s * 0.78, s * 0.78), color, width)
			draw_line(Vector2(s * 0.78, s * 0.22), Vector2(s * 0.22, s * 0.78), color, width)
		"star":
			draw_polyline(_pts(s, [[0.5, 0.08], [0.62, 0.38], [0.94, 0.4], [0.7, 0.6], [0.78, 0.92],
					[0.5, 0.74], [0.22, 0.92], [0.3, 0.6], [0.06, 0.4], [0.38, 0.38], [0.5, 0.08]]),
					color, width)
	if tier >= 1:
		for corner in [Vector2(0.06, 0.06), Vector2(0.94, 0.06), Vector2(0.06, 0.94), Vector2(0.94, 0.94)]:
			draw_circle(corner * s, s * 0.035, UiTheme.BRASS)
	if tier >= 2:
		draw_arc(Vector2(s, s) * 0.5, s * 0.5, 0.0, TAU, 48, Color(0.88, 0.71, 0.29), width * 0.7)


func _pts(s: float, list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in list:
		out.append(Vector2(float(p[0]) * s, float(p[1]) * s))
	return out
