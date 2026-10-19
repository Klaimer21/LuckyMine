class_name Juice
extends RefCounted
## «Сочность» интерфейса: ячейки предметов по редкости, пульсирующие уголки-скобки вокруг того, что можно забрать,
## вращающиеся лучи за наградой, каскадное появление карточек, точки-уведомления на вкладках и окно «Получено!»,
## где награды выскакивают по одной. Всё рисуется кодом в палитре игры.

const RARITY := [Color(0.62, 0.66, 0.62), Color(0.42, 0.66, 0.95), Color(0.72, 0.52, 0.92), Color(0.98, 0.72, 0.25)]
const DOT := Color(0.90, 0.30, 0.24)


## Ячейка предмета: толстая рамка цвета редкости, двухтонная заливка (верх светлее), значок и число в углу.
static func item_slot(icon_kind: String, rarity: int, side := 120.0, count_text := "") -> Control:
	var color: Color = RARITY[clampi(rarity, 0, RARITY.size() - 1)]
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(side, side)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.pixelize(StyleBoxFlat.new(), 10)
	style.bg_color = color.darkened(0.72)
	style.border_color = color
	style.set_border_width_all(5)
	style.border_width_bottom = 9                        # толстая нижняя кромка: ячейка «стоит» на столе
	slot.add_theme_stylebox_override("panel", style)
	var top := ColorRect.new()                           # светлая верхняя половина
	top.color = Color(color.darkened(0.55), 0.9)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(5, 5)
	top.size = Vector2(side - 10, (side - 14) * 0.45)
	slot.add_child(top)
	var icon_side := side * 0.68
	var icon := Icon.new().setup(icon_kind, Color.WHITE, icon_side)
	icon.position = Vector2((side - icon_side) * 0.5, (side - icon_side) * 0.5 - 3.0)
	slot.add_child(icon)
	if count_text != "":
		var font_px := int(side * (0.2 if count_text.length() <= 4 else 0.13))      # длинное число («123.46K») мельче
		var count := Label.new()                              # мимо make_label: у неё минимальный размер для чтения, а здесь цифра в углу
		count.text = count_text
		count.add_theme_font_size_override("font_size", maxi(18, font_px))
		count.add_theme_color_override("font_color", UiTheme.TEXT)
		var count_font := UiTheme.font(UiTheme.display_file(), true)
		if count_font != null:
			count.add_theme_font_override("font", count_font)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.05))
		count.add_theme_constant_override("outline_size", 8)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.size = Vector2(side - 10, side * 0.3)
		count.position = Vector2(2, side - side * 0.36)
		slot.add_child(count)
	return slot


## Пульсирующие уголки-скобки вокруг control (что можно забрать или выбрать).
static func add_brackets(control: Control, color := UiTheme.BRASS) -> void:
	var brackets := JuiceBrackets.new()
	brackets.color = color
	brackets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brackets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(brackets)


## Красная точка-уведомление в правом верхнем углу control.
static func add_dot(control: Control) -> void:
	var dot := JuiceDot.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(dot)
	control.resized.connect(func() -> void: dot.position = Vector2(control.size.x - 26.0, 6.0))
	dot.position = Vector2(control.size.x - 26.0, 6.0)


