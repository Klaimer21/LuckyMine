class_name InfoDialogs
extends RefCounted
## Информационные окна: ежедневная награда, знакомство с Борком, «пока вас не было», статистика.

var host: Control
var state: ClickerState
var _settings: Settings
var _sfx: Sfx
var _toast: Callable
var _start_tutorial: Callable
var _on_double: Callable          # «×2 за рекламу» в окне офлайна: проверку и показ рекламы делает main


func setup(host_node: Control, game_state: ClickerState, game_settings: Settings, sound: Sfx, show_toast: Callable,
		start_tutorial: Callable, on_double: Callable) -> InfoDialogs:
	host = host_node
	state = game_state
	_settings = game_settings
	_sfx = sound
	_toast = show_toast
	_start_tutorial = start_tutorial
	_on_double = on_double
	return self


## Ежедневная награда: семь дней по кругу, серия обрывается, если пропустить сутки.
func show_daily() -> void:
	var slot := state.daily_next_slot()
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Ежедневная награда", 50, UiTheme.TEXT, true))
	var days := HBoxContainer.new()
	days.add_theme_constant_override("separation", 8)
	modal.body.add_child(days)
	for i in Retention.DAILY.size():
		var reward: Dictionary = Retention.DAILY[i]
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := UiTheme.BRASS if i == slot else UiTheme.LINE
		cell.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE if i != slot else UiTheme.FELT, border, 2 if i == slot else 1, 12, 8))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		cell.add_child(box)
		var day_label := UiTheme.make_label(str(i + 1), 24, UiTheme.MUTE)
		day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(day_label)
		var icon_row := CenterContainer.new()
		icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kind := "coin" if reward.has("coins") else "gem"
		icon_row.add_child(Icon.new().setup(kind, UiTheme.BRASS if kind == "coin" else Color(0.55, 0.86, 0.90), 36))
		box.add_child(icon_row)
		var text := ""
		if reward.has("diamonds"):
			text = "+%d" % int(reward["diamonds"])
		if reward.has("points"):
			text += " +" + Tr.t("очко")
		if reward.has("dynamite"):
			text += " +%d " % int(reward["dynamite"]) + Tr.t("дин.")
		var amount := UiTheme.make_label(text, 22, UiTheme.TEXT)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(amount)
		days.add_child(cell)
	var claim := UiTheme.make_button("Забрать", true, 36)
	claim.custom_minimum_size.y = 90
	claim.pressed.connect(func() -> void:
			var result := state.claim_daily()
			if not result.is_empty():
				state.save()
				_sfx.play("claim", -4.0)
				_settings.vibrate(30)
				var parts: Array[String] = []
				if result.has("coins"):
					parts.append("+" + NumberFormat.short(float(result["coins"])))
				if result.has("diamonds"):
					parts.append("+%d" % int(result["diamonds"]))
				if result.has("points"):
					parts.append("+%d " % int(result["points"]) + Tr.t("очко"))
				if int(result.get("dynamite", 0)) > 0:
					parts.append(Tr.t("Динамит +%d") % int(result["dynamite"]))
				_toast.call(Tr.t("Ежедневная награда") + ": " + ", ".join(parts))
			modal.close())
	modal.body.add_child(claim)
	host.add_child(modal)


## Знакомство: Борк рассказывает, что к чему, и предлагает обучение.
func show_intro() -> void:
	var modal := Modal.new()
	var face := Companion.portrait(400.0)
	if face != null:
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		modal.body.add_child(face)
	modal.body.add_child(UiTheme.make_label("Борк, бригадир", 46, UiTheme.BRASS, true))
	var talk := UiTheme.make_label("Здорово, новичок! Я Борк, бригадир этой шахты. Камни сами себя не расколют: роняй обвалы, копи монеты и копай всё глубже: чем ниже, тем богаче порода. Давай покажу, что к чему.", 30, UiTheme.TEXT)
	talk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(talk)
	var start_button := UiTheme.make_key("Показать", 34, "brass")
	start_button.custom_minimum_size.y = 88
	start_button.pressed.connect(func() -> void:
			modal.close()
			_start_tutorial.call())
	modal.body.add_child(start_button)
	var skip := UiTheme.make_button("Я разберусь сам", false, 28)
	skip.pressed.connect(func() -> void:
			state.tutorial_done = true
			state.save()
			modal.close())
	modal.body.add_child(skip)
	host.add_child(modal)


