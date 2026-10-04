class_name Modal
extends Control
## Окно поверх экрана: затемнение и панель. Содержимое добавляется в `body`; закрытие — close().

signal closed

var body: VBoxContainer
var _panel: PanelContainer
var _closing := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	_panel = panel
	panel.custom_minimum_size.x = 900
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.SURFACE
	style.set_corner_radius_all(14)
	style.set_border_width_all(1)
	style.border_color = UiTheme.BRASS_DIM
	style.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	panel.add_child(body)


## Появление: затемнение проявляется, панель «всплывает» из чуть меньшего размера.
func _ready() -> void:
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.14)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Кнопка «Назад» на Android и Esc на компьютере закрывают верхнее окно. Закрытие рекламной заглушки раньше времени награды не даёт.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _is_top():
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_top():
		get_viewport().set_input_as_handled()
		close()


func _is_top() -> bool:
	var parent := get_parent()
	return parent != null and not _closing and parent.get_child(parent.get_child_count() - 1) == self


## Закрытие: сигнал уходит сразу, окно плавно гаснет и удаляется.
func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_inside_tree():
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)