## Каскад: дети container выезжают снизу и проявляются по очереди.
static func cascade(container: Container, step := 0.035, limit := 14) -> void:
	var index := 0
	for child in container.get_children():
		if not (child is Control) or index >= limit:
			continue
		var item := child as Control
		item.modulate.a = 0.0
		var delay := step * index
		index += 1
		var tween := item.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(item, "modulate:a", 1.0, 0.16)
		# смещение делается через pivot-масштаб: позицию в контейнере трогать нельзя (её ставит раскладка)
		item.pivot_offset = Vector2(item.size.x * 0.5, item.size.y)
		item.scale = Vector2(1.0, 0.92)
		tween.parallel().tween_property(item, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Окно «Получено!»: лучи и свечение, награды выскакивают по одной с отскоком. items — [{icon, count, rarity, name}].
static func reward_reveal(host: Control, title: String, items: Array, subtitle := "") -> Modal:
	var modal := Modal.new()
	var head := UiTheme.make_label(title, 50, UiTheme.BRASS, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal.body.add_child(head)
	if subtitle != "":
		var sub := UiTheme.make_text(subtitle, 26, UiTheme.MUTE)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modal.body.add_child(sub)
	var stage := Control.new()
	var columns := mini(4, maxi(1, items.size()))
	var rows := ceili(items.size() / float(columns))
	var side := 150.0 if items.size() <= 4 else 130.0
	stage.custom_minimum_size = Vector2(0, rows * (side + 100.0) + 40.0)
	modal.body.add_child(stage)
	var rays := JuiceRays.new()
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rays)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	stage.add_child(grid)
	stage.resized.connect(func() -> void:
			rays.size = stage.size
			grid.position = Vector2((stage.size.x - grid.size.x) * 0.5, 20.0))
	for i in items.size():
		var entry: Dictionary = items[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		# количество — крупно под ячейкой (в углу ячейки длинное «123.46K» было бы нечитаемым), ниже название
		var slot := item_slot(str(entry.get("icon", "chest")), int(entry.get("rarity", 0)), side)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(slot)
		var count_label := UiTheme.make_label(str(entry.get("count", "")), 28, UiTheme.BRASS, true)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.visible = count_label.text != ""
		cell.add_child(count_label)
		var name_label := UiTheme.make_label(str(entry.get("name", "")), 20, UiTheme.MUTE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size.x = side + 34.0
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD          # перенос только между словами: «Алмаз / ы» не бывает
		_fit_words(name_label, side + 34.0)
		cell.add_child(name_label)
		grid.add_child(cell)
		# выскакивает по очереди: из точки, с перелётом и отскоком
		slot.pivot_offset = Vector2(side, side) * 0.5
		slot.scale = Vector2.ZERO
		name_label.modulate.a = 0.0
		count_label.modulate.a = 0.0
		var tween := slot.create_tween()
		tween.tween_interval(0.25 + 0.12 * i)
		tween.tween_property(slot, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(name_label, "modulate:a", 1.0, 0.18)
		tween.parallel().tween_property(count_label, "modulate:a", 1.0, 0.18)
		if int(entry.get("rarity", 0)) >= 2:
			tween.tween_callback(func() -> void: add_brackets(slot, RARITY[int(entry["rarity"])]))
	var close := UiTheme.make_button("Отлично", true, 32)
	close.pressed.connect(modal.close)
	modal.body.add_child(close)
	close.modulate.a = 0.0
	close.create_tween().tween_property(close, "modulate:a", 1.0, 0.2).set_delay(0.3 + 0.12 * items.size())
	host.add_child(modal)
	return modal


## Уменьшает шрифт подписи, пока самое длинное слово не влезет в ширину (слова не рвутся посередине).
static func _fit_words(label: Label, width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var widest := 0.0
	for word in label.text.split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if widest > width:
		label.add_theme_font_size_override("font_size", maxi(UiTheme.MIN_LABEL_SIZE, floori(font_size * width / widest)))


## Элемент награды для reward_reveal из обычного словаря выдачи (coins, diamonds, picks, …).
static func items_from(result: Dictionary) -> Array:
	var items: Array = []
	if result.has("coins"):
		items.append({"icon": "px_coins", "count": NumberFormat.short(float(result["coins"])), "rarity": 0, "name": Tr.t("Монеты")})
	if int(result.get("diamonds", 0)) > 0:
		items.append({"icon": "gem", "count": "×%d" % int(result["diamonds"]), "rarity": 1, "name": Tr.t("Алмазы")})
	if int(result.get("picks", 0)) > 0:
		items.append({"icon": "px_pickaxe", "count": "×%d" % int(result["picks"]), "rarity": 0, "name": Tr.t("Кирки")})
	var tokens := int(result.get("tickets", result.get("tokens", 0)))
	if tokens > 0:
		items.append({"icon": "rail_token", "count": "×%d" % tokens, "rarity": 1, "name": Tr.t("Жетоны")})
	if int(result.get("dynamite", 0)) > 0:
		items.append({"icon": "px_bomb", "count": "×%d" % int(result["dynamite"]), "rarity": 0, "name": Tr.t("Динамит")})
	if int(result.get("baits", 0)) > 0:
		items.append({"icon": "pet_bait", "count": "×%d" % int(result["baits"]), "rarity": 1, "name": Tr.t("Приманки")})
	if int(result.get("chest", 0)) > 0:
		items.append({"icon": "chest", "count": "×%d" % int(result["chest"]), "rarity": 2, "name": Tr.t("Сундук удачи")})
	if int(result.get("golden", 0)) > 0:
		items.append({"icon": "chest", "count": "×%d" % int(result["golden"]), "rarity": 3, "name": Tr.t("Золотой сундук")})
	if int(result.get("points", 0)) > 0:
		items.append({"icon": "px_scroll", "count": "×%d" % int(result["points"]), "rarity": 3, "name": Tr.t("Очки навыков")})
	if result.has("shards") and typeof(result["shards"]) == TYPE_DICTIONARY:
		for id in result["shards"]:
			var entry := Artifacts.data(str(id))
			items.append({"icon": "art_" + str(id), "count": "×%d" % int(result["shards"][id]), "rarity": int(entry.get("rarity", 0)),
					"name": Tr.t("Осколки")})
	return items
