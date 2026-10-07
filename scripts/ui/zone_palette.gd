class_name ZonePalette
extends RefCounted
## Палитры интерфейса по зонам: фон, панели, линии, фетр и акцент (латунь) меняются вместе с зоной.
## Новые окна берут цвета из UiTheme (там переменные), а уже построенный интерфейс перекрашивается обходом дерева.

const KEYS := ["BG", "SURFACE", "LINE", "LINE_STRONG", "FELT", "BRASS", "BRASS_DIM"]

## Порядок цветов: BG, SURFACE, LINE, LINE_STRONG, FELT, BRASS, BRASS_DIM. Нулевая зона — исходная палитра игры.
const ZONES := [
	["0e1714", "15221d", "26382f", "3d5a4d", "1b4034", "c9a45c", "7d6a3e"],   # 0 каменоломня: зелёный фетр и латунь
	["150f0b", "211710", "362619", "5a412c", "4a2e1c", "dc9660", "85553a"],   # 1 медные пещеры
	["0b1017", "131b25", "222f3c", "3c4d5e", "20364a", "b4c3d2", "66798c"],   # 2 железные жилы
	["14110a", "1f1b0f", "362f19", "5a4e2b", "3b3414", "e0b64a", "86702e"],   # 3 золотые залежи
	["07131a", "0e2029", "17353f", "2b5a68", "134650", "6fd9e6", "3a7c8c"],   # 4 кристальная пещера
	["170b09", "241311", "3e201b", "6a362c", "5a2a1c", "ee8a63", "9a5a45"],   # 5 магма
	["0f0a18", "181226", "2a2040", "4a3b70", "34265a", "b48af0", "6a4a9f"],   # 6 ядро
]

static var current_zone := 0
static var _palettes: Array = []


static func colors(zone: int) -> Array:
	if _palettes.is_empty():
		for row in ZONES:
			var cols: Array = []
			for hex in row:
				cols.append(Color(str(hex)))
			_palettes.append(cols)
	return _palettes[clampi(zone, 0, _palettes.size() - 1)]


## Записывает цвета в UiTheme (только для новых элементов; готовые перекрашивает retheme).
static func set_current(cols: Array) -> void:
	UiTheme.BG = cols[0]
	UiTheme.SURFACE = cols[1]
	UiTheme.LINE = cols[2]
	UiTheme.LINE_STRONG = cols[3]
	UiTheme.FELT = cols[4]
	UiTheme.BRASS = cols[5]
	UiTheme.BRASS_DIM = cols[6]


static func current_colors() -> Array:
	return [UiTheme.BG, UiTheme.SURFACE, UiTheme.LINE, UiTheme.LINE_STRONG, UiTheme.FELT, UiTheme.BRASS, UiTheme.BRASS_DIM]


## Мгновенно: палитра зоны и перекраска готового интерфейса root (если задан).
static func apply(zone: int, root: Node = null) -> void:
	var from := current_colors()
	current_zone = zone
	var to := colors(zone)
	set_current(to)
	RenderingServer.set_default_clear_color(UiTheme.BG)
	if root != null:
		retheme(root, from, to)


## Плавно: несколько шагов между палитрами за seconds секунд.
static func shift(zone: int, root: Node, seconds := 0.7) -> void:
	if zone == current_zone or root == null or not root.is_inside_tree():
		return
	var start := current_colors()
	var target := colors(zone)
	current_zone = zone
	var steps := 6
	var tween := root.create_tween()
	for i in range(1, steps + 1):
		var k := float(i) / float(steps)
		tween.tween_interval(seconds / float(steps))
		tween.tween_callback(func() -> void:
				var from := current_colors()
				var mixed: Array = []
				for c in start.size():
					mixed.append((start[c] as Color).lerp(target[c], k))
				set_current(mixed)
				RenderingServer.set_default_clear_color(UiTheme.BG)
				retheme(root, from, mixed))


# ---------- перекраска ----------

const STYLE_NAMES := ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed", "panel", "background", "fill",
		"slider", "grabber_area", "grabber_area_highlight"]
const COLOR_NAMES := ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color",
		"font_outline_color", "font_hover_pressed_color", "icon_normal_color", "icon_pressed_color"]


## Перекрашивает цвета, близкие к цветам палитры from, в соответствующие цвета to: прямые (обычные) и их оттенки
## (светлее, темнее). Остальные цвета (красный динамит, голубые алмазы, руды) не затрагиваются.
static func retheme(root: Node, from: Array, to: Array) -> void:
	var seen := {}
	_walk(root, from, to, seen)


static func _walk(node: Node, from: Array, to: Array, seen: Dictionary) -> void:
	if node is Control:
		var control := node as Control
		for style_name in STYLE_NAMES:
			if control.has_theme_stylebox_override(style_name):
				var box := control.get_theme_stylebox(style_name)
				if box is StyleBoxFlat and not seen.has(box.get_instance_id()):
					seen[box.get_instance_id()] = true
					var flat := box as StyleBoxFlat
					flat.bg_color = map_color(flat.bg_color, from, to)
					flat.border_color = map_color(flat.border_color, from, to)
					flat.shadow_color = map_color(flat.shadow_color, from, to)
		for color_name in COLOR_NAMES:
			if control.has_theme_color_override(color_name):
				control.add_theme_color_override(color_name, map_color(control.get_theme_color(color_name), from, to))
		if control is ColorRect:
			(control as ColorRect).color = map_color((control as ColorRect).color, from, to)
		elif control is Icon:
			var icon := control as Icon
			icon.color = map_color(icon.color, from, to)
			icon.queue_redraw()
	for child in node.get_children():
		_walk(child, from, to, seen)


## Цвет c в палитре from -> такой же по смыслу цвет в палитре to (или c, если он не из этого семейства).
static func map_color(c: Color, from: Array, to: Array) -> Color:
	if c.s < 0.05 and c.v < 0.12:
		return c                         # почти чёрный: тени, затемнения
	if (c.h < 0.065 or c.h > 0.94) and c.s > 0.64:
		return c                         # насыщенный красный и рыжий (динамит, опасные кнопки) не перекрашивается
	var best := -1
	var best_score := 9.0
	for i in from.size():
		var p: Color = from[i]
		var hue_diff := absf(c.h - p.h)
		hue_diff = minf(hue_diff, 1.0 - hue_diff)
		var sat_diff := absf(c.s - p.s)
		if (hue_diff > 0.05 and p.s > 0.12) or sat_diff > 0.16:
			continue
		var score := hue_diff * 4.0 + sat_diff + absf(c.v - p.v) * 0.6
		if score < best_score:
			best_score = score
			best = i
	if best < 0:
		return c
	var p: Color = from[best]
	var q: Color = to[best]
	var value_ratio := c.v / maxf(p.v, 0.02)
	var hue := fposmod(q.h + (c.h - p.h), 1.0)
	return Color.from_hsv(hue, clampf(q.s + (c.s - p.s), 0.0, 1.0), clampf(q.v * value_ratio, 0.0, 1.0), c.a)
