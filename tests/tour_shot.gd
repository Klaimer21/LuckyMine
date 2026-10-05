extends SceneTree
## Скриншоты тура по машинам: godot --path . --script res://tests/tour_shot.gd -- <папка>
## Игра пишет сохранение: запускать на копии профиля.

var _main: Node
var _t := 0.0
var _step := 0
var _dir := "."


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = args[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.state.tutorial_done = true
	_main.state.daily_day = ClickerState.today()
	_main.state.offline_away = 0.0


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])


func _process(delta: float) -> bool:
	_t += delta
	if _main == null or _main._table == null:
		return false
	var plan := [
		[0.5, func() -> void:
			_main.state.auto_throw = false
			_main._table.auto_throw = false
			for modal in _main.find_children("*", "Modal", true, false):
				modal.close()],
		[1.5, func() -> void: _main.state.levels["rain"] = 5],
		[3.2, func() -> void: _shot("0_tour_step1")],
		[3.3, func() -> void: _main._machine_tour._advance()],
		[4.2, func() -> void: _shot("1_tour_step2")],
		[4.3, func() -> void: _main._machine_tour._advance()],
		[4.8, func() -> void:
			_main.state.coins = 1.0e6
			_main.state.machines["crusher"] = 5
			_main.state.machines_unlocked["conveyor"] = true
			_main.state.machines["conveyor"] = 3
			_main._machines.refresh()],
		[5.5, func() -> void: _shot("2_strip_running")],
		[5.6, func() -> void: quit()],
	]
	if _step < plan.size() and _t >= float(plan[_step][0]):
		(plan[_step][1] as Callable).call()
		_step += 1
	return false
