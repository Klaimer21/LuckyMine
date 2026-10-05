class_name UiTheme
extends RefCounted
## Палитра и фабрики элементов интерфейса: фетр, слоновая кость и один акцент (латунь).
## Шрифты подхватываются из assets/fonts, если файлы лежат на месте.

const BG := Color(0.055, 0.090, 0.078)
const SURFACE := Color(0.082, 0.133, 0.114)
const LINE := Color(0.149, 0.220, 0.184)
const LINE_STRONG := Color(0.239, 0.353, 0.302)
const TEXT := Color(0.937, 0.910, 0.839)
const MUTE := Color(0.624, 0.690, 0.631)
const BRASS := Color(0.788, 0.643, 0.361)
const BRASS_DIM := Color(0.490, 0.416, 0.243)
const FELT := Color(0.106, 0.251, 0.204)
const DPS := Color(0.659, 0.267, 0.227)
const TANK := Color(0.290, 0.416, 0.561)
const SUP := Color(0.420, 0.541, 0.361)
const INK := Color(0.953, 0.925, 0.855)
const ENEMY := Color(0.169, 0.165, 0.161)
const ENEMY_INK := Color(0.753, 0.333, 0.247)
const DARK_ON_BRASS := Color(0.10, 0.08, 0.03)

const DISPLAY_FONT := "AlfaSlabOne-Regular.ttf"
const BODY_FONT := "BarlowSemiCondensed-SemiBold.ttf"
## Для русского: те же роли, но шрифты с кириллицей (Alfa Slab One и Barlow её не содержат).
const RU_DISPLAY_FONT := "RussoOne-Regular.ttf"
const RU_BODY_FONT := "FiraSansCondensed-SemiBold.ttf"


static var _system_font: SystemFont


## Системный шрифт с поддержкой кириллицы и китайского (шрифты ОС подбираются сами).
static func system_font() -> SystemFont:
	if _system_font == null:
		_system_font = SystemFont.new()
		_system_font.font_names = PackedStringArray(["Noto Sans CJK SC", "PingFang SC", "Microsoft YaHei",
				"Noto Sans SC", "Source Han Sans SC", "Heiti SC", "sans-serif"])
		_system_font.font_weight = 600
	return _system_font


## Делает системный шрифт шрифтом интерфейса по умолчанию (нужно для китайского и запасного вывода).
static func install_system_font() -> void:
	ThemeDB.get_default_theme().default_font = system_font()


static func display_file() -> String:
	return RU_DISPLAY_FONT       # один гарнитур на всех языках (Russo One содержит и латиницу, и кириллицу)


static func body_file() -> String:
	return RU_BODY_FONT


## Файл шрифта из assets/fonts. Для китайского свои файлы не используются (в них нет иероглифов).
## В Alfa Slab One и Barlow нет кириллицы: русские буквы и стрелки берутся из системного шрифта (запасной).
static func font(file_name: String) -> Font:
	if Tr.language == "zh":
		return null
	var path := "res://assets/fonts/" + file_name
	if ResourceLoader.exists(path):
		var loaded := load(path) as FontFile
		if loaded != null and loaded.fallbacks.is_empty():
			loaded.fallbacks = [system_font()]
		return loaded
	return null


## Шрифт для 3D-текста: фирменный, если есть, иначе системный.
static func text_font(display := false) -> Font:
	var f := font(display_file() if display else body_file())
	return f if f != null else system_font()


static func class_color(cls: String) -> Color:
	match cls:
		"DPS":
			return DPS
		"TANK":
			return TANK
		"SUP":
			return SUP
	return ENEMY


## Меньше этого текст на телефоне плохо читается (холст 1080 px ≈ 360 dp: 30 px ≈ 10 dp).
const MIN_LABEL_SIZE := 30
const MIN_KEY_SIZE := 26


## Подпись, которая переносится на следующую строку и занимает всю доступную ширину: описания и пояснения.
## Обычная make_label не переносится: в строке с другими элементами она раздвинула бы весь экран.
static func make_text(text: String, size: int, color := TEXT) -> Label:
	var label := make_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func make_label(text: String, size: int, color := TEXT, display := false) -> Label:
	size = maxi(size, MIN_LABEL_SIZE)
	var label := Label.new()
	label.text = Tr.t(text)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	var f := font(display_file() if display else body_file())
	if f != null:
		label.add_theme_font_override("font", f)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Ползунок под палец: толстая дорожка и большой круглый бегунок.
