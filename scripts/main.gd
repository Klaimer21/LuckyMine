extends Node
## LuckyMine: рудный стол, шапка с монетами, строки улучшений, шестерёнка настроек.
## Глыбы падают сами, по кнопке «Обвал» и по касанию стола; каждая, разбиваясь, приносит монеты.

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
var _dynamite_button: Button
var _dynamite_shown := -1
var _boost_label: Label
var _boost_shown := false
var _prestige_button: Button
var _prestige_key := -1
var _prestige_hinted := false
var _depth_label: Label
var _depth_bar: ProgressBar
var _biome := 0
var _toast: Label
var _toast_time := 0.0
var _throw_button: Button
var _auto_button: Button
var _settings_screen: SettingsScreen
var _journal: JournalScreen
var _tutorial: Tutorial
var _hint_card: HintCard
var _peek: CompanionPeek
var _journal_button: Button
var _diamonds_shown := -1
var _points_shown := false
var _coins_label: Label
var _coin_icon: Icon
var _rate_label: Label
var _message_label: Label
var _hint: Label
var _hint_hiding := false
var _save_timer := 0.0
var _message_time := 0.0
var _earned_batch := 0.0
var _shown_coins := 0.0
var _shown_text := ""
var _bump := 0.0
var _save_dialogs := SaveDialogs.new()
var _info := InfoDialogs.new()
var _perf := PerfMonitor.new()
var _rewards := Rewards.new()
var _progression := ProgressionDialogs.new()
var _sheet := UpgradesSheet.new()
var _last_tap_frame := -10
var _mouse_finger := -1               # палец, который движок превращает в мышь (-1 — пока нет)
var _last_button_frame := -10
var _last_button: Button
var _last_tap_pos := Vector2.ZERO


func _ready() -> void:
	settings.load_settings()
	Tr.set_language(settings.language)
	UiTheme.install_system_font()
	var offline := state.load_save()
	if not state.style_unlocked(settings.rock_style):
		settings.rock_style = 0
	_shown_coins = state.coins
	_rewards.offline_earned = offline

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
			_hit_stop(0.07)
			state.start_rush(ClickerState.BOOST_SECONDS, false)
			state.golden_caught += 1
			if state.golden_caught % 3 == 0:
				_rewards.award_dynamite(1)
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
			if not _perf.stress_active:
				_earned_batch += payout
			_bump = minf(1.0, _bump + (0.35 if real else 0.15))
			if real:
				state.rocks_broken += 1
				sfx.crack())
	_table.detonated.connect(func(screen_pos: Vector2) -> void: _fx.blast(screen_pos))
	_table.gem_spawned.connect(func(screen_pos: Vector2, ore: int) -> void:
			_fx.glint(screen_pos)
			if ore == 4:
				_hit_stop(0.07))
	_table.collected.connect(func(screen_pos: Vector2, color: Color) -> void: _fx.emit_sparks(screen_pos, color))

	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_save_dialogs.setup(_ui, state, _show_toast)
	_sheet.setup(_ui, state, settings, sfx, PANEL_HEIGHT, _refresh, func(px: float) -> void: _hint_card.set_lift(px),
			func(key: String) -> void: _tutorial.notify("buy_" + key))
	_progression.setup(_ui, state, _table, sfx, music, settings, _show_toast,
			func() -> void:
				_earned_batch = 0.0
				_shown_coins = state.coins
				_prestige_key = -1
				_sheet.reset_affordability()
				_say_hint("after_prestige", "Жилы прибавили доход навсегда. Новые очки навыков тратятся в журнале («Навыки»). Зоны и коллекция остались при вас."),
			func() -> void:
				_earned_batch = 0.0
				_shown_coins = 0.0
				_biome = 0
				_planet_arrival_line()
				_dust.color = Color((Biomes.ACCENTS[0] as Color) * Biomes.planet_tint(state.planet), 0.32)
				_prestige_key = -1
				_sheet.reset_affordability()
				_journal.visible = false)
	_rewards.setup(_ui, state, settings, sfx, _table, get_viewport(), _show_toast, _refresh,
			func() -> void:
				if _journal.visible:
					_journal.rebuild(),
			func() -> void: _dynamite_shown = -1,
			func() -> int: return _biome)
	_perf.setup(_ui, state, settings, _table, get_viewport(), func() -> void:
			_say_hint("low_fps", "Мало кадров в секунду. В настройках можно понизить качество, а «Тест нагрузки» покажет, что тянет устройство."))
	_info.setup(_ui, state, settings, sfx, _show_toast, func() -> void: _tutorial.start(), func() -> void:
			if not _rewards.offline_doubled():
				_rewards.on_ad_requested("offline"))
	_build_ui()
	settings.apply(get_viewport(), _table)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if not state.tutorial_done:
				_info.show_intro())
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if not state.tutorial_done:
				return
			if state.offline_away >= 60.0 and _rewards.offline_earned >= 1.0:
				_info.show_offline(_rewards.offline_earned).closed.connect(func() -> void:
						if state.daily_available():
							_info.show_daily())
			elif state.daily_available():
				_info.show_daily())
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
	_perf.update(delta)
	_update_depth(delta)
	_update_abilities(delta)
	_sheet.update_autobuy(delta)
	_update_prestige_button()
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
	if _sheet.poll_affordable():
		_refresh()


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
	if index != _biome and not _perf.stress_active:
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
	return _sheet.rain_rect()


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
		_info.show_daily()


