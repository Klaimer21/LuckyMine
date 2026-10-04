extends SceneTree
## Ломаем игру случайными действиями: godot --headless --path . --script res://tests/fuzz_driver.gd -- <seed> <кадров>
## Каждый кадр жмёт случайные кнопки (иногда по два раза подряд), крутит интерфейс и портит состояние;
## каждые 60 кадров проверяет инварианты. Ошибки движка видны в выводе (SCRIPT ERROR), нарушения — строками BUG.
## Игра пишет сохранение: запускать на копии профиля (прогресс затирается).

var _rng := RandomNumberGenerator.new()
var _main: Node
var _frame := 0
var _frames := 3000
var _bugs := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_rng.seed = int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_frames = int(args[1])
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.state.tutorial_done = _rng.randf() < 0.5
	Engine.time_scale = 3.0
	Engine.max_fps = 0                       # без ограничения кадров: прогон идёт быстрее


func _buttons(node: Node, out: Array) -> void:
	if node is BaseButton and node.is_visible_in_tree() and not node.disabled:
		out.append(node)
	for child in node.get_children():
		_buttons(child, out)


func _click(button: BaseButton) -> void:
	button.button_down.emit()
	button.pressed.emit()
	button.button_up.emit()


func _process(_delta: float) -> bool:
	_frame += 1
	if _main == null or not is_instance_valid(_main):
		return false
	for i in _rng.randi_range(1, 4):
		_act()
	if _frame % 60 == 0:
		_check()
	if _frame >= _frames:
		print("DONE frames=%d bugs=%d" % [_frame, _bugs])
		quit()
	return false


func _act() -> void:
	var state: ClickerState = _main.state
	match _rng.randi_range(0, 21):
		0, 1, 2, 3, 4, 5, 6, 7:
			var list: Array = []
			_buttons(root, list)
			if list.is_empty():
				return
			var button: BaseButton = list[_rng.randi() % list.size()]
			_click(button)
			if _rng.randf() < 0.3:
				_click(button)                         # двойное нажатие
			if _rng.randf() < 0.1 and is_instance_valid(button):
				_click(button)
		8:
			_main._sheet.toggle()
			_main._sheet.toggle()
		9:
			_main._on_throw_pressed()
		10:
			_main._on_dynamite_pressed()
		11:
			_main._table.tap(Vector2(_rng.randf_range(0, 1080), _rng.randf_range(0, 1920)))
		12:
			var event := InputEventKey.new()
			event.pressed = true
			event.keycode = [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_U, KEY_D, KEY_A][_rng.randi() % 6]
			Input.parse_input_event(event)
		13:
			var cancel := InputEventAction.new()
			cancel.action = "ui_cancel"
			cancel.pressed = true
			Input.parse_input_event(cancel)
		14:
			state.add_coins(10.0 ** _rng.randf_range(0.0, 40.0))
		15:
			state.diamonds += _rng.randi_range(0, 500)
			state.skill_points += _rng.randi_range(0, 20)
			state.stardust += _rng.randi_range(0, 50)
		16:
			_main.settings.language = ["en", "ru", "zh"][_rng.randi() % 3]
			_main._on_language_changed()
		17:
			state.save()
			var copy := ClickerState.new()
			copy.load_save()
		18:
			_main._table.summon_golden()
			_main._table.summon_boss(_rng.randi_range(0, 6))
		19:
			_main._table.detonate()
		20, 21:
			# прыжки системных часов: вперёд, назад, на годы; потом игра «просыпается» как после офлайна
			var jumps := [60.0, 3600.0, 86400.0, -3600.0, -86400.0 * 3.0, 86400.0 * 365.0, -86400.0 * 365.0]
			ClickerState.clock_offset += jumps[_rng.randi() % jumps.size()]
			if _rng.randf() < 0.4:
				state.save()
				var woke := ClickerState.new()
				woke.load_save()


func _bug(text: String) -> void:
	_bugs += 1
	print("BUG frame=%d: %s" % [_frame, text])


func _finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _check() -> void:
	var s: ClickerState = _main.state
	for pair in [["coins", s.coins], ["total_earned", s.total_earned], ["lifetime_earned", s.lifetime_earned]]:
		if not _finite(float(pair[1])) or float(pair[1]) < 0.0:
			_bug("%s = %s" % [pair[0], pair[1]])
	if s.diamonds < 0 or s.skill_points < 0 or s.stardust < 0 or s.veins < 0:
		_bug("negative currency d=%d sp=%d sd=%d v=%d" % [s.diamonds, s.skill_points, s.stardust, s.veins])
	if s.dynamite_stock < 0 or s.dynamite_stock > s.dynamite_max():
		_bug("dynamite_stock %d (max %d)" % [s.dynamite_stock, s.dynamite_max()])
	for key in s.levels:
		if int(s.levels[key]) < 0:
			_bug("level %s = %s" % [key, s.levels[key]])
	if not _finite(s.income_per_second()) or not _finite(s.multiplier()):
		_bug("income/multiplier not finite: %s %s" % [s.income_per_second(), s.multiplier()])
	if s.expedition_active() and s.expedition_remaining() > float(Retention.EXPEDITIONS[s.expedition_type]["hours"]) * 3600.0:
		_bug("expedition remaining longer than its duration")
	for placement in Ads.PLACEMENTS:
		if s.ad_remaining(placement) > float(Ads.PLACEMENTS[placement]["cooldown"]) + 1.0 and abs(ClickerState.clock_offset) < 86400.0:
			_bug("ad cooldown %s longer than configured: %s" % [placement, s.ad_remaining(placement)])
	var modals := 0
	for node in _main.find_children("*", "Modal", true, false):
		if not node.is_queued_for_deletion():
			modals += 1
	if modals > 6:
		_bug("modal pile: %d" % modals)
