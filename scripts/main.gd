extends Node
## LuckyMine: рудный стол, шапка с монетами, строки улучшений, шестерёнка настроек.
## Глыбы падают сами, по кнопке «Обвал» и по касанию стола; каждая, разбиваясь, приносит монеты.

const UPGRADE_NAMES := {"rain": "Камнепад", "tap": "Сила обвала", "faces": "Глубина", "mult": "Добыча"}
const UPGRADE_ICONS := {"rain": "rain", "tap": "tap", "faces": "gem", "mult": "cross"}
const SAVE_EVERY := 5.0
const PANEL_HEIGHT := 350               # нижняя панель: «Обвал», «Авто», «Динамит» и кнопка «Улучшения»

var state := ClickerState.new()
var settings := Settings.new()

var _table: MineTable
var _ui: Control
var _fx: FxLayer
var _dust: CPUParticles2D
var sfx: Sfx
var music: Music
var _throw_row: HBoxContainer
var _upgrades_button: Button
var _sheet_open := false
var _sheet_tween: Tween
var _upgrades_sheet: PanelContainer      # меню улучшений: выезжает над нижней панелью
var _dynamite_button: Button
var _dynamite_shown := -1
var _boost_label: Label
var _boost_shown := false
var _prestige_button: Button
var _prestige_key := -1
var _prestige_hinted := false
var _fps_label: Label
var _depth_label: Label
var _depth_bar: ProgressBar
var _biome := 0
var _toast: Label
var _toast_time := 0.0
var _fps_timer := 0.0
var _stress_active := false
var _stress_time := 0.0
var _stress_deltas := PackedFloat32Array()
var _stress_peak := 0
var _stress_auto_before := true
var _stress_label: Label
var _throw_button: Button
var _mode_buttons: Array[Button] = []
var _auto_button: Button
var _settings_screen: SettingsScreen
var _journal: JournalScreen
var _tutorial: Tutorial
var _hint_card: HintCard
var _peek: CompanionPeek
var _fps_watch_time := 0.0
var _fps_watch_frames := 0
var _fps_hint_done := false
var _journal_button: Button
var _diamonds_shown := -1
var _points_shown := false
var _coins_label: Label
var _coin_icon: Icon
var _rate_label: Label
var _message_label: Label
var _hint: Label
var _hint_hiding := false
var _rows: Dictionary = {}            # ключ улучшения -> {title, effect, button, coin}
var _save_timer := 0.0
var _message_time := 0.0
var _earned_batch := 0.0
var _shown_coins := 0.0
var _shown_text := ""
var _bump := 0.0
var _afford_mask := -1
var _offline_earned := 0.0
var _ads := Ads.new()
var _save_dialogs := SaveDialogs.new()
var _offline_doubled := false
var _autobuy_time := 0.0
var _autobuy_button: Button


func _ready() -> void:
	settings.load_settings()
	Tr.set_language(settings.language)
	UiTheme.install_system_font()
	var offline := state.load_save()
	if not state.style_unlocked(settings.rock_style):
		settings.rock_style = 0
	_shown_coins = state.coins
	_offline_earned = offline

	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)
	_table = MineTable.new()
	add_child(_table)
	_table.setup(state)
	_table.auto_throw = state.auto_throw
	_biome = Biomes.index_for(state.total_earned, state.planet_scale())
	_table.set_biome(_biome)
	_table.set_planet(state.planet)
	music.play_zone(_biome, true)
	_table.biome_changed.connect(_on_biome_changed)
	_table.golden_spawned.connect(func() -> void:
			_show_toast(Tr.t("Золотая глыба! Коснитесь её"))
			sfx.play("golden", -4.0))
	_table.golden_hit.connect(func() -> void:
			state.start_rush(ClickerState.BOOST_SECONDS, false)
			state.golden_caught += 1
			if state.golden_caught % 3 == 0:
				_award_dynamite(1)
			_say_hint("first_rush", "Золотая лихорадка: ×7 к добыче на 15 секунд. На 5 минут её можно купить в журнале за алмазы или получить за рекламу.")
			_show_toast(Tr.t("Золотая лихорадка ×%d") % int(ClickerState.BOOST_FACTOR))
			sfx.play("rush", -3.0)
			sfx.play("claim", -8.0)
			settings.vibrate(30))
	_table.ore_collected.connect(_on_ore_collected)
	_table.boss_spawned.connect(func(_zone: int) -> void:
			_show_toast(Tr.t("Хранитель зоны! Бейте по нему"))
			_say_hint("first_boss", "Хранитель зоны: бейте по нему касаниями или взорвите динамитом. Число над ним — оставшиеся удары. Внутри геода и алмазы.")
			sfx.play("boom", -8.0, 0.6))
	_table.boss_hit.connect(func() -> void: sfx.play("boss_hit", -6.0))
	_table.boss_defeated.connect(_on_boss_defeated)
	_table.boss_gone.connect(func() -> void: _show_toast(Tr.t("Хранитель рассыпался")))
	_table.landed.connect(func(payout: float, real: bool) -> void:
			if not _stress_active:
				_earned_batch += payout
			_bump = minf(1.0, _bump + (0.35 if real else 0.15))
			if real:
				state.rocks_broken += 1
				sfx.crack())
	_table.detonated.connect(func(screen_pos: Vector2) -> void: _fx.blast(screen_pos))
	_table.gem_spawned.connect(func(screen_pos: Vector2, _ore: int) -> void: _fx.glint(screen_pos))
	_table.collected.connect(func(screen_pos: Vector2, color: Color) -> void: _fx.emit_sparks(screen_pos, color))

	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_ads.setup(_ui, state)
	_save_dialogs.setup(_ui, state, _show_toast)
	_build_ui()
	settings.apply(get_viewport(), _table)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if not state.tutorial_done:
				_show_intro())
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if not state.tutorial_done:
				return
			if state.offline_away >= 60.0 and _offline_earned >= 1.0:
				_show_offline().closed.connect(func() -> void:
						if state.daily_available():
							_show_daily())
			elif state.daily_available():
				_show_daily())
	# подсказка про навыки: очки есть, а ни один не куплен
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if state.tutorial_done and state.skill_points > 0 and state.skill_level("drill") + state.skill_level("dynamite") + state.skill_level("luck") == 0:
				_say_hint("skills", "Есть очки навыков: журнал → «Навыки». В каждой ветке навыки открываются по порядку."))


func _process(delta: float) -> void:
	state.play_seconds += delta
	# монеты за разбитые глыбы копятся пачкой за кадр
	if _earned_batch > 0.0:
		state.add_coins(_earned_batch)
		_earned_batch = 0.0
	_update_counter(delta)
	_update_fps(delta)
	_update_stress(delta)
	_update_depth(delta)
	_update_abilities(delta)
	_update_autobuy(delta)
	_update_prestige_button()
	_watch_fps(delta)
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message_label.text = ""
	_save_timer += delta
	if _save_timer >= SAVE_EVERY:
		_save_timer = 0.0
		state.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		state.save()