## Подсказка по требованию: один раз за всю игру (и не во время обучения).
func _say_hint(id: String, text: String) -> void:
	if not state.tutorial_done or _perf.stress_active:
		return
	if state.take_hint(id):
		_hint_card.show_hint(Tr.t(text))


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
		_rewards.award_dynamite(2)
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
		_progression.show_ending()


## Борк встречает на новой планете: название и её особенность (один раз для каждой планеты).
func _planet_arrival_line() -> void:
	if not state.tutorial_done or not state.take_hint("planet_%d" % state.planet):
		return
	_hint_card.show_hint(Tr.t("Мы на планете: %s! Особенность: %s.") % [Tr.t(Biomes.planet_name(state.planet)), Tr.t(Biomes.planet_mod_text(state.planet))])


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
	if _perf.stress_active:
		return
	state.collect_find(ore)
	_say_hint("first_ore", "Находка! Руда копится в журнале: каждая веха коллекции даёт постоянный бонус к доходу.")
	if ore == 3:
		_say_hint("first_gold", "Золото запускает «Золотой запал»: ×2 к доходу на несколько секунд, потом пауза.")
	if ore == 4:
		_say_hint("first_diamond", "Алмаз! Это вторая валюта: в журнале («Руда») за неё можно купить «Золотую лихорадку» и динамит.")


## Короткая «заморозка» кадра на редкой находке: вес событию. Время возвращается по таймеру реального времени.
func _hit_stop(seconds: float) -> void:
	if not settings.hit_stop or _perf.stress_active or Engine.time_scale != 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _on_boss_defeated(zone: int) -> void:
	_hit_stop(0.09)
	var gems := int(round((2 + zone) * state.boss_reward_factor()))
	state.diamonds += gems
	state.bosses_defeated += 1
	_rewards.award_dynamite(2)
	state.save()
	_show_toast(Tr.fmt("Хранитель побеждён! +%d алмазов", [gems]))
	sfx.play("boss_break", -3.0)
	sfx.play("claim", -8.0)
	settings.vibrate(80)


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


func _on_dynamite_pressed() -> void:
	if _perf.stress_active:
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


# ---------- Интерфейс ----------

func _build_ui() -> void:
	for child in _ui.get_children():
		child.queue_free()
	_shown_text = ""
	_sheet.reset_affordability()
	_hint_hiding = false
	_auto_button = null
	_sheet.rows.clear()

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

	_perf.build()
	_toast = UiTheme.make_label("", 52, UiTheme.TEXT, true)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 420
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)

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
	_journal.purchase.connect(_rewards.on_shop_purchase)
	_journal.skill_purchase.connect(_rewards.on_skill_purchase)
	_journal.meta_purchase.connect(_rewards.on_meta_purchase)
	_journal.planet_requested.connect(_progression.show_planet)
	_journal.respec_requested.connect(_rewards.on_respec)
	_journal.expedition_start.connect(_rewards.on_expedition_start)
	_journal.expedition_claim.connect(_rewards.on_expedition_claim)
	_journal.achievement_claim.connect(_rewards.on_achievement_claim)
	_journal.achievement_claim_all.connect(_rewards.on_achievement_claim_all)
	_journal.ad_requested.connect(_rewards.on_ad_requested)
	_settings_screen = SettingsScreen.new()
	_ui.add_child(_settings_screen)
	_settings_screen.setup(settings, _table, state)
	_settings_screen.language_changed.connect(_on_language_changed)
	_settings_screen.reset_requested.connect(_save_dialogs.reset_progress)
	_settings_screen.export_requested.connect(_save_dialogs.export_code)
	_settings_screen.import_requested.connect(_save_dialogs.import_code)
	_settings_screen.stress_requested.connect(_perf.start_stress)
	_settings_screen.hints_reset_requested.connect(func() -> void:
			state.hints_seen.clear()
			_show_toast(Tr.t("Подсказки включены снова")))
	_settings_screen.stats_requested.connect(_info.show_stats)
	_settings_screen.tutorial_requested.connect(func() -> void:
			state.tutorial_done = false
			_tutorial.start())
	_settings_screen.settings_changed.connect(_perf.refresh_fps_visibility)
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
	_journal_button.custom_minimum_size = Vector2(150, 76)
	_journal_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_journal_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var journal_icon := Icon.new().setup("journal", UiTheme.MUTE, 34)
	journal_icon.position = Vector2(12, 15)
	_journal_button.add_child(journal_icon)
	_journal_button.pressed.connect(func() -> void:
			_journal.open()
			_say_hint("journal_first", "Походы идут по реальному времени, даже пока игра закрыта: отправьте шахтёров и возвращайтесь за добычей."))
	top.add_child(_journal_button)
	var gear := UiTheme.icon_button("gear", UiTheme.MUTE, 36, Vector2(76, 76))
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
	_prestige_button.custom_minimum_size = Vector2(0, 72)
	_prestige_button.visible = false
	_prestige_button.pressed.connect(_progression.show_prestige)
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
	_upgrades_button.pressed.connect(_sheet.toggle)
	column.add_child(_upgrades_button)
	_sheet.upgrades_button = _upgrades_button
	_sheet.build(panel)


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


