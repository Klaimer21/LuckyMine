class_name UiTheme
extends RefCounted
## Палитра и фабрики элементов интерфейса: фетр, слоновая кость и один акцент (латунь).
## Цвета фона, панелей, линий, фетра и акцента (static var) меняются вместе с зоной: см. ZonePalette.
## Шрифты подхватываются из assets/fonts, если файлы лежат на месте.

static var BG := Color(0.055, 0.090, 0.078)
static var SURFACE := Color(0.082, 0.133, 0.114)
static var LINE := Color(0.149, 0.220, 0.184)
static var LINE_STRONG := Color(0.239, 0.353, 0.302)
const TEXT := Color(0.937, 0.910, 0.839)
const MUTE := Color(0.624, 0.690, 0.631)
static var BRASS := Color(0.788, 0.643, 0.361)
static var BRASS_DIM := Color(0.490, 0.416, 0.243)
static var FELT := Color(0.106, 0.251, 0.204)
const DPS := Color(0.659, 0.267, 0.227)
const TANK := Color(0.290, 0.416, 0.561)
const SUP := Color(0.420, 0.541, 0.361)
const INK := Color(0.953, 0.925, 0.855)
const ENEMY := Color(0.169, 0.165, 0.161)
const ENEMY_INK := Color(0.753, 0.333, 0.247)
const DARK_ON_BRASS := Color(0.10, 0.08, 0.03)

## Шрифты (один набор на все языки, кроме китайского: Russo One и Fira Sans Condensed содержат латиницу и кириллицу).
const PIXEL_DISPLAY := "PixelifySans-Display.ttf"      # Pixelify Sans (OFL), вес 700. В кириллице добавлены О и П, а цифра 5 перерисована (в оригинале похожа на S)
const PIXEL_BODY := "PixelifySans-Body.ttf"            # он же, вес 550
const DISPLAY_FONT := "RussoOne-Regular.ttf"
const BODY_FONT := "FiraSansCondensed-SemiBold.ttf"
const PIXEL_UI := true                                  # пиксельный шрифт вместо Russo One и Fira Sans


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
	return PIXEL_DISPLAY if PIXEL_UI and _has_font(PIXEL_DISPLAY) else DISPLAY_FONT


static func body_file() -> String:
	return PIXEL_BODY if PIXEL_UI and _has_font(PIXEL_BODY) else BODY_FONT


static func _has_font(file_name: String) -> bool:
	return ResourceLoader.exists("res://assets/fonts/" + file_name)



## Файл шрифта из assets/fonts. Для китайского свои файлы не используются (в них нет иероглифов).
## Знаки, которых нет в шрифте (например, стрелка в Russo One), берутся из системного шрифта (запасной).
static func font(file_name: String, display := false) -> Font:
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
	var f := font(display_file() if display else body_file(), display)
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


## Шкала отступов между элементами: плотный, обычный, просторный.
const SPACE_S := 8
const SPACE_M := 16
const SPACE_L := 24

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


## Весь текст интерфейса чуть крупнее заданных размеров (пиксельный шрифт читается лучше покрупнее).
const FONT_SCALE := 1.12


static func make_label(text: String, size: int, color := TEXT, display := false) -> Label:
	size = maxi(roundi(size * FONT_SCALE), MIN_LABEL_SIZE)
	var label := Label.new()
	label.text = Tr.t(text)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	var f := font(display_file() if display else body_file(), display)
	if f != null:
		label.add_theme_font_override("font", f)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Ползунок под палец: толстая дорожка со скошенными углами и квадратный пиксельный бегунок.
static func style_slider(slider: HSlider) -> void:
	var track := pixelize(StyleBoxFlat.new(), 6)
	track.bg_color = SURFACE
	track.set_border_width_all(4)
	track.border_color = BG
	track.content_margin_top = 14
	track.content_margin_bottom = 14
	slider.add_theme_stylebox_override("slider", track)
	var filled := pixelize(StyleBoxFlat.new(), 6)
	filled.bg_color = BRASS_DIM
	filled.set_border_width_all(4)
	filled.border_color = BG
	filled.content_margin_top = 14
	filled.content_margin_bottom = 14
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _slider_knob()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	slider.add_theme_icon_override("grabber_disabled", knob)


static var _knob: ImageTexture
static var _knob_key := Color.BLACK


## Бегунок 48x72: тёмная рамка в 4 пикселя, скошенные углы, блик сверху слева и тень снизу справа (шаг пикселя 4).
static func _slider_knob() -> ImageTexture:
	if _knob != null and _knob_key == BRASS:
		return _knob
	var w := 48
	var h := 72
	var step := 4
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var cx := mini(x, w - 1 - x)
			var cy := mini(y, h - 1 - y)
			if cx + cy < step * 2:
				continue                                  # срезанный угол
			var color: Color
			if cx < step or cy < step:
				color = BG                                # рамка
			elif x < step * 2 or y < step * 2:
				color = BRASS.lightened(0.3)              # блик
			elif x >= w - step * 2 or y >= h - step * 2:
				color = BRASS_DIM                         # тень
			else:
				color = BRASS
			image.set_pixel(x, y, color)
	_knob = ImageTexture.create_from_image(image)
	_knob_key = BRASS
	return _knob


static func make_button(text: String, brass: bool, size := 32) -> Button:
	size = maxi(roundi(size * FONT_SCALE), MIN_KEY_SIZE)
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
	size = maxi(roundi(size * FONT_SCALE), MIN_KEY_SIZE)
	var button := Button.new()
	button.text = Tr.t(text)
	button.add_theme_font_size_override("font_size", size)
	var f := font(display_file(), true)
	if f != null:
		button.add_theme_font_override("font", f)
	style_key(button, kind)
	button.add_child(KeyTexture.new())                       # крапинка, блики и заклёпки: большие кнопки не выглядят плоскими
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


## Пиксельный вид рамки: скошенные углы (по одному «ступенчатому» шагу) и без сглаживания, как у спрайтов.
static func pixelize(style: StyleBoxFlat, radius := 8) -> StyleBoxFlat:
	style.set_corner_radius_all(radius)
	style.corner_detail = 1
	style.anti_aliasing = false
	return style


static func _key_box(fill: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var style := pixelize(StyleBoxFlat.new(), 8)
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(4)
	style.border_width_bottom = 6 if pressed else 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 13 if pressed else 8
	style.content_margin_bottom = 6 if pressed else 11
	return style


static func _box(fill: Color, filled: bool) -> StyleBoxFlat:
	var style := pixelize(StyleBoxFlat.new(), 6)
	style.bg_color = fill
	style.set_content_margin_all(12)
	if not filled:
		style.set_border_width_all(2)
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
	var style := pixelize(StyleBoxFlat.new(), clampi(int(radius / 2.0) * 2 / 2, 4, 10))
	style.bg_color = fill
	style.set_content_margin_all(margin)
	if border_width > 0:
		style.set_border_width_all(maxi(2, border_width + (border_width % 2)))
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
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER      # иначе точка растягивалась бы вровень со строкой
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(px)
		if i < filled:
			style.bg_color = BRASS
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.set_border_width_all(2)
			style.border_color = Color(0.55, 0.62, 0.56)
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
	var back := pixelize(StyleBoxFlat.new(), 4)
	back.bg_color = Color(1, 1, 1, 0.09)      # светлее фона: пустая шкала видна на тёмных панелях
	var fill := pixelize(StyleBoxFlat.new(), 4)
	fill.bg_color = color
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