## Счётчик плавно догоняет значение и «подпрыгивает» от приземлений; кнопки следят за доступностью.
func _update_counter(delta: float) -> void:
	_shown_coins += (state.coins - _shown_coins) * minf(1.0, delta * 9.0)
	if absf(state.coins - _shown_coins) < 0.5:
		_shown_coins = state.coins
	var text := NumberFormat.short(floorf(_shown_coins))
	if text != _shown_text:
		_shown_text = text
		_coins_label.text = text
	_bump = maxf(0.0, _bump - delta * 3.0)
	var zoom := 1.0 + 0.045 * _bump
	_coins_label.pivot_offset = Vector2(0.0, _coins_label.size.y * 0.5)
	_coins_label.scale = Vector2(zoom, zoom)
	_fx.target = _coin_icon.global_position + _coin_icon.size * 0.5
	var mask := 0
	for i in ClickerState.ORDER.size():
		var count := _buy_count(ClickerState.ORDER[i])
		if state.coins >= state.cost_for(ClickerState.ORDER[i], count):
			mask |= 1 << i
		mask = hash([mask, count])
	if mask != _afford_mask:
		_afford_mask = mask
		_refresh()


## Тест нагрузки: 15 секунд максимального потока глыб, замер кадров, итог с рекомендацией.
func _start_stress() -> void:
	if _stress_active:
		return
	_stress_active = true
	_stress_time = 0.0
	_stress_deltas = PackedFloat32Array()
	_stress_peak = 0
	_stress_auto_before = _table.auto_throw
	_table.stress_rate = 500.0
	_stress_label.visible = true


func _update_stress(delta: float) -> void:
	if not _stress_active:
		return
	_stress_time += delta
	if _stress_time > 1.0:                      # первую секунду не считаем: сцена прогревается
		_stress_deltas.append(delta)
	_stress_peak = maxi(_stress_peak, _table.rock_count())
	_stress_label.text = Tr.t("Тест нагрузки") + "  %d" % maxi(0, 15 - int(_stress_time))
	if _stress_time >= 15.0:
		_finish_stress()


func _finish_stress() -> void:
	_stress_active = false
	_table.stress_rate = 0.0
	_table.auto_throw = _stress_auto_before
	_stress_label.visible = false
	var sorted := Array(_stress_deltas)
	sorted.sort()
	var total := 0.0
	for d in sorted:
		total += float(d)
	var average_fps := float(sorted.size()) / maxf(total, 0.0001)
	var worst_count := maxi(1, int(sorted.size() / 100.0))
	var worst := 0.0
	for i in worst_count:
		worst += float(sorted[sorted.size() - 1 - i])
	var low_fps := 1.0 / maxf(worst / worst_count, 0.0001)

	var report := Modal.new()
	report.body.add_child(UiTheme.make_label("Тест нагрузки", 50, UiTheme.TEXT, true))
	report.body.add_child(UiTheme.make_label(Tr.t("Средний FPS: %d") % int(average_fps), 38, UiTheme.TEXT))
	report.body.add_child(UiTheme.make_label(Tr.t("Нижние 1%%: %d") % int(low_fps), 38, UiTheme.TEXT))
	report.body.add_child(UiTheme.make_label(Tr.t("Глыб одновременно: %d") % _stress_peak, 32, UiTheme.MUTE))
	var weak := average_fps < 45.0 or low_fps < 25.0
	var verdict := UiTheme.make_label("FPS низкий: лучше понизить качество." if weak else "Хорошо: качество можно оставить.",
			30, UiTheme.BRASS if weak else UiTheme.MUTE)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.body.add_child(verdict)
	if weak and settings.quality > 0:
		var lower := UiTheme.make_button("Понизить качество", true, 32)
		lower.pressed.connect(func() -> void:
				settings.quality -= 1
				settings.apply(get_viewport(), _table)
				settings.save()
				report.close())
		report.body.add_child(lower)
	var close := UiTheme.make_button("Закрыть", false, 32)
	close.pressed.connect(report.close)
	report.body.add_child(close)
	_ui.add_child(report)


## Глубина и зона: подпись, полоска до следующей зоны, переход при смене зоны.
func _update_depth(delta: float) -> void:
	var total := state.total_earned
	var depth := Biomes.depth_m(total, state.planet_scale())
	var depth_text := Tr.t("%d м · %s") % [depth, Tr.t(Biomes.zone_name(_biome, state.planet))]
	if state.planet > 0:
		depth_text = Tr.t(Biomes.planet_name(state.planet)) + " · " + depth_text
	_depth_label.text = depth_text
	_depth_bar.value = Biomes.progress(total, state.planet_scale())
	_depth_bar.visible = _biome < Biomes.CORE
	var index := Biomes.index_for(total, state.planet_scale())
	if state.planet_ready():
		_say_hint("planet_ready", "Ядро достигнуто! В журнале → «Планета» откроется «Новая планета»: звёздная пыль и мета-улучшения.")
	if index != _biome and not _stress_active:
		_biome = index
		_table.set_biome(index, true)
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(minf(_toast_time, 3.0 - _toast_time) * 2.5, 0.0, 1.0)


## Кнопка «Новая шахта»: видна, когда прибавится хотя бы одна жила; латунная, когда сброс выгоден.
func _update_prestige_button() -> void:
	var pending := state.pending_veins()
	var recommended := state.prestige_recommended()
	var key := pending * 2 + (1 if recommended else 0)
	if key == _prestige_key:
		return
	_prestige_key = key
	_prestige_button.visible = pending >= 1
	if pending >= 1 and state.prestiges == 0 and not _prestige_hinted:
		_prestige_hinted = true
		_show_toast(Tr.t("Открыта «Новая шахта»"))
		_say_hint("prestige_ready", "«Новая шахта» сбрасывает монеты и улучшения, но даёт жилы: доход растёт навсегда, а ещё очки навыков. Лучше жать, когда кнопка латунная.")
	_prestige_button.text = Tr.t("Новая шахта") + "  +%d" % pending
	UiTheme.style_key(_prestige_button, "brass" if recommended else "dark")


