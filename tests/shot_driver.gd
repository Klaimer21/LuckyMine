extends SceneTree
## Снимает скриншоты интерфейса: godot --path . --script res://tests/shot_driver.gd -- <папка>
## Язык берётся из настроек игры (luckymine_settings.cfg). Запускать с окном (не headless) и на чистом профиле: игра сохраняет прогресс при выходе.

var _t := 0.0
var _step := 0
var _main: Node
var _dir := "."


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = args[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.state.tutorial_done = true
	_main.state.add_coins(2.0e5)
	_main.state.diamonds = 40
	_main.state.daily_day = ClickerState.today()      # без окна ежедневной награды в кадре


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])


func _process(delta: float) -> bool:
	_t += delta
	var plan := [
		[2.9, func() -> void: _main._hint_card.show_hint("Находка! Руда копится в журнале: каждая веха коллекции даёт постоянный бонус к доходу.")],
		[3.0, func() -> void: _shot("1_main")],
		[3.1, func() -> void: _main._toggle_upgrades()],
		[3.2, func() -> void: _shot("2_sheet_mid")],
		[4.2, func() -> void: _shot("3_sheet_open")],
		[4.3, func() -> void: _main._toggle_upgrades()],
		[4.4, func() -> void: _shot("4_sheet_closing")],
		[5.2, func() -> void:
			_main.state.start_expedition(1)
			_main._journal._tab = 2
			_main._journal.open()],
		[6.0, func() -> void: _shot("5_journal_expedition")],
		[6.1, func() -> void:
			_main._journal._tab = 0
			_main._journal.rebuild()],
		[6.6, func() -> void: _shot("6_journal_ore")],
		[6.7, func() -> void:
			_main._journal.visible = false
			_main._settings_screen.open()],
		[7.5, func() -> void: _shot("7_settings")],
		[7.6, func() -> void:
			_main._settings_screen.visible = false
			_main._save_dialogs.reset_progress()],
		[8.4, func() -> void: _shot("8_modal")],
		[8.5, func() -> void: _main._info.show_daily()],
		[9.3, func() -> void: _shot("9_daily")],
		[9.4, func() -> void: _main._info.show_stats()],
		[10.2, func() -> void: _shot("10_stats")],
		[10.3, func() -> void: _main._info.show_offline(123456.0)],
		[11.1, func() -> void: _shot("11_offline")],
		[11.2, func() -> void: _main._info.show_intro()],
		[12.0, func() -> void: _shot("12_intro")],
		[12.1, func() -> void: quit()],
	]
	if _step < plan.size() and _t >= float(plan[_step][0]):
		(plan[_step][1] as Callable).call()
		_step += 1
	return false
