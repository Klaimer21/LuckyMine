extends SceneTree
## Пробует многопальцевые касания через настоящий ввод движка: godot --path . --script res://tests/touch_probe.gd
## (нужно окно: безоконный режим не строит сцену ввода как на устройстве). Печатает, что сработало.

var _main: Node
var _t := 0.0
var _step := 0
var _log := []
var _buttons := 0
var _peak := 0                 # сколько касаний стола засчитано с последнего _begin()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		route = args[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.state.tutorial_done = true
	_main.state.daily_day = ClickerState.today()
	_main.state.auto_throw = false


## Путь доставки события: "input" — через Input (как с устройства, с эмуляцией мыши от касаний), "viewport" — прямо в окно.
var route := "input"


func _send(event: InputEvent) -> void:
	if route == "viewport":
		root.push_input(event)
	else:
		Input.parse_input_event(event)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	_send(event)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = pressed
	_send(event)


func _rocks() -> int:
	return _peak


func _begin() -> void:
	_peak = 0


func _process(delta: float) -> bool:
	_t += delta
	var table_a := Vector2(300, 600)
	var table_b := Vector2(150, 400)
	var table_c := Vector2(400, 500)
	var throw_pos: Vector2 = _main._throw_button.get_global_rect().get_center() * 0.5      # окно 540x960, холст 1080x1920
	var plan := [
		[0.5, func() -> void:
			_main.state.offline_away = 0.0               # без окна «С возвращением», оно закрывает стол
			_main.state.auto_throw = false
			_main._table.auto_throw = false
			_peak = 0
			_main._table.tapped.connect(func(_pos: Vector2) -> void: _peak += 1)
			_main._throw_button.pressed.connect(func() -> void: _buttons += 1)],
		[3.0, func() -> void:
			for modal in _main.find_children("*", "Modal", true, false):
				modal.close()],
		[4.0, func() -> void:
			_log.append(["modals open at start (expect 0)", _main.find_children("*", "Modal", true, false).filter(func(m: Node) -> bool: return not m.is_queued_for_deletion()).size()])
			_begin()],
		[4.1, func() -> void: _mouse(table_a, true)],
		[4.2, func() -> void: _mouse(table_a, false)],
		[6.0, func() -> void: _log.append(["baseline: 1 mouse click (expect 1)", _rocks()]); _begin()],
		[6.1, func() -> void: _touch(0, table_a, true)],
		[6.2, func() -> void: _touch(0, table_a, false)],
		[8.0, func() -> void: _log.append(["1 finger, 1 tap (expect 1)", _rocks()]); _begin()],
		[8.1, func() -> void: _touch(0, table_a, true)],
		[8.2, func() -> void: _touch(1, table_b, true)],
		[8.3, func() -> void: _touch(1, table_b, false)],
		[8.4, func() -> void: _touch(0, table_a, false)],
		[10.0, func() -> void: _log.append(["finger0 down + finger1 tap (expect 2)", _rocks()]); _begin()],
		[10.1, func() -> void:
			_touch(0, table_a, true)
			_touch(1, table_b, true)
			_touch(2, table_c, true)],
		[10.2, func() -> void:
			_touch(0, table_a, false)
			_touch(1, table_b, false)
			_touch(2, table_c, false)],
		[12.0, func() -> void: _log.append(["3 fingers at once (expect 3)", _rocks()]); _begin()],
		[12.1, func() -> void:
			for i in 10:
				_touch(0, table_a + Vector2(i * 20, 0), true)
				_touch(0, table_a + Vector2(i * 20, 0), false)],
		[14.0, func() -> void: _log.append(["10 taps in one frame at different spots (expect up to 10)", _rocks()]); _begin()],
		[14.1, func() -> void: _touch(0, table_a, true)],
		[14.2, func() -> void: _touch(1, throw_pos, true)],
		[14.3, func() -> void: _touch(1, throw_pos, false)],
		[14.4, func() -> void: _touch(0, table_a, false)],
		[16.0, func() -> void:
			_log.append(["finger0 table + finger1 on throw button: table taps (expect 1)", _rocks()])
			_log.append(["  throw button presses so far (expect 1)", _buttons])
			_touch(2, throw_pos, true)
			_touch(2, throw_pos, false)],
		[16.3, func() -> void: _log.append(["  lone finger on throw button (expect 2 total)", _buttons])],
		[16.5, func() -> void:
			for line in _log:
				print("PROBE ", line[0], ": ", line[1])
			quit()],
	]
	if _step < plan.size() and _t >= float(plan[_step][0]):
		(plan[_step][1] as Callable).call()
		_step += 1
	return false
