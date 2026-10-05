class_name MachineStrip
extends RefCounted
## Полоса машин над столом: ячейка на каждую машину (закрытая показывает замок и условие), нажатие открывает
## карточку с описанием и покупкой. Уровни, цены и эффекты считает ClickerState (docs/MACHINES.md).

const TOP := 366.0                       # под шапкой и кнопкой «Новая шахта», над столом (стол начинается около 548)
const CELL := Vector2(144, 144)          # цель касания 48 dp

var host: Control
var state: ClickerState

var _settings: Settings
var _sfx: Sfx
var _table: MineTable
var _on_changed: Callable                # куплен уровень: main обновляет остальной интерфейс
var _row: HBoxContainer
var _cells: Dictionary = {}              # id -> {button, icon, lock, label, charge, tween}
var _card: Modal
var _card_id := ""
var _card_parts: Dictionary = {}         # подписи и кнопка открытой карточки


func setup(host_node: Control, game_state: ClickerState, game_settings: Settings, sound: Sfx, mine_table: MineTable, on_changed: Callable) -> MachineStrip:
	host = host_node
	state = game_state
	_settings = game_settings
	_sfx = sound
	_table = mine_table
	_on_changed = on_changed
	return self


## Создаёт полосу (при каждой пересборке интерфейса заново): ряд ячеек по центру.
func build() -> void:
	_cells.clear()
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_row.offset_top = TOP
	_row.offset_bottom = TOP + CELL.y
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 20)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_row)
	for entry in Machines.LIST:
		_make_cell(entry)
	refresh()