static func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = SURFACE
	track.set_corner_radius_all(10)
	track.set_border_width_all(1)
	track.border_color = LINE_STRONG
	track.content_margin_top = 14
	track.content_margin_bottom = 14
	slider.add_theme_stylebox_override("slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = BRASS_DIM
	filled.set_corner_radius_all(10)
	filled.content_margin_top = 14
	filled.content_margin_bottom = 14
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _slider_knob()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	slider.add_theme_icon_override("grabber_disabled", knob)


static var _knob: ImageTexture


static func _slider_knob() -> ImageTexture:
	if _knob != null:
		return _knob
	var size := 80
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var edge := clampf(center.x - d, 0.0, 1.0)        # 1 внутри круга, мягкая кромка в 1 пиксель
			var ring := d > center.x - 6.0
			var color := BRASS_DIM if ring else BRASS
			image.set_pixel(x, y, Color(color, edge))
	_knob = ImageTexture.create_from_image(image)
	return _knob


static func make_button(text: String, brass: bool, size := 32) -> Button:
	size = maxi(size, MIN_KEY_SIZE)
	var button := Button.new()
	button.text = Tr.t(text)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", DARK_ON_BRASS if brass else TEXT)
	button.add_theme_color_override("font_hover_color", DARK_ON_BRASS if brass else TEXT)
	button.add_theme_color_override("font_pressed_color", DARK_ON_BRASS if brass else TEXT)
	button.add_theme_color_override("font_disabled_color", MUTE)
	var f := font(body_file())
	if f != null:
		button.add_theme_font_override("font", f)
	button.add_theme_stylebox_override("normal", _box(BRASS if brass else Color(0, 0, 0, 0), brass))
	button.add_theme_stylebox_override("hover", _box(BRASS.lightened(0.08) if brass else SURFACE, brass))
	button.add_theme_stylebox_override("pressed", _box(BRASS.darkened(0.12) if brass else LINE, brass))
	button.add_theme_stylebox_override("disabled", _box(SURFACE, false))
	button.custom_minimum_size.y = 84
	# лёгкое «вдавливание» при нажатии, как у клавиш
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.button_down.connect(func() -> void: _press_tween(button, 0.97, 0.06))
	button.button_up.connect(func() -> void: _press_tween(button, 1.0, 0.12))
	return button


## Плавное появление экрана или панели.
static func fade_in(control: Control, seconds := 0.18) -> void:
	if not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, seconds).set_ease(Tween.EASE_OUT)


## Кнопка-«клавиша» с толстой нижней кромкой: при нажатии вдавливается.
## kind: brass, felt (включено), dark (выключено), ember (опасное действие, ржавый).
static func make_key(text: String, size := 32, kind := "brass") -> Button:
	size = maxi(size, MIN_KEY_SIZE)
	var button := Button.new()
	button.text = Tr.t(text)
	button.add_theme_font_size_override("font_size", size)
	var f := font(display_file())
	if f != null:
		button.add_theme_font_override("font", f)
	style_key(button, kind)
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.button_down.connect(func() -> void: _press_tween(button, 0.95, 0.06))
	button.button_up.connect(func() -> void: _press_tween(button, 1.0, 0.12))
	return button


static func _press_tween(button: Button, target: float, seconds: float) -> void:
	if not button.is_inside_tree():
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(target, target), seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Перекрашивает клавишу (можно вызывать повторно, например при смене состояния).
static func style_key(button: Button, kind: String) -> void:
	var fill := BRASS
	var edge := BRASS_DIM
	var ink := DARK_ON_BRASS
	match kind:
		"felt":
			fill = FELT
			edge = Color(0.05, 0.13, 0.10)
			ink = TEXT
		"dark":
			fill = SURFACE
			edge = LINE
			ink = MUTE
		"ember":
			fill = Color(0.60, 0.28, 0.17)
			edge = Color(0.33, 0.14, 0.09)
			ink = TEXT
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, ink)
	button.add_theme_color_override("font_disabled_color", MUTE)
	button.add_theme_stylebox_override("normal", _key_box(fill, edge, false))
	button.add_theme_stylebox_override("hover", _key_box(fill.lightened(0.06), edge, false))
	button.add_theme_stylebox_override("focus", _key_box(fill, edge, false))
	button.add_theme_stylebox_override("pressed", _key_box(fill.darkened(0.05), edge, true))
	button.add_theme_stylebox_override("disabled", _key_box(BG, LINE, false))


static func _key_box(fill: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(18)
	style.border_color = edge
	style.border_width_bottom = 2 if pressed else 7
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 13 if pressed else 8
	style.content_margin_bottom = 6 if pressed else 11
	return style


static func _box(fill: Color, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	if not filled:
		style.set_border_width_all(1)
		style.border_color = LINE_STRONG
	return style


## Цвет рамки по редкости: от тонкой линии до латуни.
static func rarity_color(rarity: int) -> Color:
	match rarity:
		0:
			return LINE_STRONG
		1:
			return Color(0.290, 0.353, 0.227)
		2:
			return BRASS_DIM
	return BRASS


static func panel_style(fill: Color, border: Color, border_width := 1, radius := 12, margin := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	return style


## Ряд точек-«звёзд»: filled заполненных из total.
static func pip_row(filled: int, total := 5, px := 14) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(px, px)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(px)
		if i < filled:
			style.bg_color = BRASS
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.set_border_width_all(1)
			style.border_color = Color(0.365, 0.435, 0.384)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
	return row


## Тонкая полоска прогресса.
static func make_bar(ratio: float, color := BRASS, height := 12) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.09)      # светлее фона: пустая шкала видна на тёмных панелях
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


static func hairline() -> ColorRect:
	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Полноэкранный фон экрана (непрозрачный).
static func make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


## Кнопка с иконкой по центру (иконка не получает нажатий).
static func icon_button(kind: String, color: Color, icon_px: float, button_size: Vector2) -> Button:
	var button := make_button("", false, 24)
	button.custom_minimum_size = button_size
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(Icon.new().setup(kind, color, icon_px))
	button.add_child(center)
	return button