func _on_prestige_pressed() -> void:
	var pending := state.pending_veins()
	if pending < 1:
		return
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Новая шахта", 54, UiTheme.TEXT, true))
	var after := 1.0 + state.vein_step() * (state.veins + pending)
	var gain_text := UiTheme.make_label(Tr.t("Вы получите %d жил: доход ×%.1f → ×%.1f") % [pending, state.vein_multiplier(), after], 32, UiTheme.BRASS)
	gain_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(gain_text)
	var reset_text := UiTheme.make_label("Сбросятся монеты и улучшения. Останутся глубина, зона и жилы.", 28, UiTheme.MUTE)
	reset_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(reset_text)
	if not state.prestige_recommended():
		var wait_text := UiTheme.make_label(Tr.t("Лучше подождать: стоит от +%d жил.") % maxi(ClickerState.PRESTIGE_GOOD_MIN, int(0.7 * state.veins)), 26, UiTheme.MUTE)
		wait_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(wait_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	modal.body.add_child(row)
	var cancel := UiTheme.make_button("Отмена", false, 32)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	var ok := UiTheme.make_button("Начать заново", true, 32)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
			var gained := state.prestige()
			_table.clear_field()
			_earned_batch = 0.0
			_shown_coins = state.coins
			state.save()
			_show_toast(Tr.t("Новая шахта! +%d жил") % gained + "  ·  " + Tr.t("очков навыков: %d") % state.skill_points)
			sfx.play("gong", -3.0)
			settings.vibrate(60)
			_table.celebrate()
			_say_hint("after_prestige", "Жилы прибавили доход навсегда. Новые очки навыков тратятся в журнале («Навыки»). Зоны и коллекция остались при вас.")
			_prestige_key = -1
			_afford_mask = -1
			modal.close())
	row.add_child(ok)
	_ui.add_child(modal)


## Обучение: семь коротких шагов; каждый подсвечивает нужный элемент. Можно пропустить; вернуть можно в настройках.
func _build_tutorial() -> void:
	_tutorial = Tutorial.new()
	_ui.add_child(_tutorial)
	_tutorial.steps = [
		{"text": "Касайтесь стола: на месте касания упадут глыбы, а каждая принесёт монеты.",
				"rect": _tut_rect_table, "wait": "tap"},
		{"text": "Жмите «Обвал»: сразу несколько глыб. «Сила обвала» увеличивает их число.",
				"rect": _tut_rect_throw, "wait": "throw"},
		{"text": "Накопите монет, откройте «Улучшения» и купите «Камнепад»: глыбы начнут падать сами.",
				"rect": _tut_rect_rain, "wait": "buy_rain", "done": _tut_rain_bought},
		{"text": "«Авто» включено: шахта работает, даже пока вы не смотрите. Доход копится и офлайн до 8 часов.",
				"rect": _tut_rect_auto, "wait": "next"},
		{"text": "Глубина растёт от заработанного. Новая зона меняет вид и руду, а потом откроется «Новая шахта».",
				"rect": _tut_rect_depth, "wait": "next"},
		{"text": "Иногда падает золотая глыба: коснитесь её. «Динамит» взрывает всё разом и платит крупно, но запас ограничен: его дают за зоны, хранителей и награды.",
				"rect": _tut_rect_dynamite, "wait": "next"},
		{"text": "В журнале: навыки (у вас уже есть 2 очка), коллекция руды, походы и награды. Удачи под землёй!",
				"rect": _tut_rect_journal, "wait": "next"},
	]
	_tutorial.finished.connect(_on_tutorial_done)
	_tutorial.skipped.connect(_on_tutorial_done)


func _tut_rect_table() -> Rect2:
	return _table.screen_rect()


func _tut_rect_throw() -> Rect2:
	return _throw_button.get_global_rect()


func _tut_rect_rain() -> Rect2:
	if _upgrades_sheet.visible:
		return (_rows["rain"]["button"] as Control).get_parent().get_global_rect()
	return _upgrades_button.get_global_rect()


func _tut_rain_bought() -> bool:
	return int(state.levels["rain"]) >= 1


func _tut_rect_auto() -> Rect2:
	return _auto_button.get_global_rect()


func _tut_rect_depth() -> Rect2:
	return _depth_label.get_parent().get_global_rect()


func _tut_rect_dynamite() -> Rect2:
	return _dynamite_button.get_global_rect()


func _tut_rect_journal() -> Rect2:
	return _journal_button.get_global_rect()


func _on_tutorial_done() -> void:
	state.tutorial_done = true
	state.save()
	if state.daily_available():
		_show_daily()


## Подсказка по требованию: один раз за всю игру (и не во время обучения).
func _say_hint(id: String, text: String) -> void:
	if not state.tutorial_done or _stress_active:
		return
	if state.take_hint(id):
		_hint_card.show_hint(Tr.t(text))


## Следим за кадрами: если стабильно мало, один раз советуем снизить качество (только на слабом железе).
func _watch_fps(delta: float) -> void:
	if _fps_hint_done or _stress_active or not state.tutorial_done:
		return
	_fps_watch_time += delta
	_fps_watch_frames += 1
	if _fps_watch_time < 10.0:
		return
	var fps := float(_fps_watch_frames) / _fps_watch_time
	_fps_watch_time = 0.0
	_fps_watch_frames = 0
	if fps < 35.0 and settings.quality > 0:
		_fps_hint_done = true
		_say_hint("low_fps", "Мало кадров в секунду. В настройках можно понизить качество, а «Тест нагрузки» покажет, что тянет устройство.")


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 3.0


func _on_biome_changed(index: int) -> void:
	var data: Dictionary = Biomes.LIST[index]
	_show_toast(Tr.t("Новая зона: %s") % Tr.t(Biomes.zone_name(index, state.planet)))
	sfx.play("zone", -3.0)
	_dust.color = Color((Biomes.ACCENTS[index] as Color) * Biomes.planet_tint(state.planet), 0.32)
	music.play_zone(index)
	if index > state.dynamite_zone_best:
		state.dynamite_zone_best = index
		_award_dynamite(2)
	_say_hint("first_zone", "Новая зона: меняются вид, музыка и руда, а доход растёт. Заглядывайте в журнал: там награды за зоны.")
	match index:
		2:
			_say_hint("zone_2", "Железные жилы. Теперь среди находок попадается золото: оно запускает золотой запал.")
		3:
			_say_hint("zone_3", "Золотые залежи! Руда богаче, а хранители крепче: держите динамит под рукой.")
		4:
			_say_hint("zone_4", "Кристальная пещера. Алмазов здесь больше всего: тратьте их в журнале («Руда»).")
		5:
			_say_hint("zone_5", "Магма: жарко! Дальше только Ядро. Загляните в журнал: пора думать о «Новой шахте».")
	settings.vibrate(40)
	if index == Biomes.CORE and not state.ending_seen:
		state.ending_seen = true
		state.save()
		_show_ending()


## Борк встречает на новой планете: название и её особенность (один раз для каждой планеты).
func _planet_arrival_line() -> void:
	if not state.tutorial_done or not state.take_hint("planet_%d" % state.planet):
		return
	_hint_card.show_hint(Tr.t("Мы на планете: %s! Особенность: %s.") % [Tr.t(Biomes.planet_name(state.planet)), Tr.t(Biomes.planet_mod_text(state.planet))])


