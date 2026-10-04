class_name UpgradesSheet
extends RefCounted
## Меню улучшений: лист, выезжающий над нижней панелью. Режимы покупки ×1…Макс, автопокупка, карточки улучшений,
## их цены и доступность. Деньги и уровни хранит ClickerState; интерфейс вокруг (счётчик, подсказки) — в main (обратные вызовы).

const UPGRADE_NAMES := {"rain": "Камнепад", "tap": "Сила обвала", "faces": "Глубина", "mult": "Добыча"}
const UPGRADE_ICONS := {"rain": "rain", "tap": "tap", "faces": "gem", "mult": "cross"}

var host: Control
var state: ClickerState
var sheet: PanelContainer
var sheet_open := false
var upgrades_button: Button              # кнопка «Улучшения» в нижней панели: подпись показывает, что можно купить
var autobuy_button: Button
var rows: Dictionary = {}                # ключ улучшения -> {level, effect, button, coin}
var panel_height := 350.0

var _settings: Settings
var _sfx: Sfx
var _on_changed: Callable                # что-то куплено или переключено: main обновляет остальной интерфейс
var _on_lift: Callable                   # лист выехал/уехал: main поднимает подсказку Борка (высота листа или 0)
var _on_bought: Callable                 # куплено улучшение key (для обучения)
var _mode_buttons: Array[Button] = []
var _tween: Tween
var _slide := 0.0
var _afford_mask := -1
var _autobuy_time := 0.0


func setup(host_node: Control, game_state: ClickerState, game_settings: Settings, sound: Sfx, height: float,
		on_changed: Callable, on_lift: Callable, on_bought: Callable) -> UpgradesSheet:
	host = host_node
	state = game_state
	_settings = game_settings
	_sfx = sound
	panel_height = height
	_on_changed = on_changed
	_on_lift = on_lift
	_on_bought = on_bought
	return self


func reset_affordability() -> void:
	_afford_mask = -1


## Каждый кадр: изменился ли набор доступных покупок (тогда main обновляет подписи).
func poll_affordable() -> bool:
	var mask := 0
	for i in ClickerState.ORDER.size():
		var count := buy_count(ClickerState.ORDER[i])
		if state.coins >= state.cost_for(ClickerState.ORDER[i], count):
			mask |= 1 << i
		mask = hash([mask, count])
	if mask == _afford_mask:
		return false
	_afford_mask = mask
	return true


## Рамка карточки «Камнепад» (или кнопки «Улучшения», пока лист закрыт): для подсветки в обучении.
func rain_rect() -> Rect2:
	if sheet.visible:
		return (rows["rain"]["button"] as Control).get_parent().get_global_rect()
	return upgrades_button.get_global_rect()


## Подписи кнопки «Улучшения», автопокупки и карточек по текущему состоянию.
func refresh() -> void:
	var ready_count := 0
	for upgrade_key in ClickerState.ORDER:
		if state.coins >= state.cost_for(upgrade_key, buy_count(upgrade_key)):
			ready_count += 1
	if sheet_open:
		upgrades_button.text = Tr.t("Закрыть")
	else:
		upgrades_button.text = Tr.t("Улучшения") + ((" · %d" % ready_count) if ready_count > 0 else "")
	UiTheme.style_key(upgrades_button, "brass" if ready_count > 0 and not sheet_open else "felt")
	autobuy_button.visible = state.autobuy_interval() > 0.0
	autobuy_button.text = Tr.t("Автопокупка: вкл") if state.autobuy_on else Tr.t("Автопокупка: выкл")
	UiTheme.style_key(autobuy_button, "felt" if state.autobuy_on else "dark")
	for key in ClickerState.ORDER:
		var row: Dictionary = rows[key]
		var count := buy_count(key)
		(row["level"] as Label).text = Tr.t("Ур. %d") % int(state.levels[key]) + (" +%d" % count if count > 1 else "")
		(row["effect"] as Label).text = _effect_text(key, count)
		var button: Button = row["button"]
		var price := state.cost_for(key, count)
		button.text = NumberFormat.short(price)
		var affordable := state.coins >= price
		button.disabled = not affordable
		var coin: Icon = row["coin"]
		coin.color = UiTheme.DARK_ON_BRASS if affordable else UiTheme.BRASS_DIM
		coin.queue_redraw()


## Меню улучшений: выезжает над нижней панелью (панель с «Обвалом» остаётся доступной), закрывается той же кнопкой.
func build(panel: Node) -> void:
	sheet = PanelContainer.new()
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 0.0
	sheet.offset_right = 0.0
	sheet.offset_bottom = -panel_height
	sheet.offset_top = sheet.offset_bottom - 100.0
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.BG
	style.set_border_width_all(0)
	style.border_width_top = 2
	style.border_color = UiTheme.BRASS_DIM
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 16
	sheet.add_theme_stylebox_override("panel", style)
	sheet.visible = false
	sheet_open = false
	_slide = 0.0
	if _tween != null:
		_tween.kill()
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(sheet)
	# лист рисуется под нижней панелью: при выезде он выходит из-за неё, а не наезжает сверху
	host.move_child(sheet, panel.get_index())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	sheet.add_child(column)
	column.add_child(_make_buy_modes())
	autobuy_button = UiTheme.make_key("", 24, "dark")
	autobuy_button.custom_minimum_size.y = 60
	autobuy_button.pressed.connect(func() -> void:
			state.autobuy_on = not state.autobuy_on
			state.save()
			_sfx.play("tick", -6.0)
			_on_changed.call())
	column.add_child(autobuy_button)
	for key in ClickerState.ORDER:
		column.add_child(_make_row(key))


