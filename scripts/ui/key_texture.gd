class_name KeyTexture
extends Control
## Пиксельная «фактура» поверх большой кнопки: мелкая крапинка, блик по верхнему краю, тень снизу и четыре заклёпки в углах.
## Рисуется поверх (текст кнопки ниже виден чуть приглушённым, поэтому крапинка очень слабая); ввод не перехватывает.

const CELL := 4                          # пиксель текстуры = 4 пикселя холста, как у остального пиксель-арта
const TILE := 16                         # клеток в стороне плитки
static var _tile: ImageTexture

var border := 4.0                        # толщина рамки кнопки по бокам и сверху
var bottom := 12.0                       # толщина нижней грани (кнопка выглядит приподнятой)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


static func tile_texture() -> ImageTexture:
	if _tile != null:
		return _tile
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var image := Image.create(TILE * CELL, TILE * CELL, false, Image.FORMAT_RGBA8)
	for cy in TILE:
		for cx in TILE:
			var roll := rng.randf()
			var color := Color(0, 0, 0, 0)
			if roll < 0.10:
				color = Color(1, 1, 1, 0.10)
			elif roll < 0.22:
				color = Color(0, 0, 0, 0.09)
			if color.a > 0.0:
				image.fill_rect(Rect2i(cx * CELL, cy * CELL, CELL, CELL), color)
	_tile = ImageTexture.create_from_image(image)
	return _tile


func _draw() -> void:
	var inner := Rect2(border, border, size.x - border * 2.0, size.y - border - bottom)
	if inner.size.x < 16.0 or inner.size.y < 16.0:
		return
	draw_texture_rect(tile_texture(), inner, true)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, CELL)), Color(1, 1, 1, 0.20))                       # блик сверху
	draw_rect(Rect2(inner.position, Vector2(CELL, inner.size.y)), Color(1, 1, 1, 0.10))                       # и слева
	draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y - CELL), Vector2(inner.size.x, CELL)), Color(0, 0, 0, 0.14))   # тень снизу
	if size.x > 120.0 and size.y > 70.0:
		for corner in [Vector2(10, 10), Vector2(size.x - 18, 10), Vector2(10, size.y - bottom - 18), Vector2(size.x - 18, size.y - bottom - 18)]:
			draw_rect(Rect2(corner, Vector2(8, 8)), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(corner, Vector2(4, 4)), Color(1, 1, 1, 0.35))