func _show_ending() -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Вы достигли Ядра", 54, UiTheme.TEXT, true))
	var text := UiTheme.make_label(Tr.t("Глубина %d м. Глубже шахты нет: дальше только бесконечный спуск. Откройте журнал → «Планета»: «Новая планета» даст звёздную пыль и новые улучшения.") % Biomes.depth_m(state.total_earned, state.planet_scale()), 30, UiTheme.MUTE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(text)
	var go_on := UiTheme.make_button("Продолжить", true, 34)
	go_on.pressed.connect(modal.close)
	modal.body.add_child(go_on)
	_ui.add_child(modal)


## «Золотая лихорадка» и «Динамит»: таймеры, подписи, состояние клавиши.
func _update_abilities(delta: float) -> void:
	state.tick_boost(delta)
	var boosted := state.boost_time > 0.0
	_boost_label.visible = boosted
	if boosted:
		var left := int(ceilf(state.boost_time))
		var left_text := ("%d:%02d" % [floori(left / 60.0), left % 60]) if left >= 60 else (Tr.t("%d с") % left)
		_boost_label.text = Tr.t("Золотая лихорадка ×%d · %s") % [int(state.boost_factor), left_text] if state.boost_factor >= ClickerState.BOOST_FACTOR \
				else Tr.t("Золотой запал ×%d · %d с") % [int(state.boost_factor), left]
	if boosted != _boost_shown:
		_boost_shown = boosted
		_coins_label.add_theme_color_override("font_color", UiTheme.BRASS if boosted else UiTheme.TEXT)
	var has_points := state.needs_attention()
	if has_points != _points_shown:
		_points_shown = has_points
		_journal_button.add_theme_color_override("font_color", UiTheme.BRASS if has_points else UiTheme.TEXT)
	if state.diamonds != _diamonds_shown:
		_diamonds_shown = state.diamonds
		_journal_button.text = str(state.diamonds)
	if state.dynamite_stock != _dynamite_shown:
		_dynamite_shown = state.dynamite_stock
		_dynamite_button.text = Tr.t("Динамит") + "\n×%d" % state.dynamite_stock
		_style_dynamite("ember" if state.dynamite_stock > 0 else "dark")


func _style_dynamite(kind: String) -> void:
	UiTheme.style_key(_dynamite_button, kind)
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(_dynamite_button.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 62


## Подобрана находка: журнал, золотой запал, алмазы.
func _on_ore_collected(ore: int) -> void:
	sfx.ore(ore)
	if _stress_active:
		return
	state.collect_find(ore)
	_say_hint("first_ore", "Находка! Руда копится в журнале: каждая веха коллекции даёт постоянный бонус к доходу.")
	if ore == 3:
		_say_hint("first_gold", "Золото запускает «Золотой запал»: ×2 к доходу на несколько секунд, потом пауза.")
	if ore == 4:
		_say_hint("first_diamond", "Алмаз! Это вторая валюта: в журнале («Руда») за неё можно купить «Золотую лихорадку» и динамит.")


func _on_boss_defeated(zone: int) -> void:
	var gems := int(round((2 + zone) * state.boss_reward_factor()))
	state.diamonds += gems
	state.bosses_defeated += 1
	_award_dynamite(2)
	state.save()
	_show_toast(Tr.t("Хранитель побеждён! +%d алмазов") % gems)
	sfx.play("boss_break", -3.0)
	sfx.play("claim", -8.0)
	settings.vibrate(80)


func _on_expedition_start(index: int) -> void:
	if state.start_expedition(index):
		sfx.play("tick", -4.0)
		state.save()


func _on_expedition_claim() -> void:
	var result := state.claim_expedition()
	if result.is_empty():
		return
	state.save()
	sfx.play("claim", -4.0)
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Экспедиция вернулась", 50, UiTheme.TEXT, true))
	modal.body.add_child(UiTheme.make_label(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])), 34, UiTheme.BRASS))
	if int(result["diamonds"]) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Алмазы: +%d") % int(result["diamonds"]), 34, UiTheme.TEXT))
	if int(result["dynamite"]) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Динамит +%d") % int(result["dynamite"]), 34, UiTheme.TEXT))
	var found: Dictionary = result["found"]
	var names := ["Медь", "Железо", "Золото", "Алмаз"]
	for ore in found:
		if int(found[ore]) > 0:
			modal.body.add_child(UiTheme.make_label("%s: +%d" % [Tr.t(names[int(ore) - 1]), int(found[ore])], 28, UiTheme.MUTE))
	var close := UiTheme.make_button("Закрыть", true, 34)
	close.pressed.connect(modal.close)
	modal.body.add_child(close)
	_ui.add_child(modal)


## Реклама за награду: ролик (пока заглушка) и выдача награды по месту.
func _on_ad_requested(placement: String) -> void:
	if state.ad_remaining(placement) > 0.0:
		return
	_ads.request(placement, func() -> void: _grant_ad_reward(placement))


func _grant_ad_reward(placement: String) -> void:
	match placement:
		"offline":
			if _offline_doubled:
				return
			_offline_doubled = true
			state.add_coins(_offline_earned)
			_show_toast(Tr.t("Офлайн-доход ×2: +%s") % NumberFormat.short(_offline_earned))
		"rush":
			state.start_rush(ClickerState.RUSH_LONG_SECONDS)
			_show_toast(Tr.t("Золотая лихорадка ×%d") % int(ClickerState.BOOST_FACTOR))
		"dynamite":
			_award_dynamite(2)
		"diamonds":
			var gems := state.ad_diamonds()
			state.diamonds += gems
			_show_toast(Tr.t("Алмазы: +%d") % gems)
		"expedition":
			state.expedition_end -= 3600.0
			_show_toast(Tr.t("Поход ускорен на 1 час"))
	sfx.play("claim", -4.0)
	settings.vibrate(30)
	state.save()
	_refresh()
	if _journal.visible:
		_journal.rebuild()


func _on_achievement_claim_all() -> void:
	var count := 0
	for achievement in Retention.ACHIEVEMENTS:
		if not state.claim_achievement(achievement).is_empty():
			count += 1
	if count > 0:
		state.save()
		sfx.play("claim", -4.0)
		settings.vibrate(30)
		_show_toast(Tr.t("Наград получено") + ": %d" % count)


func _on_achievement_claim(id: String) -> void:
	for achievement in Retention.ACHIEVEMENTS:
		if str(achievement["id"]) == id:
			if state.claim_achievement(achievement).is_empty():
				return
			state.save()
			sfx.play("claim", -4.0)
			settings.vibrate(30)
			_show_toast(Tr.t("Награда получена") + ": " + Tr.t(str(achievement["name"])))
			return


