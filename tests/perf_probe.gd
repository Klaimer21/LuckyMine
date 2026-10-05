extends SceneTree
## Замер нагрузки в тесте нагрузки (максимальный поток глыб) для каждого качества графики.
## От видеокарты почти не зависят: вызовы отрисовки, объекты, полигоны, время скриптов на кадр — по ним можно
## прикинуть запас для слабых телефонов (процессор телефона обычно в 3–6 раз медленнее настольного).
## Запуск (нужно окно): godot --path . --resolution 540x960 --script res://tests/perf_probe.gd
## Игра пишет сохранение: запускать на копии профиля.

const SECONDS_PER_QUALITY := 8.0
const WARMUP := 2.0

var _main: Node
var _quality := 0
var _t := 0.0
var _samples := {}
var _frames := 0
var _results := []


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _begin_quality() -> void:
	_main.settings.quality = _quality
	_main.settings.apply(root, _main._table)
	_main._table.auto_throw = true
	_main._table.stress_rate = 500.0
	_t = 0.0
	_frames = 0
	_samples = {"process_ms": 0.0, "draw_calls": 0.0, "objects": 0.0, "primitives": 0.0, "fps": 0.0, "rocks": 0.0, "draw_peak": 0.0}


func _process(delta: float) -> bool:
	if _main == null or _main._table == null:
		return false
	if _frames == 0 and _t == 0.0:
		_main.state.tutorial_done = true
		_main.state.daily_day = ClickerState.today()
		_main.state.offline_away = 0.0
		_begin_quality()
	_t += delta
	_frames += 1
	if _t > WARMUP:
		var draw := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_samples["process_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_samples["draw_calls"] += draw
		_samples["draw_peak"] = maxf(_samples["draw_peak"], draw)
		_samples["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		_samples["primitives"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_samples["fps"] += Performance.get_monitor(Performance.TIME_FPS)
		_samples["rocks"] += _main._table.rock_count()
		_samples["n"] = float(_samples.get("n", 0.0)) + 1.0
	if _t >= SECONDS_PER_QUALITY + WARMUP:
		var n := maxf(1.0, float(_samples.get("n", 1.0)))
		_results.append({"quality": _quality, "process_ms": _samples["process_ms"] / n, "draw_calls": _samples["draw_calls"] / n,
				"draw_peak": _samples["draw_peak"], "objects": _samples["objects"] / n, "primitives": _samples["primitives"] / n,
				"fps": _samples["fps"] / n, "rocks": _samples["rocks"] / n})
		_quality += 1
		if _quality > 2:
			_finish()
		else:
			_begin_quality()
	return false


func _finish() -> void:
	var names := ["Низкое", "Среднее", "Высокое"]
	for r in _results:
		print("PERF %-8s  скрипты %.2f мс/кадр, вызовов отрисовки %.0f (пик %.0f), объектов %.0f, полигонов %.0fK, глыб %.0f, FPS %.0f" % [
				names[int(r["quality"])], r["process_ms"], r["draw_calls"], r["draw_peak"], r["objects"], float(r["primitives"]) / 1000.0, r["rocks"], r["fps"]])
	quit()
