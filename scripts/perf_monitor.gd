class_name PerfMonitor
extends RefCounted
## Счётчик FPS, «Тест нагрузки» (15 секунд максимального потока глыб) и совет понизить качество при стабильно низком FPS.

const STRESS_SECONDS := 15.0
const STRESS_RATE := 500.0

var stress_active := false

var host: Control
var state: ClickerState
var settings: Settings
var table: MineTable
var viewport: Viewport
var _on_low_fps: Callable          # вызывается один раз, когда игра долго идёт на низком FPS
var _fps_label: Label
var _stress_label: Label
var _fps_timer := 0.0
var _stress_time := 0.0
var _stress_deltas := PackedFloat32Array()
var _stress_peak := 0
var _stress_auto_before := true
var _watch_time := 0.0
var _watch_frames := 0
var _hint_done := false


func setup(host_node: Control, game_state: ClickerState, game_settings: Settings, mine_table: MineTable,
		view: Viewport, on_low_fps: Callable) -> PerfMonitor:
	host = host_node
	state = game_state
	settings = game_settings
	table = mine_table
	viewport = view
	_on_low_fps = on_low_fps
	return self


## Создаёт подписи (при каждой пересборке интерфейса заново).
func build() -> void:
	_fps_label = UiTheme.make_label("", 22, UiTheme.MUTE)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -240
	_fps_label.offset_right = -28
	_fps_label.offset_top = 98
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.add_child(_fps_label)
	_stress_label = UiTheme.make_label("", 34, UiTheme.BRASS, true)
	_stress_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_stress_label.offset_top = 330
	_stress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stress_label.visible = false
	host.add_child(_stress_label)
	refresh_fps_visibility()


func refresh_fps_visibility() -> void:
	_fps_label.visible = settings.show_fps


## Каждый кадр: подпись FPS, ход теста нагрузки, наблюдение за FPS.
func update(delta: float) -> void:
	_update_fps(delta)
	_update_stress(delta)
	_watch_fps(delta)


## Тест нагрузки: 15 секунд максимального потока глыб, замер кадров, итог с рекомендацией.
func start_stress() -> void:
	if stress_active:
		return
	stress_active = true
	_stress_time = 0.0
	_stress_deltas = PackedFloat32Array()
	_stress_peak = 0
	_stress_auto_before = table.auto_throw
	table.stress_rate = STRESS_RATE
	_stress_label.visible = true


func _update_stress(delta: float) -> void:
	if not stress_active:
		return
	_stress_time += delta
	if _stress_time > 1.0:                      # первую секунду не считаем: сцена прогревается
		_stress_deltas.append(delta)
	_stress_peak = maxi(_stress_peak, table.rock_count())
	_stress_label.text = Tr.t("Тест нагрузки") + "  %d" % maxi(0, int(STRESS_SECONDS) - int(_stress_time))
	if _stress_time >= STRESS_SECONDS:
		_finish_stress()


func _finish_stress() -> void:
	stress_active = false
	table.stress_rate = 0.0
	table.auto_throw = _stress_auto_before
	_stress_label.visible = false
	var sorted := Array(_stress_deltas)
	sorted.sort()
	var total := 0.0
	for d in sorted:
		total += float(d)
	var average_fps := float(sorted.size()) / maxf(total, 0.0001)
	var worst_count := maxi(1, int(sorted.size() / 100.0))
	var worst := 0.0
	for i in worst_count:
		worst += float(sorted[sorted.size() - 1 - i])
	var low_fps := 1.0 / maxf(worst / worst_count, 0.0001)

	var report := Modal.new()
	report.body.add_child(UiTheme.make_label("Тест нагрузки", 50, UiTheme.TEXT, true))
	report.body.add_child(UiTheme.make_label(Tr.t("Средний FPS: %d") % int(average_fps), 38, UiTheme.TEXT))
	report.body.add_child(UiTheme.make_label(Tr.t("Нижние 1%%: %d") % int(low_fps), 38, UiTheme.TEXT))
	report.body.add_child(UiTheme.make_label(Tr.t("Глыб одновременно: %d") % _stress_peak, 32, UiTheme.MUTE))
	var weak := average_fps < 45.0 or low_fps < 25.0
	var verdict := UiTheme.make_label("FPS низкий: лучше понизить качество." if weak else "Хорошо: качество можно оставить.",
			30, UiTheme.BRASS if weak else UiTheme.MUTE)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.body.add_child(verdict)
	if weak and settings.quality > 0:
		var lower := UiTheme.make_button("Понизить качество", true, 32)
		lower.pressed.connect(func() -> void:
				settings.quality -= 1
				settings.apply(viewport, table)
				settings.save()
				report.close())
		report.body.add_child(lower)
	var close := UiTheme.make_button("Закрыть", false, 32)
	close.pressed.connect(report.close)
	report.body.add_child(close)
	host.add_child(report)


## Следим за кадрами: если стабильно мало, один раз советуем снизить качество (только на слабом железе).
func _watch_fps(delta: float) -> void:
	if _hint_done or stress_active or not state.tutorial_done:
		return
	_watch_time += delta
	_watch_frames += 1
	if _watch_time < 10.0:
		return
	var fps := float(_watch_frames) / _watch_time
	_watch_time = 0.0
	_watch_frames = 0
	if fps < 35.0 and settings.quality > 0:
		_hint_done = true
		_on_low_fps.call()


func _update_fps(delta: float) -> void:
	_fps_label.visible = settings.show_fps
	_fps_timer += delta
	if _fps_timer >= 0.25 and settings.show_fps:
		_fps_timer = 0.0
		_fps_label.text = "FPS %d  ·  %d" % [int(Engine.get_frames_per_second()), table.rock_count()]
