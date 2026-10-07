extends SceneTree
## Снимки поля при 4, 5 и 6 ходах ленты: godot --path . --script res://tests/density_shot.gd -- <папка>. Запускать на копии профиля.
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
	root.get_texture().get_image().save_png("%s/density_%s.png" % [_dir, n])


func _setup(planet: int, ids: Array) -> void:
	var s = _main.state
	s.tutorial_done = true
	s.daily_day = ClickerState.today()
	s.offline_away = 0.0
	for m in _main.find_children("*", "Modal", true, false):
		m.close()
	s.planet = planet
	for id in Machines.ids():
		s.machines_unlocked.erase(id)
		s.machines[id] = 0
	for id in ids:
		s.machines_unlocked[id] = true
		s.machines[id] = 8
	_main._table.auto_throw = true
	_main._machines.refresh()
	_main._refresh()


func _process(d: float) -> bool:
	_t += d
	var earth := ["crusher", "conveyor", "lab", "blaster", "winch", "cart"]
	var plan := [
		[1.0, func() -> void: _setup(0, earth)],
		[4.0, func() -> void: _shot("4")],
		[4.1, func() -> void: _setup(1, earth + ["rover", "compressor"])],
		[7.5, func() -> void: _shot("5")],
		[7.6, func() -> void: _setup(4, earth + ["rover", "compressor", "excavator", "catapult", "reactor", "burner", "acid", "solar"])],
		[11.0, func() -> void: _shot("6")],
		[11.1, func() -> void: quit()],
	]
	if _step < plan.size() and _t >= float(plan[_step][0]):
		(plan[_step][1] as Callable).call()
		_step += 1
	return false
