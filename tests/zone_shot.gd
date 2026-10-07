extends SceneTree
## Скриншоты фонов всех зон: godot --path . --script res://tests/zone_shot.gd -- <папка>
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
		[1.5, func() -> void: _main._table.set_biome(0, false); ZonePalette.apply(0, _main)],
		[2.5, func() -> void: _shot("zone_0")],
		[3.5, func() -> void: _main._table.set_biome(1, false); ZonePalette.apply(1, _main)],
		[4.5, func() -> void: _shot("zone_1")],
		[5.5, func() -> void: _main._table.set_biome(2, false); ZonePalette.apply(2, _main)],
		[6.5, func() -> void: _shot("zone_2")],
		[7.5, func() -> void: _main._table.set_biome(3, false); ZonePalette.apply(3, _main)],
		[8.5, func() -> void: _shot("zone_3")],
		[9.5, func() -> void: _main._table.set_biome(4, false); ZonePalette.apply(4, _main)],
		[10.5, func() -> void: _shot("zone_4")],
		[11.5, func() -> void: _main._table.set_biome(5, false); ZonePalette.apply(5, _main)],
		[12.5, func() -> void: _shot("zone_5")],
		[13.5, func() -> void: _main._table.set_biome(6, false); ZonePalette.apply(6, _main)],
		[14.5, func() -> void: _shot("zone_6")],
		[15.5, func() -> void: quit()],
	]
	if _step < plan.size() and _t >= float(plan[_step][0]):
		(plan[_step][1] as Callable).call()
		_step += 1
	return false
