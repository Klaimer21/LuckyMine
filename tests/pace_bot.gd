extends SceneTree
## «Бот-новичок» измеряет темп первых минут: когда первая покупка, находка, золото, алмаз, зона, золотая глыба, «Новая шахта».
## Бот играет как аккуратный новичок: тапает по столу раз в полсекунды, ловит золотую глыбу через 2 секунды после появления,
## покупает самое дешёвое доступное улучшение. Время ускорено; считаются игровые секунды.
## Запуск: godot --headless --path . --script res://tests/pace_bot.gd -- <игровых секунд, по умолчанию 900> [passive|nomachines]
## Игра пишет сохранение: запускать на копии профиля, начинает с нового прогресса (см. docs/ROADMAP.md, ориентиры).

var _main: Node
var _t := 0.0                      # игровые секунды
var _duration := 900.0
var _next_tap := 0.5
var _next_buy := 0.0
var _golden_seen_at := -1.0
var _events := {}
var _purchases: Array[float] = []
var _snapshots := [30.0, 60.0, 180.0, 300.0, 600.0, 900.0]
var _snap_done := {}
var _last_biome := 0
var _passive := false
var _use_machines := true
var _machine_buys := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_duration = float(args[0])
	if args.size() > 1 and args[1] == "nomachines":
		_use_machines = false
	if args.size() > 1 and args[1] == "passive":
		_passive = true                  # игрок почти не касается экрана: растёт только «Камнепад»
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	Engine.time_scale = 10.0
	Engine.max_fps = 0
	_main.state.tutorial_done = true
	_main.state.daily_day = ClickerState.today()
	_main.state.offline_away = 0.0
	_main.state.coins = 0.0
	_main.state.total_earned = 0.0


func _mark(name: String) -> void:
	if not _events.has(name):
		_events[name] = _t


func _process(delta: float) -> bool:
	if _main == null or _main._table == null:
		return false
	_t += delta                       # delta уже умножена на time_scale: это игровые секунды
	var state: ClickerState = _main.state
	if _t < 0.1:
		return false
	if not _events.has("_connected"):
		_events["_connected"] = 0.0
		_main._table.golden_spawned.connect(func() -> void:
				_mark("первая золотая глыба")
				_golden_seen_at = _t)
		_main._table.boss_spawned.connect(func(_z: int) -> void: _mark("первый хранитель"))
		_main._table.ore_collected.connect(func(ore: int) -> void:
				_mark("первая находка")
				if ore == 3:
					_mark("первое золото")
				if ore == 4:
					_mark("первый алмаз"))
	# тап по столу раз в полсекунды
	if _t >= _next_tap and not _passive:
		_next_tap = _t + 0.5
		_main._on_throw_pressed()
	# золотая глыба: ловим через 2 секунды после появления
	if _golden_seen_at > 0.0 and _t >= _golden_seen_at + 2.0 and _main._table._golden != null:
		_main._table._hit_golden()
		_golden_seen_at = -1.0
	# покупки: самое дешёвое доступное
	if _t >= _next_buy:
		_next_buy = _t + 0.25
		var bought := ""
		# машины: покупаем уровень, как только хватает монет (игрок видит золотую рамку ячейки)
		if _use_machines and state.machine_unlocked("crusher") and state.machine_cost("crusher", 1) <= state.coins and state.machine_level("crusher") < state.machine_max_level("crusher"):
			state.buy_machine("crusher", 1)
			bought = "crusher"
			_mark("первая покупка Дробилки")
			_machine_buys += 1
		else:
			bought = state.autobuy_step()
		if bought != "":
			_purchases.append(_t)
			_mark("первая покупка")
			if _purchases.size() == 5:
				_mark("пятая покупка")
			if _purchases.size() == 20:
				_mark("двадцатая покупка")
	var biome := Biomes.index_for(state.total_earned, state.planet_scale())
	if biome > _last_biome:
		_last_biome = biome
		_mark("зона %d (%s)" % [biome, Biomes.LIST[biome]["name"]])
	if state.pending_veins() >= 1:
		_mark("«Новая шахта» доступна")
	if state.prestige_recommended():
		_mark("«Новая шахта» рекомендована")
	for snap in _snapshots:
		if _t >= snap and not _snap_done.has(snap):
			_snap_done[snap] = true
			print("PACE %4ds: заработано %s, монеты %s, доход %s/с, покупок %d, уровни %s, алмазов %d" % [int(snap), NumberFormat.short(state.total_earned), NumberFormat.short(state.coins),
					NumberFormat.short(state.income_per_second()), _purchases.size(), state.levels, state.diamonds])
	if _t >= _duration:
		_finish()
	return false


func _finish() -> void:
	print("PACE -- вехи (игровые секунды) --")
	var names := _events.keys()
	names.erase("_connected")
	names.sort_custom(func(a, b) -> bool: return float(_events[a]) < float(_events[b]))
	for name in names:
		print("PACE %6.1f c  %s" % [_events[name], name])
	var max_gap := 0.0
	var gap_at := 0.0
	var previous := 0.0
	for t in _purchases:
		if t - previous > max_gap:
			max_gap = t - previous
			gap_at = previous
		previous = t
	print("PACE покупок Дробилки: %d, уровень %d" % [_machine_buys, _main.state.machine_level("crusher")])
	print("PACE покупок за забег: %d; самая долгая пауза между покупками: %.1f c (с %.0f-й секунды)" % [_purchases.size(), max_gap, gap_at])
	quit()