## Ежедневная награда: семь дней по кругу, серия обрывается, если пропустить сутки.
func _show_daily() -> void:
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
				sfx.play("claim", -4.0)
				settings.vibrate(30)
				var parts: Array[String] = []
				if result.has("coins"):
					parts.append("+" + NumberFormat.short(float(result["coins"])))
				if result.has("diamonds"):
					parts.append("+%d" % int(result["diamonds"]))
				if result.has("points"):
					parts.append("+%d " % int(result["points"]) + Tr.t("очко"))
				if int(result.get("dynamite", 0)) > 0:
					parts.append(Tr.t("Динамит +%d") % int(result["dynamite"]))
				_show_toast(Tr.t("Ежедневная награда") + ": " + ", ".join(parts))
			modal.close())
	modal.body.add_child(claim)
	_ui.add_child(modal)


func _on_meta_purchase(id: String) -> void:
	if state.buy_meta(id):
		sfx.play("coin", -5.0)
		settings.vibrate(20)
		state.save()
		_refresh()


## «Новая планета»: окно подтверждения, затем сброс забега, смена оттенка мира и возврат в первую зону.
## На телефонах отступаем от вырезов и системных полос (чёлка, жесты внизу): интерфейс сдвигается в безопасную область.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var view := get_viewport().get_visible_rect().size
	var k := view.y / window.y
	_ui.offset_top = maxf(0.0, safe.position.y * k)
	_ui.offset_bottom = -maxf(0.0, (window.y - safe.end.y) * k)


## Знакомство: Борк рассказывает, что к чему, и предлагает обучение.
func _show_intro() -> void:
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
			_tutorial.start())
	modal.body.add_child(start_button)
	var skip := UiTheme.make_button("Я разберусь сам", false, 28)
	skip.pressed.connect(func() -> void:
			state.tutorial_done = true
			state.save()
			modal.close())
	modal.body.add_child(skip)
	_ui.add_child(modal)


func _format_duration(seconds: float) -> String:
	var total := int(seconds)
	var hours := floori(total / 3600.0)
	var minutes := floori(total / 60.0) % 60
	return (Tr.t("%d ч %d мин") % [hours, minutes]) if hours > 0 else (Tr.t("%d мин") % maxi(1, minutes))


## Окно «пока вас не было»: время, монеты, лимит офлайна и что ждёт в журнале.
func _show_offline() -> Modal:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("С возвращением!", 54, UiTheme.TEXT, true))
	modal.body.add_child(UiTheme.make_label(Tr.t("Вас не было: %s") % _format_duration(state.offline_away), 30, UiTheme.MUTE))
	var income := UiTheme.make_label("+" + NumberFormat.short(_offline_earned), 72, UiTheme.BRASS, true)
	modal.body.add_child(income)
	if state.offline_capped:
		var cap := UiTheme.make_label(Tr.t("Офлайн-доход копится не дольше %s. «Долгая смена» на вкладке «Планета» увеличивает лимит.") % _format_duration(state.offline_cap_seconds()), 24, UiTheme.MUTE)
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
			if not _offline_doubled:
				_on_ad_requested("offline"))
	modal.body.add_child(double)
	modal.body.add_child(ok)
	_ui.add_child(modal)
	return modal


func _show_stats() -> void:
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
	_ui.add_child(modal)


func _on_planet_requested() -> void:
	if not state.planet_ready():
		return
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Новая планета", 54, UiTheme.TEXT, true))
	var next_name := Tr.t(Biomes.planet_name(state.planet + 1))
	var gain_text := UiTheme.make_label(Tr.t("Вы полетите на планету: %s. Звёздной пыли: +%d") % [next_name, state.planet_gain()], 32, UiTheme.BRASS)
	gain_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(gain_text)
	var perk_text := UiTheme.make_label(Tr.t("Особенность планеты") + ": " + Tr.t(Biomes.planet_mod_text(state.planet + 1)), 26, UiTheme.TEXT)
	perk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(perk_text)
	var reset_text := UiTheme.make_label("Сбросятся монеты, улучшения, жилы и глубина. Останутся навыки, коллекция, алмазы, достижения и мета-улучшения.", 28, UiTheme.MUTE)
	reset_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(reset_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	modal.body.add_child(row)
	var cancel := UiTheme.make_button("Отмена", false, 32)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	var ok := UiTheme.make_button("Лететь", true, 32)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
			var gained := state.new_planet()
			if gained <= 0:
				return
			_table.clear_field()
			_earned_batch = 0.0
			_shown_coins = 0.0
			_biome = 0
			_table.set_planet(state.planet)
			_table.set_biome(0)
			_table.celebrate()
			music.play_zone(0)
			_planet_arrival_line()
			_dust.color = Color((Biomes.ACCENTS[0] as Color) * Biomes.planet_tint(state.planet), 0.32)
			state.save()
			_show_toast(Tr.t(Biomes.planet_name(state.planet)) + ": " + Tr.t("звёздной пыли +%d") % gained)
			sfx.play("gong", -2.0)
			settings.vibrate(80)
			_prestige_key = -1
			_afford_mask = -1
			_journal.visible = false
			modal.close())
	row.add_child(ok)
	_ui.add_child(modal)


func _on_skill_purchase(branch: String) -> void:
	if state.buy_skill(branch):
		sfx.play("coin", -5.0)
		settings.vibrate(20)
		state.save()
		_refresh()


func _on_respec() -> void:
	var cost := state.shop_cost("respec")
	if state.diamonds < cost:
		return
	state.diamonds -= cost
	state.respec()
	sfx.play("tick", -4.0)
	state.save()
	_refresh()


func _on_shop_purchase(item: String) -> void:
	var cost := state.shop_cost(item)
	if state.diamonds < cost or not state.shop_available(item):
		return
	match item:
		"golden":
			if not _table.summon_golden():
				_show_toast(Tr.t("Золотая глыба уже на столе"))
				return
			state.diamonds -= cost
		"boss":
			if not _table.summon_boss(_biome):
				_show_toast(Tr.t("Хранитель уже на столе"))
				return
			state.diamonds -= cost
		"expedition_skip":
			state.diamonds -= cost
			state.expedition_end = Time.get_unix_time_from_system()
			_show_toast(Tr.t("Шахтёры вернулись!"))
		"skill_point":
			state.diamonds -= cost
			state.skill_points += 1
			state.skill_points_bought += 1
			_show_toast(Tr.t("Очко навыков +1"))
		"rush":
			if state.rush_remaining() > 0.0:
				return
			state.diamonds -= cost
			state.rush_ready_at = Time.get_unix_time_from_system() + ClickerState.RUSH_COOLDOWN
			state.start_rush(ClickerState.RUSH_LONG_SECONDS)
			_show_toast(Tr.t("Золотая лихорадка ×%d") % int(ClickerState.BOOST_FACTOR))
		"dynamite":
			state.diamonds -= cost
			_award_dynamite(3)
		_:
			if item.begins_with("style_"):
				var style_index := int(item.substr(6))
				state.diamonds -= cost
				state.styles_bought.append(style_index)
				settings.rock_style = style_index
				settings.save()
				settings.apply(get_viewport(), _table)
				_show_toast(Tr.t("Новая порода: ") + Tr.t(Settings.STYLE_NAMES[style_index]))
	sfx.play("coin", -5.0)
	settings.vibrate(20)
	state.save()


