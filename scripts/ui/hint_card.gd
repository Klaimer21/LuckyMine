class_name HintCard
extends Control
## Подсказка по требованию: Борк выглядывает из нижней панели и говорит в облачке над ней. Появляется впервые при
## событии и исчезает сама (или по касанию). Подсказки идут по одной, остальные ждут в очереди.
## Какие уже показаны — помнит ClickerState.

const SHOW_SECONDS := 9.0

var peek: CompanionPeek
var panel_height := 640.0
var _lift := 0.0                      # на сколько поднять облачко (например, над открытым меню улучшений)

var _queue: Array[String] = []
var _bubble: PanelContainer
var _label: Label
var _time := 0.0
var _shown := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.BRASS_DIM, 2, 18, 18))
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.modulate.a = 0.0
	_bubble.visible = false
	add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_bubble.add_child(column)
	column.add_child(UiTheme.make_label("Борк", 22, UiTheme.BRASS, true))
	_label = UiTheme.make_label("", 28, UiTheme.TEXT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_label)
	_bubble.gui_input.connect(func(event: InputEvent) -> void:
			if _shown and event is InputEventMouseButton and event.pressed:
				_dismiss())
	_layout()


## Облачко стоит над нижней панелью правее фигуры Борка и растёт вверх.
func _layout() -> void:
	var left := CompanionPeek.bubble_left()
	_bubble.anchor_left = 0.0
	_bubble.anchor_right = 1.0
	_bubble.anchor_top = 1.0
	_bubble.anchor_bottom = 1.0
	_bubble.offset_left = left
	_bubble.offset_right = -24.0
	_bubble.offset_bottom = -panel_height - 18.0 - _lift
	_bubble.offset_top = _bubble.offset_bottom - 80.0
	_bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN


func set_lift(pixels: float) -> void:
	_lift = pixels
	_layout()


func show_hint(text: String) -> void:
	_queue.append(text)
	if not _shown:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_shown = false
		_bubble.visible = false
		if peek != null:
			peek.leave()
		return
	_shown = true
	_label.text = _queue.pop_front()
	_layout()
	_bubble.visible = true
	_time = 0.0
	if peek != null:
		peek.appear()
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if not _shown:
		return
	_time += delta
	if _time >= SHOW_SECONDS:
		_dismiss()


func _dismiss() -> void:
	_shown = false
	var tween := create_tween()
	tween.tween_property(_bubble, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_next)
