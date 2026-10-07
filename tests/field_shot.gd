extends SceneTree
## Снимки 2D-поля: godot --path . --script res://tests/field_shot.gd -- <папка>. Игра пишет сохранение: запускать на копии профиля.
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


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s/field_%s.png" % [_dir, n])


func _process(d: float) -> bool:
	_t += d
	var plan := [
		[1.0, func() -> void:
			var s = _main.state
			s.tutorial_done = true
			s.daily_day = ClickerState.today()
			s.offline_away = 0.0
			for m in _main.find_children("*", "Modal", true, false):
				m.close()
			for id in ["crusher", "conveyor", "lab", "blaster", "winch", "cart"]:
				s.machines_unlocked[id] = true
				s.machines[id] = maxi(int(s.machines[id]), 6)
			_main._machines.refresh()],
		[5.0, func() -> void: _shot("a")],
		[5.2, func() -> void: _main._table.tap(Vector2(540, 900))],
		[5.5, func() -> void: _shot("b")],
		[5.6, func() -> void: _main._table.spawn_boss(1)],
		[7.5, func() -> void: _shot("boss")],
		[7.6, func() -> void: _main._table.detonate()],
		[7.8, func() -> void: _shot("boom")],
		[7.9, func() -> void: quit()],
	]
	if _step < plan.size() and _t >= float(plan[_step][0]):
		(plan[_step][1] as Callable).call()
		_step += 1
	return false
