extends SceneTree
## Проверка вёрстки без эталонных картинок: открывает экраны и окна на трёх языках и ищет то, что обычно ломается:
## текст, не влезающий в кнопку или подпись; элементы за краем экрана; налезающие друг на друга кнопки;
## слишком мелкие кнопки. Запуск (нужно окно): godot --path . --script res://tests/ui_lint.gd
## FAIL — сломано (код выхода 1), WARN — на усмотрение. Игра пишет сохранение: запускать на копии профиля.

const CANVAS := Vector2(1080, 1920)
const MIN_TOUCH := 72.0                  # холст 1080 px ≈ 360 dp: 72 px ≈ 24 dp; кнопки ниже — предупреждение

var _main: Node
var _fails := 0
var _warns := 0
var _seen := {}


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _close_modals() -> void:
	for modal in _main.find_children("*", "Modal", true, false):
		modal.close()
	await _wait(0.3)


func _run() -> void:
	await _wait(0.5)
	var state: ClickerState = _main.state
	state.tutorial_done = true
	state.daily_day = ClickerState.today()
	state.offline_away = 0.0
	state.add_coins(5.0e5)
	state.diamonds = 123
	state.skill_points = 7
	state.stardust = 20
	for language in ["ru", "en", "zh"]:
		_main.settings.language = language
		_main._on_language_changed()
		_main._settings_screen.visible = false
		await _wait(0.4)
		await _screens(language)
	print("LINT DONE fails=%d warns=%d" % [_fails, _warns])
	quit(1 if _fails > 0 else 0)


func _screens(language: String) -> void:
	var state: ClickerState = _main.state
	await _check(language, "главный экран")
	_main._sheet.toggle()
	await _wait(0.6)
	await _check(language, "меню улучшений")
	_main._sheet.toggle()
	await _wait(0.5)

	state.start_expedition(1)
	for tab in 6:
		_main._journal._tab = tab
		_main._journal.open()
		await _wait(0.4)
		await _check(language, "журнал, вкладка %d" % tab)
	_main._journal.visible = false
	_main._settings_screen.open()
	await _wait(0.4)
	await _check(language, "настройки")
	_main._settings_screen.visible = false
	state.expedition_type = -1

	var dialogs := {
		"ежедневная награда": func() -> void: _main._info.show_daily(),
		"знакомство": func() -> void: _main._info.show_intro(),
		"офлайн": func() -> void: _main._info.show_offline(123456.0),
		"статистика": func() -> void: _main._info.show_stats(),
		"сброс прогресса": func() -> void: _main._save_dialogs.reset_progress(),
		"импорт кода": func() -> void: _main._save_dialogs.import_code(),
		"новая шахта": func() -> void: _main._progression.show_prestige(),
	}
	for name in dialogs:
		(dialogs[name] as Callable).call()
		await _wait(0.4)
		await _check(language, "окно: " + name)
		await _close_modals()


func _check(language: String, screen: String) -> void:
	await _wait(0.1)
	# проверяем только то, что игрок видит сверху: окно, иначе журнал или настройки, иначе главный экран
	var scope: Node = _top_modal()
	if scope == null and _main._journal.visible:
		scope = _main._journal
	elif scope == null and _main._settings_screen.visible:
		scope = _main._settings_screen
	elif scope == null:
		scope = _main._ui
	_lint(scope, language, screen, scope == _main._ui)


func _top_modal() -> Node:
	var top: Node = null
	for modal in _main.find_children("*", "Modal", true, false):
		if not modal.is_queued_for_deletion():
			top = modal
	return top


func _report(kind: String, language: String, screen: String, what: String, node: Control) -> void:
	var key := "%s|%s|%s|%s" % [kind, language, screen if kind == "FAIL" else "", what]    # предупреждения не повторяем по экранам
	if _seen.has(key):
		return
	_seen[key] = true
	if kind == "FAIL":
		_fails += 1
	else:
		_warns += 1
	print("LINT %s [%s] %s: %s (%s %s)" % [kind, language, screen, what, node.get_class(), node.get_rect()])


func _in_scroll(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _lint(scope: Node, language: String, screen: String, is_main: bool) -> void:
	var buttons: Array[BaseButton] = []
	for node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 1.0 or control.size.y <= 1.0 or control.modulate.a < 0.5:
			continue
		if is_main and (_main._journal.is_ancestor_of(control) or _main._settings_screen.is_ancestor_of(control)):
			continue
		var rect := control.get_global_rect()
		var scrolled := _in_scroll(control)
		var bounded := rect.position.x >= -2.0 and rect.end.x <= CANVAS.x + 2.0 and (scrolled or (rect.position.y >= -2.0 and rect.end.y <= CANVAS.y + 2.0))
		if control is Label:
			var label := control as Label
			if label.text == "":
				continue
			if not bounded:
				_report("FAIL", language, screen, "подпись «%s» выходит за экран" % label.text.left(30), control)
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				if label.get_minimum_size().x > label.size.x + 1.0 and label.clip_text == false and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
					# подпись шире своей области: в контейнерах она раздвигается, поэтому важно только если она вышла за экран/родителя
					var parent_rect := (label.get_parent() as Control).get_global_rect() if label.get_parent() is Control else Rect2(Vector2.ZERO, CANVAS)
					if rect.end.x > parent_rect.end.x + 2.0 and not scrolled:
						_report("FAIL", language, screen, "подпись «%s» шире контейнера" % label.text.left(30), control)
			elif label.get_line_count() > label.get_visible_line_count() and label.get_visible_line_count() > 0:
				_report("FAIL", language, screen, "подпись «%s» обрезана по высоте" % label.text.left(30), control)
		elif control is BaseButton:
			var button := control as BaseButton
			buttons.append(button)
			if not bounded:
				_report("FAIL", language, screen, "кнопка «%s» выходит за экран" % _text_of(button), control)
			if button is Button:
				var shown := button as Button
				if shown.text != "" and _text_clipped(shown):
					_report("FAIL", language, screen, "текст кнопки «%s» не влезает" % shown.text.left(30), control)
			if not button.disabled and control.size.y < MIN_TOUCH and not (button is CheckBox):
				_report("WARN", language, screen, "мелкая кнопка «%s» (%d px)" % [_text_of(button), int(control.size.y)], control)
	# налезающие друг на друга кнопки
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a := buttons[i].get_global_rect()
			var b := buttons[j].get_global_rect()
			var overlap := a.intersection(b)
			if overlap.size.x > 6.0 and overlap.size.y > 6.0:
				_report("FAIL", language, screen, "кнопки «%s» и «%s» налезают друг на друга" % [_text_of(buttons[i]), _text_of(buttons[j])], buttons[i])


func _text_of(button: BaseButton) -> String:
	return (button as Button).text.left(24) if button is Button else button.name


func _text_clipped(button: Button) -> bool:
	var font := button.get_theme_font("font")
	var size := button.get_theme_font_size("font_size")
	var width := 0.0
	for line in button.text.split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var box := button.get_theme_stylebox("normal")
	var margins := box.get_minimum_size().x if box != null else 0.0
	return width + margins > button.size.x + 1.0