func toggle() -> void:
	sheet_open = not sheet_open
	_slide_sheet(sheet_open)
	_sfx.play("tick", -6.0)
	_afford_mask = -1
	_on_changed.call()


## Меню улучшений выезжает снизу из-за нижней панели и уезжает обратно. Двигаем оба отступа сразу: высота листа не меняется.
func _slide_sheet(open: bool) -> void:
	if _tween != null:
		_tween.kill()
	var height := sheet.get_combined_minimum_size().y
	_on_lift.call(height if open else 0.0)      # подсказка Борка не прячется за открытым меню
	var from := _slide if not open else height + 40.0
	if open:
		sheet.visible = true
		_set_slide(from)
	_tween = sheet.create_tween()
	_tween.tween_method(_set_slide, from, 0.0 if open else height + 40.0, 0.28 if open else 0.2) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if not open:
		_tween.tween_callback(func() -> void: sheet.visible = false)


## Сдвиг листа вниз от своего места на slide пикселей (0 — на месте).
func _set_slide(slide: float) -> void:
	_slide = slide
	var height := sheet.get_combined_minimum_size().y
	sheet.offset_bottom = -panel_height + slide
	sheet.offset_top = sheet.offset_bottom - height
	sheet.modulate.a = clampf(1.0 - slide / (height + 40.0) * 0.8, 0.0, 1.0)


## Автопокупка из мета-улучшения «Автоснабжение»: раз в несколько секунд берёт самое дешёвое улучшение.
func update_autobuy(delta: float) -> void:
	var interval := state.autobuy_interval()
	if interval <= 0.0 or not state.autobuy_on:
		return
	_autobuy_time += delta
	if _autobuy_time < interval:
		return
	_autobuy_time = 0.0
	if state.autobuy_step() != "":
		_sfx.play("tick", -12.0)
		_on_changed.call()


## Сколько уровней купит нажатие в текущем режиме (в «Макс» — сколько хватает монет, но не меньше одного).
func buy_count(key: String) -> int:
	var mode: int = Settings.BUY_MODES[_settings.buy_mode]
	return maxi(1, state.max_affordable(key)) if mode == 0 else mode


## Ряд «×1 ×5 ×10 ×100 Макс» над улучшениями.
func _make_buy_modes() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_mode_buttons.clear()
	for i in Settings.BUY_MODES.size():
		var mode: int = Settings.BUY_MODES[i]
		var button := UiTheme.make_key("Макс" if mode == 0 else "×%d" % mode, 26, "brass" if i == _settings.buy_mode else "dark")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
		button.pressed.connect(func() -> void: set_buy_mode(i))
		row.add_child(button)
		_mode_buttons.append(button)
	return row


func set_buy_mode(index: int) -> void:
	_settings.buy_mode = index
	_settings.save()
	_sfx.play("tick", -6.0)
	for i in _mode_buttons.size():
		UiTheme.style_key(_mode_buttons[i], "brass" if i == index else "dark")
	_afford_mask = -1
	_on_changed.call()


## Карточка улучшения: значок в рамке, название и уровень, что будет на следующем уровне, клавиша с ценой.
func _make_row(key: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG, UiTheme.LINE_STRONG, 1, 14, 10))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(Icon.new().setup(UPGRADE_ICONS[key], UiTheme.BRASS, 44))
	row.add_child(badge)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	texts.add_child(head)
	var title := UiTheme.make_label(UPGRADE_NAMES[key], 32, UiTheme.TEXT)
	head.add_child(title)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0, 0, 0, 0), UiTheme.BRASS_DIM, 1, 12, 3))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var level_label := UiTheme.make_label("", 22, UiTheme.BRASS)
	pill.add_child(level_label)
	head.add_child(pill)
	var effect := UiTheme.make_label("", 26, UiTheme.MUTE)
	texts.add_child(effect)

	var button := UiTheme.make_key("0", 34, "brass")
	button.custom_minimum_size = Vector2(240, 84)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(button.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 66
	var coin := Icon.new().setup("coin", UiTheme.DARK_ON_BRASS, 34)
	coin.position = Vector2(24, 22)
	button.add_child(coin)
	button.pressed.connect(func() -> void:
			if state.buy_n(key, buy_count(key)) > 0:
				state.save()
				_sfx.play("coin", -6.0)
				_settings.vibrate(20)
				_on_changed.call()
				_pulse(button)
				_on_bought.call(key))
	row.add_child(button)
	rows[key] = {"level": level_label, "effect": effect, "button": button, "coin": coin}
	return card


## Короткий «щелчок» кнопки при покупке.
func _pulse(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.06)
	tween.tween_property(button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Текущий эффект и то, что даст следующий уровень.
func _effect_text(key: String, count: int = 1) -> String:
	var level: int = state.levels[key]
	var next := level + count
	match key:
		"rain":
			return Tr.t("%.1f → %.1f глыб в секунду") % [1.0 + 0.8 * level, 1.0 + 0.8 * next]
		"tap":
			return Tr.fmt("%d → %d глыб за обвал", [1 + level, 1 + next])
		"faces":
			return Tr.t("ценность руды 1–%d → 1–%d") % [6 + 2 * level, 6 + 2 * next]
	return Tr.t("×%.2f → ×%.2f ко всему") % [pow(1.5, level), pow(1.5, next)]