## Выдаёт динамит на склад и сообщает об этом (сколько влезло).
func _award_dynamite(amount: int) -> void:
	var added := state.add_dynamite(amount)
	if added > 0:
		_show_toast(Tr.t("Динамит +%d") % added)
	else:
		_show_toast(Tr.t("Склад динамита полон"))
	_dynamite_shown = -1


func _on_dynamite_pressed() -> void:
	if _stress_active:
		return
	if not state.use_dynamite():
		_say_hint("dynamite_empty", "Динамит закончился. Его дают за новые зоны, хранителей, золотые глыбы, походы и награды; можно купить за алмазы в журнале или получить за рекламу.")
		_show_toast(Tr.t("Динамита нет"))
		return
	_say_hint("first_dynamite", "Динамит взрывает всё в воздухе, подбирает находки и платит как за 30 секунд дохода и выбивает из породы руду. Запас ограничен, берегите его для хранителей.")
	_dynamite_shown = -1
	state.save()
	_table.detonate()
	if state.dynamite_spark():
		state.start_mini(6.0)
	sfx.play("boom", -2.0)
	settings.vibrate(60)


func _update_fps(delta: float) -> void:
	_fps_label.visible = settings.show_fps
	_fps_timer += delta
	if _fps_timer >= 0.25 and settings.show_fps:
		_fps_timer = 0.0
		_fps_label.text = "FPS %d  ·  %d" % [int(Engine.get_frames_per_second()), _table.rock_count()]


# ---------- Интерфейс ----------

func _build_ui() -> void:
	for child in _ui.get_children():
		child.queue_free()
	_shown_text = ""
	_afford_mask = -1
	_hint_hiding = false
	_auto_button = null
	_rows.clear()

	var tap_area := Control.new()
	tap_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_area.gui_input.connect(_on_tap_input)
	_ui.add_child(tap_area)

	_fx = FxLayer.new()
	_ui.add_child(_fx)
	_fx.spark_arrived.connect(func() -> void: _bump = minf(1.0, _bump + 0.12))

	_build_atmosphere()
	_build_top()

	_fps_label = UiTheme.make_label("", 22, UiTheme.MUTE)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -240
	_fps_label.offset_right = -28
	_fps_label.offset_top = 98
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(_fps_label)
	_toast = UiTheme.make_label("", 52, UiTheme.TEXT, true)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 420
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)
	_stress_label = UiTheme.make_label("", 34, UiTheme.BRASS, true)
	_stress_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_stress_label.offset_top = 330
	_stress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stress_label.visible = false
	_ui.add_child(_stress_label)

	_hint = UiTheme.make_label("Касайтесь стола или жмите «Обвал»", 30, Color(UiTheme.MUTE, 0.8))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -PANEL_HEIGHT - 70
	_hint.offset_bottom = -PANEL_HEIGHT - 20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_hint)

	# Борк рисуется позади нижней панели (добавлен до неё), чтобы выглядывать из-за её кромки
	_peek = CompanionPeek.new()
	_peek.panel_height = PANEL_HEIGHT
	_ui.add_child(_peek)
	_build_panel()
	_build_tutorial()
	_tutorial.peek = _peek
	_tutorial.panel_height = PANEL_HEIGHT
	_hint_card = HintCard.new()
	_hint_card.peek = _peek
	_hint_card.panel_height = PANEL_HEIGHT
	_ui.add_child(_hint_card)

	_journal = JournalScreen.new()
	_ui.add_child(_journal)
	_journal.setup(state)
	_journal.purchase.connect(_on_shop_purchase)
	_journal.skill_purchase.connect(_on_skill_purchase)
	_journal.meta_purchase.connect(_on_meta_purchase)
	_journal.planet_requested.connect(_on_planet_requested)
	_journal.respec_requested.connect(_on_respec)
	_journal.expedition_start.connect(_on_expedition_start)
	_journal.expedition_claim.connect(_on_expedition_claim)
	_journal.achievement_claim.connect(_on_achievement_claim)
	_journal.achievement_claim_all.connect(_on_achievement_claim_all)
	_journal.ad_requested.connect(_on_ad_requested)
	_settings_screen = SettingsScreen.new()
	_ui.add_child(_settings_screen)
	_settings_screen.setup(settings, _table, state)
	_settings_screen.language_changed.connect(_on_language_changed)
	_settings_screen.reset_requested.connect(_save_dialogs.reset_progress)
	_settings_screen.export_requested.connect(_save_dialogs.export_code)
	_settings_screen.import_requested.connect(_save_dialogs.import_code)
	_settings_screen.stress_requested.connect(_start_stress)
	_settings_screen.hints_reset_requested.connect(func() -> void:
			state.hints_seen.clear()
			_show_toast(Tr.t("Подсказки включены снова")))
	_settings_screen.stats_requested.connect(_show_stats)
	_settings_screen.tutorial_requested.connect(func() -> void:
			state.tutorial_done = false
			_tutorial.start())
	_settings_screen.settings_changed.connect(func() -> void: _fps_label.visible = settings.show_fps)
	_refresh()


## Атмосфера поверх фона: плывущая пыль цвета зоны и затемнение сверху, чтобы счётчик читался на любом фоне.
func _build_atmosphere() -> void:
	var scrim_gradient := Gradient.new()
	scrim_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	scrim_gradient.colors = PackedColorArray([Color(UiTheme.BG, 0.72), Color(UiTheme.BG, 0.0)])
	var scrim_texture := GradientTexture2D.new()
	scrim_texture.gradient = scrim_gradient
	scrim_texture.fill_from = Vector2(0.0, 0.0)
	scrim_texture.fill_to = Vector2(0.0, 1.0)
	scrim_texture.width = 4
	scrim_texture.height = 128
	var scrim := TextureRect.new()
	scrim.texture = scrim_texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	scrim.offset_bottom = 460
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(scrim)
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(540, 1300)
	_dust.amount = 36
	_dust.lifetime = 14.0
	_dust.preprocess = 14.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(560, 30)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 28.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 14.0
	_dust.initial_velocity_max = 34.0
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 5.0
	_dust.color = Color((Biomes.ACCENTS[_biome] as Color) * Biomes.planet_tint(state.planet), 0.32)
	_ui.add_child(_dust)


