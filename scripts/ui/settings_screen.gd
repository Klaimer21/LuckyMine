class_name SettingsScreen
extends Control
## Настройки по разделам: язык; графика; звук и вибрация; внешний вид (стиль кубиков); сброс прогресса.

signal back_pressed
signal language_changed
signal reset_requested
signal export_requested
signal import_requested
signal settings_changed
signal stress_requested
signal tutorial_requested
signal stats_requested
signal help_requested
signal hints_reset_requested
signal cloud_sign_in_requested
signal cloud_sync_requested

var settings: Settings
var table: FieldTable
var cloud: CloudSave                     # облачное сохранение (null или недоступно: показывается перенос кодом)
var state: ClickerState
var _content: VBoxContainer


func setup(p_settings: Settings, p_table: FieldTable, p_state: ClickerState = null) -> void:
	settings = p_settings
	table = p_table
	state = p_state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.make_background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UiTheme.SPACE_L)
	scroll.add_child(_content)
	visible = false
	rebuild()


func open() -> void:
	var was_visible := visible
	visible = true
	if not was_visible:
		UiTheme.fade_in(self)
	rebuild()


func rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_content.add_child(header)
	var back := UiTheme.icon_button("back", UiTheme.TEXT, 40, Vector2(84, 84))
	back.pressed.connect(func() -> void:
			visible = false
			back_pressed.emit())
	header.add_child(back)
	header.add_child(UiTheme.make_label("Настройки", 60, UiTheme.TEXT, true))

	var language_options: Array = []
	var language_index := 0
	for i in Tr.LANGUAGES.size():
		language_options.append(Tr.LANGUAGES[i][1])
		if Tr.LANGUAGES[i][0] == settings.language:
			language_index = i
	_add_choice("Язык", language_options, language_index, false, func(i: int) -> void:
			settings.language = Tr.LANGUAGES[i][0]
			_changed()
			language_changed.emit())

	_add_section("Графика")
	_add_choice("Качество графики", Settings.QUALITY_NAMES, settings.quality, true, func(i: int) -> void:
			settings.quality = i
			_changed())
	var quality_hint := UiTheme.make_label("Качество меняет, сколько глыб, крошки и руды рисуется сразу: на слабом телефоне ставьте низкое.", 24, UiTheme.MUTE)
	quality_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(quality_hint)
	var fps_options: Array = []
	var fps_index := 1
	for i in Settings.FPS_OPTIONS.size():
		fps_options.append("%d" % Settings.FPS_OPTIONS[i])
		if Settings.FPS_OPTIONS[i] == settings.fps_cap:
			fps_index = i
	_add_choice("Частота кадров (FPS)", fps_options, fps_index, false, func(i: int) -> void:
			settings.fps_cap = Settings.FPS_OPTIONS[i]
			_changed())
	var fps_hint := UiTheme.make_label("Больше кадров — плавнее, но быстрее садится батарея.", 24, UiTheme.MUTE)
	fps_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(fps_hint)

	_add_toggle("Не гасить экран", settings.keep_awake, func(on: bool) -> void:
			settings.keep_awake = on
			_changed())
	_add_toggle("Показывать FPS", settings.show_fps, func(on: bool) -> void:
			settings.show_fps = on
			_changed())

	var stats_button := UiTheme.make_button("Статистика", false, 30)
	stats_button.pressed.connect(func() -> void: stats_requested.emit())
	_content.add_child(stats_button)
	var help_button := UiTheme.make_button("Помощь", false, 30)
	help_button.pressed.connect(func() -> void: help_requested.emit())
	_content.add_child(help_button)
	var tutorial_button := UiTheme.make_button("Показать обучение", false, 30)
	tutorial_button.pressed.connect(func() -> void:
			visible = false
			tutorial_requested.emit())
	_content.add_child(tutorial_button)
	var hints_button := UiTheme.make_button("Сбросить подсказки", false, 30)
	hints_button.pressed.connect(func() -> void:
			hints_reset_requested.emit())
	_content.add_child(hints_button)
	var stress := UiTheme.make_button("Тест нагрузки (15 с)", false, 30)
	stress.pressed.connect(func() -> void:
			visible = false
			stress_requested.emit())
	_content.add_child(stress)
	var stress_hint := UiTheme.make_label("Сыплет максимум глыб для выбранного качества и показывает FPS. Монеты за тест не начисляются.", 24, UiTheme.MUTE)
	stress_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(stress_hint)

	_add_section("Звук и вибрация")
	_add_toggle("Звук", settings.sound_on, func(on: bool) -> void:
			settings.sound_on = on
			_changed())
	_add_slider("Громкость", settings.volume, func(value: float) -> void:
			settings.volume = value
			_changed())
	_add_slider("Громкость музыки", settings.music_volume, func(value: float) -> void:
			settings.music_volume = value
			_changed())
	_add_slider("Громкость эффектов", settings.sfx_volume, func(value: float) -> void:
			settings.sfx_volume = value
			_changed())
	_add_toggle("Вибрация", settings.vibration_on, func(on: bool) -> void:
			settings.vibration_on = on
			_changed())

	_add_section("Внешний вид")
	var locked: Array = []
	for i in Settings.STYLE_NAMES.size():
		locked.append(state != null and not state.style_unlocked(i))
	_add_choice("Порода", Settings.STYLE_NAMES, settings.rock_style, true, func(i: int) -> void:
			settings.rock_style = i
			_changed(), locked)
	var styles_hint := UiTheme.make_label("Новые породы: награды за достижения и покупка за алмазы в журнале.", 24, UiTheme.MUTE)
	styles_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(styles_hint)
	_add_choice("Сезон", Seasons.CHOICE_NAMES, maxi(0, Seasons.CHOICES.find(settings.season)), true, func(i: int) -> void:
			settings.season = Seasons.CHOICES[i]
			_changed())
	_add_toggle("Числа при ударе", settings.popups, func(on: bool) -> void:
			settings.popups = on
			_changed())
	_add_toggle("Меньше эффектов", settings.reduce_motion, func(on: bool) -> void:
			settings.reduce_motion = on
			_changed())
	var motion_note := UiTheme.make_text("Без тряски камеры, вспышек и паузы кадра.", 28, UiTheme.MUTE)
	_content.add_child(motion_note)

	if CloudSave.available():
		_build_cloud_section()
	else:
		_build_code_section()

	_content.add_child(UiTheme.hairline())
	var reset := UiTheme.make_button("Сбросить прогресс", false, 30)
	reset.pressed.connect(func() -> void: reset_requested.emit())
	_content.add_child(reset)
	_content.add_child(UiTheme.make_label(Tr.t("LuckyMine · версия %s") % str(ProjectSettings.get_setting("application/config/version", "0")), 24, UiTheme.MUTE))