func _refresh() -> void:
	var rate_text := Tr.t("+%s в секунду") % NumberFormat.short(state.income_per_second())
	if state.veins > 0:
		rate_text += "  ·  " + Tr.t("Жилы %d (×%.1f)") % [state.veins, state.vein_multiplier()]
	_rate_label.text = rate_text
	_throw_button.text = Tr.t("Обвал") + " ×%d" % state.rocks_per_throw()
	_sheet.refresh()


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
			_sheet.toggle()
		KEY_B:
			_sheet.set_buy_mode((settings.buy_mode + 1) % Settings.BUY_MODES.size())
		KEY_A:
			if _auto_button != null:
				_auto_button.pressed.emit()
		KEY_1, KEY_2, KEY_3, KEY_4:
			var key: String = ClickerState.ORDER[key_event.keycode - KEY_1]
			(_sheet.rows[key]["button"] as Button).pressed.emit()


## Касание стола мышью (на телефоне — эмуляция от первого пальца, приходит в gui_input).
func _on_tap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_register_tap(event.position)


## Godot превращает в мышь только первый палец (пока он на экране): его касания идут через gui_input. Остальные пальцы
## иначе пропали бы, поэтому по ним тут же роняются глыбы (касание стола) и нажимаются «Обвал» и «Динамит».
func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	if not event.pressed:
		if event.index == _mouse_finger:
			_mouse_finger = -1
		return
	if _mouse_finger == -1:                 # так же выбирает палец для мыши сам движок
		_mouse_finger = event.index
		return
	if _touch_over_table(event.position):
		_register_tap(event.position)
	elif _overlay_free():
		_press_extra(event.position)


## Нажатие кнопки вторым и следующими пальцами.
func _press_extra(pos: Vector2) -> void:
	for button in [_throw_button, _dynamite_button]:
		if button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(pos):
			var frame := Engine.get_process_frames()
			if frame == _last_button_frame and button == _last_button:
				return
			_last_button_frame = frame
			_last_button = button
			button.button_down.emit()
			button.pressed.emit()
			button.button_up.emit()
			return


## Ничто не закрывает игровой экран: ни окно, ни журнал, ни настройки.
func _overlay_free() -> bool:
	if _journal.visible or _settings_screen.visible:
		return false
	for child in _ui.get_children():
		if child is Modal:
			return false
	return true


func _touch_over_table(pos: Vector2) -> bool:
	if _table == null or _journal == null or not _table.screen_rect().has_point(pos) or not _overlay_free():
		return false
	return not (_sheet.sheet != null and _sheet.sheet.visible and _sheet.sheet.get_global_rect().has_point(pos))


## Один тап: бросок, подсказки, рябь. Одно и то же касание, пришедшее и как палец, и как эмулированная мышь, считается один раз.
func _register_tap(pos: Vector2) -> void:
	var frame := Engine.get_process_frames()
	if frame - _last_tap_frame <= 1 and pos.distance_to(_last_tap_pos) < 6.0:
		return
	_last_tap_frame = frame
	_last_tap_pos = pos
	_table.tap(pos)
	_tutorial.notify("tap")
	_fx.ripple(pos)
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