func _build_top() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_ui.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	_coin_icon = Icon.new().setup("coin", UiTheme.BRASS, 72)
	top.add_child(_coin_icon)
	_coins_label = UiTheme.make_label("0", 96, UiTheme.TEXT, true)
	_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_coins_label)
	_journal_button = UiTheme.make_button("0", false, 28)
	_journal_button.custom_minimum_size = Vector2(150, 64)
	_journal_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_journal_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var journal_icon := Icon.new().setup("journal", UiTheme.MUTE, 34)
	journal_icon.position = Vector2(12, 15)
	_journal_button.add_child(journal_icon)
	_journal_button.pressed.connect(func() -> void:
			_journal.open()
			_say_hint("journal_first", "Походы идут по реальному времени, даже пока игра закрыта: отправьте шахтёров и возвращайтесь за добычей."))
	top.add_child(_journal_button)
	var gear := UiTheme.icon_button("gear", UiTheme.MUTE, 36, Vector2(72, 64))
	gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear.pressed.connect(func() -> void: _settings_screen.open())
	top.add_child(gear)

	var sub_margin := MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_left", 90)
	sub_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sub_margin)
	var sub := VBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_margin.add_child(sub)
	_rate_label = UiTheme.make_label("", 30, UiTheme.MUTE)
	sub.add_child(_rate_label)
	_message_label = UiTheme.make_label("", 28, UiTheme.BRASS)
	sub.add_child(_message_label)
	_boost_label = UiTheme.make_label("", 30, UiTheme.BRASS, true)
	_boost_label.visible = false
	sub.add_child(_boost_label)
	var depth_row := HBoxContainer.new()
	depth_row.add_theme_constant_override("separation", 16)
	depth_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(depth_row)
	_depth_label = UiTheme.make_label("", 28, UiTheme.TEXT)
	depth_row.add_child(_depth_label)
	_depth_bar = UiTheme.make_bar(0.0, UiTheme.BRASS, 10)
	_depth_bar.custom_minimum_size = Vector2(220, 10)
	_depth_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	depth_row.add_child(_depth_bar)
	var depth_spacer := Control.new()
	depth_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depth_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_row.add_child(depth_spacer)
	_prestige_button = UiTheme.make_key("Новая шахта", 24, "dark")
	_prestige_button.custom_minimum_size = Vector2(0, 60)
	_prestige_button.visible = false
	_prestige_button.pressed.connect(_on_prestige_pressed)
	depth_row.add_child(_prestige_button)
	_prestige_key = -1


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.BG
	style.border_width_top = 1
	style.border_color = UiTheme.LINE_STRONG
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	# бросок: «Авто» и большая клавиша
	_throw_row = HBoxContainer.new()
	_throw_row.add_theme_constant_override("separation", 14)
	column.add_child(_throw_row)
	_make_auto_button()
	_throw_button = UiTheme.make_key("Обвал", 62, "brass")
	_throw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_throw_button.custom_minimum_size = Vector2(0, 190)
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(_throw_button.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 100
	var cube := Icon.new().setup("rock", UiTheme.DARK_ON_BRASS, 72)
	cube.position = Vector2(40, 59)
	_throw_button.add_child(cube)
	_throw_button.pressed.connect(_on_throw_pressed)
	_throw_row.add_child(_throw_button)
	_dynamite_button = UiTheme.make_key("Динамит", 30, "ember")
	_dynamite_button.custom_minimum_size = Vector2(230, 190)
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(_dynamite_button.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 62
	var fuse := Icon.new().setup("dynamite", UiTheme.TEXT, 52)
	fuse.position = Vector2(14, 69)
	_dynamite_button.add_child(fuse)
	_dynamite_button.pressed.connect(_on_dynamite_pressed)
	_throw_row.add_child(_dynamite_button)
	_dynamite_shown = -1
	_diamonds_shown = -1

	_upgrades_button = UiTheme.make_key("Улучшения", 40, "felt")
	_upgrades_button.custom_minimum_size = Vector2(0, 110)
	_upgrades_button.pressed.connect(_toggle_upgrades)
	column.add_child(_upgrades_button)
	_build_upgrades_sheet()


## Меню улучшений: выезжает над нижней панелью (панель с «Обвалом» остаётся доступной), закрывается той же кнопкой.
func _build_upgrades_sheet() -> void:
	_upgrades_sheet = PanelContainer.new()
	_upgrades_sheet.anchor_left = 0.0
	_upgrades_sheet.anchor_right = 1.0
	_upgrades_sheet.anchor_top = 1.0
	_upgrades_sheet.anchor_bottom = 1.0
	_upgrades_sheet.offset_left = 0.0
	_upgrades_sheet.offset_right = 0.0
	_upgrades_sheet.offset_bottom = -PANEL_HEIGHT
	_upgrades_sheet.offset_top = _upgrades_sheet.offset_bottom - 100.0
	_upgrades_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	_upgrades_sheet.add_theme_stylebox_override("panel", style)
	_upgrades_sheet.visible = false
	_sheet_open = false
	_sheet_slide = 0.0
	if _sheet_tween != null:
		_sheet_tween.kill()
	_upgrades_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_upgrades_sheet)
	# лист рисуется под нижней панелью: при выезде он выходит из-за неё, а не наезжает сверху
	_ui.move_child(_upgrades_sheet, _throw_row.get_parent().get_parent().get_index())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_upgrades_sheet.add_child(column)
	column.add_child(_make_buy_modes())
	_autobuy_button = UiTheme.make_key("", 24, "dark")
	_autobuy_button.custom_minimum_size.y = 60
	_autobuy_button.pressed.connect(func() -> void:
			state.autobuy_on = not state.autobuy_on
			state.save()
			sfx.play("tick", -6.0)
			_refresh())
	column.add_child(_autobuy_button)
	for key in ClickerState.ORDER:
		column.add_child(_make_row(key))


func _toggle_upgrades() -> void:
	_sheet_open = not _sheet_open
	_slide_sheet(_sheet_open)
	sfx.play("tick", -6.0)
	_afford_mask = -1
	_refresh()


## Меню улучшений выезжает снизу из-за нижней панели и уезжает обратно. Двигаем оба отступа сразу: высота листа не меняется.
func _slide_sheet(open: bool) -> void:
	if _sheet_tween != null:
		_sheet_tween.kill()
	var height := _upgrades_sheet.get_combined_minimum_size().y
	_hint_card.set_lift(height if open else 0.0)      # подсказка Борка не прячется за открытым меню
	var from := _sheet_slide if not open else height + 40.0
	if open:
		_upgrades_sheet.visible = true
		_set_sheet_slide(from)
	_sheet_tween = create_tween()
	_sheet_tween.tween_method(_set_sheet_slide, from, 0.0 if open else height + 40.0, 0.28 if open else 0.2) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if not open:
		_sheet_tween.tween_callback(func() -> void: _upgrades_sheet.visible = false)


var _sheet_slide := 0.0


## Сдвиг листа вниз от своего места на slide пикселей (0 — на месте).
func _set_sheet_slide(slide: float) -> void:
	_sheet_slide = slide
	var height := _upgrades_sheet.get_combined_minimum_size().y
	_upgrades_sheet.offset_bottom = -PANEL_HEIGHT + slide
	_upgrades_sheet.offset_top = _upgrades_sheet.offset_bottom - height
	_upgrades_sheet.modulate.a = clampf(1.0 - slide / (height + 40.0) * 0.8, 0.0, 1.0)


## Автопокупка из мета-улучшения «Автоснабжение»: раз в несколько секунд берёт самое дешёвое улучшение.
func _update_autobuy(delta: float) -> void:
	var interval := state.autobuy_interval()
	if interval <= 0.0 or not state.autobuy_on:
		return
	_autobuy_time += delta
	if _autobuy_time < interval:
		return
	_autobuy_time = 0.0
	if state.autobuy_step() != "":
		sfx.play("tick", -12.0)
		_refresh()


## Сколько уровней купит нажатие в текущем режиме (в «Макс» — сколько хватает монет, но не меньше одного).
func _buy_count(key: String) -> int:
	var mode: int = Settings.BUY_MODES[settings.buy_mode]
	return maxi(1, state.max_affordable(key)) if mode == 0 else mode


## Ряд «×1 ×5 ×10 ×100 Макс» над улучшениями.
func _make_buy_modes() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_mode_buttons.clear()
	for i in Settings.BUY_MODES.size():
		var mode: int = Settings.BUY_MODES[i]
		var button := UiTheme.make_key("Макс" if mode == 0 else "×%d" % mode, 26, "brass" if i == settings.buy_mode else "dark")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
		button.pressed.connect(func() -> void: _set_buy_mode(i))
		row.add_child(button)
		_mode_buttons.append(button)
	return row


func _set_buy_mode(index: int) -> void:
	settings.buy_mode = index
	settings.save()
	sfx.play("tick", -6.0)
	for i in _mode_buttons.size():
		UiTheme.style_key(_mode_buttons[i], "brass" if i == index else "dark")
	_afford_mask = -1
	_refresh()


## Клавиша «Авто»: включена — глыбы падают сами (зелёная), выключена — тёмная.
func _make_auto_button() -> void:
	if _auto_button != null:
		_auto_button.queue_free()
	var text := "Авто: вкл" if state.auto_throw else "Авто: выкл"
	_auto_button = UiTheme.make_key(text, 26, "felt" if state.auto_throw else "dark")
	_auto_button.custom_minimum_size = Vector2(170, 190)
	_auto_button.pressed.connect(func() -> void:
			state.auto_throw = not state.auto_throw
			_table.auto_throw = state.auto_throw
			state.save()
			sfx.play("tick", -6.0)
			settings.vibrate(10)
			_make_auto_button())
	_throw_row.add_child(_auto_button)
	_throw_row.move_child(_auto_button, 0)


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
			if state.buy_n(key, _buy_count(key)) > 0:
				state.save()
				sfx.play("coin", -6.0)
				settings.vibrate(20)
				_refresh()
				_pulse(button)
				_tutorial.notify("buy_" + key))
	row.add_child(button)
	_rows[key] = {"level": level_label, "effect": effect, "button": button, "coin": coin}
	return card