func _make_cell(entry: Dictionary) -> void:
	var id := str(entry["id"])
	var button := Button.new()
	button.custom_minimum_size = CELL
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE_STRONG, 2, 18, 8))
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	var icon := Icon.new().setup(str(entry["icon"]), UiTheme.BRASS, 72)
	icon.position = Vector2((CELL.x - 72.0) * 0.5, 12.0)
	icon.pivot_offset = Vector2(36.0, 36.0)
	button.add_child(icon)
	var lock := Icon.new().setup("lock", UiTheme.MUTE, 56)
	lock.position = Vector2((CELL.x - 56.0) * 0.5, 22.0)
	button.add_child(lock)
	var label := UiTheme.make_label("", 30, UiTheme.TEXT)
	label.position = Vector2(0.0, 92.0)
	label.size = Vector2(CELL.x, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(label)
	var charge := UiTheme.make_bar(0.0, UiTheme.BRASS, 10)         # заряд Подрывника до следующего взрыва
	charge.position = Vector2(14.0, 126.0)
	charge.size = Vector2(CELL.x - 28.0, 10.0)
	charge.visible = false
	button.add_child(charge)
	button.pressed.connect(func() -> void: _open_card(id))
	button.button_down.connect(func() -> void: _press(button, 0.95, 0.06))
	button.button_up.connect(func() -> void: _press(button, 1.0, 0.12))
	_row.add_child(button)
	_cells[id] = {"button": button, "icon": icon, "lock": lock, "label": label, "charge": charge, "tween": null}


func _press(button: Control, target: float, seconds: float) -> void:
	if not button.is_inside_tree():
		return
	button.create_tween().tween_property(button, "scale", Vector2(target, target), seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Каждый кадр: Дробилка сбрасывает глыбы над своей ячейкой; индикатор заряда Подрывника.
func update(_delta: float) -> void:
	if _row == null or _table == null or _table.camera == null:
		return
	var crusher: Dictionary = _cells.get("crusher", {})
	if not crusher.is_empty():
		var button: Button = crusher["button"]
		if button.is_inside_tree() and button.size.x > 1.0:
			_table.set_crusher_screen_x(button.global_position.x + button.size.x * 0.5)
	var blaster: Dictionary = _cells.get("blaster", {})
	if not blaster.is_empty():
		(blaster["charge"] as ProgressBar).value = _table.blaster_charge()


## Подписи и состояние ячеек: закрыта (замок и условие), открыта (значок и уровень), можно купить (латунная рамка).
func refresh() -> void:
	if _row == null:
		return
	for entry in Machines.LIST:
		var id := str(entry["id"])
		var cell: Dictionary = _cells.get(id, {})
		if cell.is_empty():
			continue
		var unlocked := state.machine_unlocked(id)
		var level := state.machine_level(id)
		var affordable := unlocked and level < state.machine_max_level(id) and state.coins >= state.machine_cost(id, 1)
		(cell["icon"] as Icon).visible = unlocked
		(cell["lock"] as Icon).visible = not unlocked
		(cell["label"] as Label).text = (Tr.t("Ур. %d") % level) if unlocked else _lock_text(entry)
		(cell["label"] as Label).add_theme_color_override("font_color", UiTheme.TEXT if unlocked else UiTheme.MUTE)
		(cell["charge"] as ProgressBar).visible = id == "blaster" and unlocked and level > 0
		var border := UiTheme.BRASS if affordable else UiTheme.LINE_STRONG
		var button: Button = cell["button"]
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, UiTheme.panel_style(UiTheme.FELT if unlocked and level > 0 else UiTheme.SURFACE, border, 3 if affordable else 2, 18, 8))
		_animate(cell, unlocked and level > 0 and not _settings.reduce_motion)
	if _card != null and is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_fill_card()


## Что написано на закрытой ячейке: прогресс «Камнепада» или номер зоны.
func _lock_text(entry: Dictionary) -> String:
	if int(entry["unlock_rain"]) > 0:
		return "%d/%d" % [mini(int(state.levels["rain"]), int(entry["unlock_rain"])), int(entry["unlock_rain"])]
	return Tr.t("Зона %d") % int(entry["unlock_zone"])


## Работающая машина слегка покачивается: видно, что она трудится.
func _animate(cell: Dictionary, working: bool) -> void:
	var icon: Icon = cell["icon"]
	if working and cell["tween"] == null and icon.is_inside_tree():
		var tween := icon.create_tween().set_loops()
		tween.tween_property(icon, "rotation", 0.06, 0.28).set_trans(Tween.TRANS_SINE)
		tween.tween_property(icon, "rotation", -0.06, 0.28).set_trans(Tween.TRANS_SINE)
		cell["tween"] = tween
	elif not working and cell["tween"] != null:
		(cell["tween"] as Tween).kill()
		cell["tween"] = null
		icon.rotation = 0.0


# ---------- Карточка машины ----------

func _open_card(id: String) -> void:
	if _card != null and is_instance_valid(_card):
		_card.close()
	var entry: Dictionary = Machines.data(id)
	_card_id = id
	_card = Modal.new()
	_card_parts = {}
	_card.body.add_child(UiTheme.make_label(str(entry["name"]), 54, UiTheme.TEXT, true))
	_card.body.add_child(UiTheme.make_text(str(entry["text"]), 30, UiTheme.MUTE))
	_card_parts["level"] = UiTheme.make_label("", 34, UiTheme.BRASS, true)
	_card.body.add_child(_card_parts["level"])
	_card_parts["effect"] = UiTheme.make_text("", 30, UiTheme.TEXT)
	_card.body.add_child(_card_parts["effect"])
	var buy := UiTheme.make_key("", 36, "brass")
	buy.custom_minimum_size = Vector2(0, 100)
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(buy.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 70
	var coin := Icon.new().setup("coin", UiTheme.DARK_ON_BRASS, 38)
	coin.position = Vector2(26, 28)
	buy.add_child(coin)
	coin.follow_button(buy)
	buy.pressed.connect(func() -> void: _buy(id))
	_card.body.add_child(buy)
	_card_parts["buy"] = buy
	var close_button := UiTheme.make_button("Закрыть", false, 32)
	close_button.pressed.connect(_card.close)
	_card.body.add_child(close_button)
	host.add_child(_card)
	_fill_card()


## Сколько уровней купит нажатие в текущем режиме покупки (как у улучшений; «Макс» — сколько хватает монет, но не меньше одного).
func buy_count(id: String) -> int:
	var mode: int = Settings.BUY_MODES[_settings.buy_mode]
	var room := state.machine_max_level(id) - state.machine_level(id)
	var wanted := maxi(1, state.machine_max_affordable(id)) if mode == 0 else mode
	return clampi(wanted, 1, maxi(room, 1))


func _fill_card() -> void:
	if _card_parts.is_empty():
		return
	var id := _card_id
	var entry: Dictionary = Machines.data(id)
	var unlocked := state.machine_unlocked(id)
	var level := state.machine_level(id)
	var max_level := state.machine_max_level(id)
	var buy: Button = _card_parts["buy"]
	if not unlocked:
		(_card_parts["level"] as Label).text = Tr.t("Закрыто")
		(_card_parts["effect"] as Label).text = _unlock_condition_text(entry)
		buy.visible = false
		return
	buy.visible = true
	(_card_parts["level"] as Label).text = Tr.t("Ур. %d из %d") % [level, max_level]
	var count := buy_count(id)
	if level >= max_level:
		(_card_parts["effect"] as Label).text = _effect_now(id, level) + "\n" + Tr.t("Максимальный уровень")
		buy.text = Tr.t("Максимум")
		buy.disabled = true
		return
	(_card_parts["effect"] as Label).text = _effect_now(id, level) + "\n" + Tr.t("После покупки") + ": " + _effect_after(id, level + count)
	var price := state.machine_cost(id, count)
	buy.text = NumberFormat.short(price) + ("  ×%d" % count if count > 1 else "")
	buy.disabled = not (state.coins >= price)


func _unlock_condition_text(entry: Dictionary) -> String:
	if int(entry["unlock_rain"]) > 0:
		return Tr.t("Откроется: «Камнепад» ур. %d") % int(entry["unlock_rain"])
	return Tr.t("Откроется в зоне: %s") % Tr.t(Biomes.zone_name(int(entry["unlock_zone"]), state.planet))


## Текст эффекта на уровне level (без изменения состояния: уровень подставляется и возвращается).
func _effect_now(id: String, level: int) -> String:
	return Tr.t("Сейчас") + ": " + _effect_text(id, level)


func _effect_after(id: String, level: int) -> String:
	return _effect_text(id, level)


func _effect_text(id: String, level: int) -> String:
	var saved := state.machine_level(id)
	state.machines[id] = level
	var text := ""
	match id:
		"crusher":
			text = Tr.t("+%.1f глыб в секунду") % state.crusher_rate()
		"conveyor":
			text = Tr.t("руда в %d%% глыб") % roundi(100.0 * (1.0 - MineTable.ORE_LIMITS[0] + state.ore_shift()))
		"blaster":
			var interval := state.blaster_interval()
			text = Tr.t("не куплен") if interval <= 0.0 else Tr.t("взрыв раз в %d с, награда %d с дохода") % [roundi(interval), roundi(Machines.BLASTER_SECONDS)]
		"winch":
			text = Tr.t("походы короче на %d%%, офлайн-лимит +%s") % [roundi(100.0 * (1.0 - state.expedition_time_factor())), _hours(Machines.WINCH_OFFLINE_STEP * level)]
		"lab":
			var period := state.lab_interval()
			text = Tr.t("не куплена") if period <= 0.0 else Tr.t("алмаз раз в %d с") % roundi(period)
		"cart":
			text = Tr.t("«Запал» %.1f с, пауза %.1f с") % [state.mini_seconds(), state.mini_cooldown_seconds()]
	state.machines[id] = saved
	return text


func _hours(seconds: float) -> String:
	return Tr.t("%s ч") % ("%.1f" % (seconds / 3600.0))


func _buy(id: String) -> void:
	if state.buy_machine(id, buy_count(id)) > 0:
		_sfx.play("coin", -6.0)
		_settings.vibrate(20)
		state.save()
		_on_changed.call()
	refresh()
