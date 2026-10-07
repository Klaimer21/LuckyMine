class_name Tutorial
extends Control
## Обучение: затемнение со «светлым окном» вокруг нужного элемента и подсказка. Шаги — словари
## {"text": подсказка, "rect": Callable -> Rect2 (где светить), "wait": "tap" | "throw" | "buy_rain" | "next",
## "done": необязательный Callable -> bool: если уже true, шаг пропускается}.
## Шаг со словом "next" ждёт кнопку «Дальше»; остальные идут дальше сами, когда игрок сделал нужное (notify()).
## Затемнение не перехватывает касания: игрок может нажимать что угодно, обучение лишь подсказывает.

signal finished
signal skipped

const DIM := Color(0.03, 0.05, 0.04, 0.66)

var steps: Array = []
var peek: CompanionPeek             # Борк выглядывает из нижней панели, пока идёт обучение
var panel_height := 640.0
var _index := -1
var _rect := Rect2()
var _time := 0.0
var _bubble: PanelContainer
var _counter: Label
var _text: Label
var _next: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.BRASS_DIM, 2, 18, 22))
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.SPACE_M)
	_bubble.add_child(column)
	_counter = UiTheme.make_label("", 22, UiTheme.MUTE)
	column.add_child(_counter)
	_text = UiTheme.make_label("", 32, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 560
	column.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	column.add_child(row)
	var skip := UiTheme.make_key("Пропустить", 24, "dark")
	skip.custom_minimum_size = Vector2(210, 96)
	skip.pressed.connect(_skip)
	row.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next = UiTheme.make_key("Дальше", 28, "brass")
	_next.custom_minimum_size = Vector2(190, 72)
	_next.pressed.connect(_advance)
	row.add_child(_next)


func start() -> void:
	if steps.is_empty():
		return
	_index = -1
	visible = true
	if peek != null:
		peek.set_pose("point")
		peek.appear()
	_advance()


func is_active() -> bool:
	return visible


## Игрок сделал действие: если шаг ждал именно его, идём дальше.
func notify(event: String) -> void:
	if visible and _index >= 0 and _index < steps.size() and str(steps[_index]["wait"]) == event:
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= steps.size():
		visible = false
		if peek != null:
			peek.leave()
		finished.emit()
		return
	var step: Dictionary = steps[_index]
	_counter.text = "%d / %d" % [_index + 1, steps.size()]
	_text.text = Tr.t(str(step["text"]))
	var waits_button := str(step["wait"]) == "next"
	_next.visible = waits_button
	_next.text = Tr.t("Начать" if _index == steps.size() - 1 else "Дальше")
	_place()


func _skip() -> void:
	visible = false
	if peek != null:
		peek.leave()
	skipped.emit()


func _process(delta: float) -> void:
	if not visible or _index < 0 or _index >= steps.size():
		return
	_time += delta
	var step: Dictionary = steps[_index]
	if step.has("done") and (step["done"] as Callable).call():
		_advance()
		if not visible:
			return
	_place()
	queue_redraw()


## Берёт прямоугольник шага и ставит подсказку над ним или под ним, где больше места.
func _place() -> void:
	var rect_fn: Callable = steps[_index]["rect"]
	_rect = rect_fn.call()
	var bubble_size := _bubble.get_combined_minimum_size()
	var view := size
	# обычно облачко Борка стоит над нижней панелью правее него; если там подсвечено нужное, уходит выше или ниже цели
	var left := CompanionPeek.bubble_left() if peek != null else (view.x - bubble_size.x) * 0.5
	left = minf(left, view.x - bubble_size.x - 24.0)
	var y := view.y - panel_height - bubble_size.y - 18.0
	var spot := Rect2(Vector2(left, y), bubble_size)
	if spot.intersects(_rect.grow(14.0)):
		y = _rect.position.y - bubble_size.y - 24.0
		if y < 12.0:
			y = _rect.end.y + 24.0
		y = clampf(y, 12.0, maxf(12.0, view.y - bubble_size.y - 12.0))
	_bubble.position = Vector2(left, y)


func _draw() -> void:
	if _index < 0 or _index >= steps.size():
		return
	var hole := _rect.grow(14.0)
	var view := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(0, 0, view.size.x, maxf(0.0, hole.position.y)), DIM)
	draw_rect(Rect2(0, hole.end.y, view.size.x, maxf(0.0, view.size.y - hole.end.y)), DIM)
	draw_rect(Rect2(0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y), DIM)
	draw_rect(Rect2(hole.end.x, hole.position.y, maxf(0.0, view.size.x - hole.end.x), hole.size.y), DIM)
	var pulse := 0.55 + 0.45 * sin(_time * 4.0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.set_border_width_all(3)
	frame.border_color = Color(UiTheme.BRASS, pulse)
	UiTheme.pixelize(frame, 10)
	draw_style_box(frame, hole)