## Короткий «щелчок» кнопки при покупке.
func _pulse(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.06)
	tween.tween_property(button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var rate_text := Tr.t("+%s в секунду") % NumberFormat.short(state.income_per_second())
	if state.veins > 0:
		rate_text += "  ·  " + Tr.t("Жилы %d (×%.1f)") % [state.veins, state.vein_multiplier()]
	_rate_label.text = rate_text
	_throw_button.text = Tr.t("Обвал") + " ×%d" % state.rocks_per_throw()
	var ready_count := 0
	for upgrade_key in ClickerState.ORDER:
		if state.coins >= state.cost_for(upgrade_key, _buy_count(upgrade_key)):
			ready_count += 1
	if _sheet_open:
		_upgrades_button.text = Tr.t("Закрыть")
	else:
		_upgrades_button.text = Tr.t("Улучшения") + ((" · %d" % ready_count) if ready_count > 0 else "")
	UiTheme.style_key(_upgrades_button, "brass" if ready_count > 0 and not _sheet_open else "felt")
	_autobuy_button.visible = state.autobuy_interval() > 0.0
	_autobuy_button.text = Tr.t("Автопокупка: вкл") if state.autobuy_on else Tr.t("Автопокупка: выкл")
	UiTheme.style_key(_autobuy_button, "felt" if state.autobuy_on else "dark")
	for key in ClickerState.ORDER:
		var row: Dictionary = _rows[key]
		var count := _buy_count(key)
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


## Текущий эффект и то, что даст следующий уровень.
func _effect_text(key: String, count: int = 1) -> String:
	var level: int = state.levels[key]
	var next := level + count
	match key:
		"rain":
			return Tr.t("%.1f → %.1f глыб в секунду") % [1.0 + 0.8 * level, 1.0 + 0.8 * next]
		"tap":
			return Tr.t("%d → %d глыб за обвал") % [1 + level, 1 + next]
		"faces":
			return Tr.t("ценность руды 1–%d → 1–%d") % [6 + 2 * level, 6 + 2 * next]
	return Tr.t("×%.2f → ×%.2f ко всему") % [pow(1.5, level), pow(1.5, next)]


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_time = 6.0


# ---------- Ввод и настройки ----------

func _on_throw_pressed() -> void:
	_tutorial.notify("throw")
	_table.throw_now()
	sfx.play("tick", -6.0)
	settings.vibrate(12)
	_hide_hint()


## Клавиши на компьютере: пробел — обвал, 1–4 — улучшения, B — режим покупки, A — «Авто».
func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if _journal.visible or _settings_screen.visible:
		return
	for child in _ui.get_children():
		if child is Modal:
			return
	match key_event.keycode:
		KEY_SPACE:
			_on_throw_pressed()
		KEY_U:
			_toggle_upgrades()
		KEY_B:
			_set_buy_mode((settings.buy_mode + 1) % Settings.BUY_MODES.size())
		KEY_A:
			if _auto_button != null:
				_auto_button.pressed.emit()
		KEY_1, KEY_2, KEY_3, KEY_4:
			var key: String = ClickerState.ORDER[key_event.keycode - KEY_1]
			(_rows[key]["button"] as Button).pressed.emit()


func _on_tap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_table.tap(event.position)
		_tutorial.notify("tap")
		_fx.ripple(event.position)
		settings.vibrate(8)
		_hide_hint()


func _hide_hint() -> void:
	if not _hint_hiding:
		_hint_hiding = true
		create_tween().tween_property(_hint, "modulate:a", 0.0, 0.6)


func _on_language_changed() -> void:
	Tr.set_language(settings.language)
	_build_ui()
	if not state.tutorial_done:
		_tutorial.start()
	_settings_screen.open()