func format_duration(seconds: float) -> String:
	var total := int(seconds)
	var hours := floori(total / 3600.0)
	var minutes := floori(total / 60.0) % 60
	return (Tr.t("%d ч %d мин") % [hours, minutes]) if hours > 0 else (Tr.t("%d мин") % maxi(1, minutes))


## Окно «пока вас не было»: время, монеты, лимит офлайна и что ждёт в журнале.
func show_offline(earned: float) -> Modal:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("С возвращением!", 54, UiTheme.TEXT, true))
	modal.body.add_child(UiTheme.make_label(Tr.t("Вас не было: %s") % format_duration(state.offline_away), 30, UiTheme.MUTE))
	var income := UiTheme.make_label("+" + NumberFormat.short(earned), 72, UiTheme.BRASS, true)
	modal.body.add_child(income)
	if state.offline_capped:
		var cap := UiTheme.make_label(Tr.t("Офлайн-доход копится не дольше %s. «Долгая смена» на вкладке «Планета» увеличивает лимит.") % format_duration(state.offline_cap_seconds()), 24, UiTheme.MUTE)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(cap)
	if state.expedition_ready():
		modal.body.add_child(UiTheme.make_label(Tr.t("Поход завершён: заберите добычу в журнале."), 26, UiTheme.TEXT))
	if state.claimable_achievements() > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Есть награды за достижения."), 26, UiTheme.TEXT))
	var ok := UiTheme.make_key("Продолжить", 34, "brass")
	ok.custom_minimum_size.y = 88
	ok.pressed.connect(modal.close)
	var double := UiTheme.make_key(Tr.t("×2 за рекламу"), 32, "felt")
	double.custom_minimum_size.y = 88
	double.pressed.connect(func() -> void:
			_on_double.call())
	modal.body.add_child(double)
	modal.body.add_child(ok)
	host.add_child(modal)
	return modal


func show_stats() -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Статистика", 54, UiTheme.TEXT, true))
	var seconds := int(state.play_seconds)
	var rows: Array = [
		["Время в игре", "%d:%02d:%02d" % [floori(seconds / 3600.0), floori(seconds / 60.0) % 60, seconds % 60]],
		["Заработано за всё время", NumberFormat.short(state.lifetime_earned)],
		["Разбито камней", NumberFormat.short(float(state.rocks_broken))],
		["Находок руды", str(int(state.finds[1]) + int(state.finds[2]) + int(state.finds[3]) + int(state.finds[4]))],
		["Алмазов", str(state.diamonds)],
		["Золотых глыб поймано", str(state.golden_caught)],
		["Динамита взорвано", str(state.dynamite_used)],
		["Хранителей побеждено", str(state.bosses_defeated)],
		["Новых шахт", str(state.prestiges)],
		["Планета", Tr.t(Biomes.planet_name(state.planet))],
		["Жил", str(state.veins)],
		["Звёздной пыли", str(state.stardust)],
		["Наград получено", str(state.achievements_claimed.size())],
		["Просмотрено реклам", str(state.ads_watched)],
	]
	for entry in rows:
		var line := HBoxContainer.new()
		var name_label := UiTheme.make_label(Tr.t(str(entry[0])), 28, UiTheme.MUTE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiTheme.make_label(str(entry[1]), 30, UiTheme.TEXT, true))
		modal.body.add_child(line)
	var close_button := UiTheme.make_button("Закрыть", false, 32)
	close_button.pressed.connect(modal.close)
	modal.body.add_child(close_button)
	host.add_child(modal)