## Облако (Android): вход в Google Play Игры, синхронизация, выключатель.
func _build_cloud_section() -> void:
	_add_section("Облачное сохранение")
	var note := UiTheme.make_label("Прогресс хранится в вашем аккаунте Google Play Игры: он не потеряется при смене телефона, а переслать его другому нельзя.", 24, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)
	_add_toggle("Облачное сохранение", settings.cloud_enabled, func(on: bool) -> void:
			settings.cloud_enabled = on
			_changed())
	var status := "Не выполнен вход"
	if cloud != null and cloud.signed_in:
		status = "Вход выполнен"
	_content.add_child(UiTheme.make_label(Tr.t("Google Play Игры") + ": " + Tr.t(status), 28, UiTheme.BRASS if cloud != null and cloud.signed_in else UiTheme.MUTE))
	if settings.cloud_last_sync > 0.0:
		var when := Time.get_datetime_dict_from_unix_time(int(settings.cloud_last_sync + Time.get_time_zone_from_system()["bias"] * 60.0))
		_content.add_child(UiTheme.make_label(Tr.t("Последняя запись") + ": %02d.%02d %02d:%02d" % [when["day"], when["month"], when["hour"], when["minute"]], 24, UiTheme.MUTE))
	if cloud != null and not cloud.signed_in:
		var sign := UiTheme.make_button("Войти в Google Play Игры", true, 30)
		sign.pressed.connect(func() -> void: cloud_sign_in_requested.emit())
		_content.add_child(sign)
	elif cloud != null:
		var sync := UiTheme.make_button("Синхронизировать сейчас", false, 30)
		sync.pressed.connect(func() -> void: cloud_sync_requested.emit())
		_content.add_child(sync)


## Перенос кодом (ПК и устройства без облака).
func _build_code_section() -> void:
	_add_section("Перенос прогресса")
	var transfer_note := UiTheme.make_label("Код хранит весь прогресс: перенесите игру на другое устройство. Он действует час и вводится один раз, покупки не переносятся. Не показывайте его другим.", 24, UiTheme.MUTE)
	transfer_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(transfer_note)
	var export_button := UiTheme.make_button("Скопировать код сохранения", false, 30)
	export_button.pressed.connect(func() -> void: export_requested.emit())
	_content.add_child(export_button)
	var import_button := UiTheme.make_button("Вставить код сохранения", false, 30)
	import_button.pressed.connect(func() -> void: import_requested.emit())
	_content.add_child(import_button)


## Заголовок раздела настроек: линия и название латунью.
func _add_section(title: String) -> void:
	_content.add_child(UiTheme.hairline())
	_content.add_child(UiTheme.make_label(title, 38, UiTheme.BRASS, true))


## Строка с ползунком 0…1.
func _add_slider(title: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_L)
	_content.add_child(row)
	var label := UiTheme.make_label(title, 30, UiTheme.TEXT)
	label.custom_minimum_size.x = 380
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 96            # вся высота ловит палец, а не только тонкая линия
	UiTheme.style_slider(slider)
	slider.value_changed.connect(func(v: float) -> void: on_change.call(v))
	row.add_child(slider)


func _changed() -> void:
	settings.apply(get_viewport(), table)
	settings.save()
	settings_changed.emit()


## Строка выбора из нескольких вариантов (кнопки в ряд, активная подсвечена латунью).
func _add_choice(title: String, options: Array, current: int, translate: bool, on_pick: Callable, locked: Array = []) -> void:
	_content.add_child(UiTheme.make_label(title, 32, UiTheme.TEXT))
	# много вариантов (породы) переносятся на следующую строку, иначе строка шире экрана и ломает весь экран
	var row: Container
	if options.size() > 5:
		row = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
	else:
		row = HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTheme.SPACE_S)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)
	for i in options.size():
		var button := UiTheme.make_button(Tr.t(str(options[i])) if translate else str(options[i]), i == current, 24)
		button.clip_text = options.size() <= 5
		if options.size() <= 5:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			button.custom_minimum_size.x = 190
		button.custom_minimum_size.y = 76
		button.disabled = i < locked.size() and bool(locked[i])
		button.pressed.connect(func() -> void:
				on_pick.call(i)
				rebuild())
		row.add_child(button)


func _add_toggle(title: String, value: bool, on_toggle: Callable) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var label := UiTheme.make_label(title, 32, UiTheme.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var button := UiTheme.make_button("Вкл" if value else "Выкл", value, 28)
	button.custom_minimum_size = Vector2(170, 76)
	button.pressed.connect(func() -> void:
			on_toggle.call(not value)
			rebuild())
	row.add_child(button)
