class_name CompanionPeek
extends Control
## Борк выглядывает из-за верхней кромки нижней панели: фигура рисуется ПОЗАДИ панели (добавлять в сцену до неё),
## поэтому панель закрывает ему пояс, и он будто вылезает из неё. Реплики и подсказки показывают HintCard и Tutorial.

const FIGURE_HEIGHT := 520.0        # полная высота картинки
const VISIBLE := 320.0              # сколько видно над панелью
const LEFT := 10.0
const RISE_SECONDS := 0.5

var panel_height := 640.0           # высота нижней панели (из main)
var _figure: TextureRect
var _shown := false
var _time := 0.0
var _tween: Tween
var _rise := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_figure = Companion.portrait(FIGURE_HEIGHT)
	if _figure == null:
		return
	_figure.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_figure)
	_figure.size = _figure.custom_minimum_size
	_place(0.0)


## Правая граница фигуры: реплики показываются правее.
static func figure_width() -> float:
	var tex := Companion.texture()
	return FIGURE_HEIGHT * float(tex.get_width()) / float(tex.get_height()) if tex != null else 0.0


## Левый край облачка с текстом: правее лица Борка.
static func bubble_left() -> float:
	return figure_width() * 0.72 + 10.0


func is_shown() -> bool:
	return _shown


func appear() -> void:
	if _figure == null or _shown:
		return
	_shown = true
	visible = true
	_animate(1.0)


func leave() -> void:
	if _figure == null or not _shown:
		return
	_shown = false
	_animate(0.0)


## k = 0 — спрятан за панелью, 1 — выглянул.
func _animate(target: float) -> void:
	if _tween != null:
		_tween.kill()
	var from := _rise
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: _place(value), from, target, RISE_SECONDS) \
			.set_trans(Tween.TRANS_BACK if target > 0.5 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if target == 0.0:
		_tween.tween_callback(func() -> void: visible = false)


func _place(k: float) -> void:
	_rise = k
	if _figure == null:
		return
	var panel_top := size.y - panel_height
	# спрятан: верх фигуры ниже кромки панели; выглянул: над кромкой на VISIBLE
	_figure.position = Vector2(LEFT, panel_top - VISIBLE * k + 12.0 * (1.0 - k) + _bob())


func _bob() -> float:
	return sin(_time * 1.6) * 3.0 if _shown else 0.0


func _process(delta: float) -> void:
	if not visible or _figure == null:
		return
	_time += delta
	if _shown and (_tween == null or not _tween.is_running()):
		_place(1.0)
