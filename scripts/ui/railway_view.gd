class_name RailwayView
extends Control
## Поле «Узкоколейки»: кольцо из 20 клеток (рамка 6×6), по клеткам идут рельсы со шпалами, в центре кубик, жетоны и
## кнопка броска. После броска (railway.animate_pending) кубик крутится, вагонетка едет по клеткам, затем показывается итог.

const N := 6                               # клеток по стороне
const GAP := 6.0
const CELL_ICONS := {
	"start": "rail_depot", "coins_s": "coin", "coins_m": "px_coins", "coins_l": "px_coins", "gems": "gem", "finds": "px_bag",
	"picks": "px_pickaxe", "dynamite": "px_bomb", "chest": "chest", "star": "star", "arrow": "rail_switch", "collapse": "rail_rubble",
}
## Цвет подложки клетки: ценные клетки теплее, пустые — холодный камень.
const CELL_TONES := {
	"start": Color(0.20, 0.16, 0.10), "chest": Color(0.24, 0.19, 0.08), "star": Color(0.22, 0.20, 0.08),
	"gems": Color(0.10, 0.18, 0.20), "collapse": Color(0.11, 0.11, 0.11), "arrow": Color(0.10, 0.18, 0.10),
}
const STEP_SECONDS := 0.16

var state: ClickerState
var journal: JournalScreen
var _cell := 150.0
var _cart: Icon
var _die_value := 1
var _die_spin := 0.0
var _result_label: Label
var _die_box: Control
var _roll_button: Button
var _busy := false
var _landed := -1                          # клетка, где остановилась вагонетка (латунная рамка после броска)


func setup(p_state: ClickerState, p_journal: JournalScreen, width: float) -> RailwayView:
	state = p_state
	journal = p_journal
	_cell = floorf((width - GAP * (N - 1)) / N)
	var side := _cell * N + GAP * (N - 1)
	custom_minimum_size = Vector2(side, side)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_die_value = maxi(1, state.railway.last_roll)
	_build_cells()
	_build_center(side)
	_cart = Icon.new().setup("rail_minecart", Color.WHITE, _cell * 0.62)
	add_child(_cart)
	_cart.position = _cart_spot(state.railway.pos)
	if state.railway.animate_pending:
		state.railway.animate_pending = false
		_animate()
	return self


## Клетка i кольца -> позиция в сетке 6×6: верх слева направо, правый край вниз, низ справа налево, левый край вверх.
static func grid_of(i: int) -> Vector2i:
	if i < N:
		return Vector2i(i, 0)
	if i < N + N - 2:
		return Vector2i(N - 1, i - N + 1)
	if i < N * 2 - 2 + N:
		return Vector2i(N - 1 - (i - (N * 2 - 2)), N - 1)
	return Vector2i(0, N - 2 - (i - (N * 3 - 2)))


func _cell_rect(i: int) -> Rect2:
	var g := grid_of(i)
	return Rect2(Vector2(g.x, g.y) * (_cell + GAP), Vector2(_cell, _cell))


func _cart_spot(i: int) -> Vector2:
	var rect := _cell_rect(i)
	var side := _cell * 0.62
	return rect.position + Vector2((_cell - side) * 0.5, _cell - side - 4.0)


func _build_cells() -> void:
	for i in Railway.BOARD.size():
		var kind := str(Railway.BOARD[i])
		var rect := _cell_rect(i)
		var icon_side := _cell * 0.46
		var icon := Icon.new().setup(str(CELL_ICONS.get(kind, "coin")), Color.WHITE, icon_side)
		icon.position = rect.position + Vector2((_cell - icon_side) * 0.5, 8.0)
		add_child(icon)
		if kind == "coins_l":
			var big := UiTheme.make_label("×10", 20, UiTheme.BRASS, true)
			big.position = rect.position + Vector2(_cell - 52.0, 2.0)
			big.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(big)


func _build_center(side: float) -> void:
	var inner := Rect2(Vector2(_cell + GAP * 2.0, _cell + GAP * 2.0), Vector2(side - 2.0 * (_cell + GAP * 2.0), side - 2.0 * (_cell + GAP * 2.0)))
	var box := VBoxContainer.new()
	box.position = inner.position
	box.size = inner.size
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UiTheme.SPACE_S)
	add_child(box)
	var railway := state.railway
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", UiTheme.SPACE_S)
	box.add_child(head)
	head.add_child(Icon.new().setup("rail_token", Color.WHITE, 56))
	head.add_child(UiTheme.make_label(str(railway.tickets), 48, UiTheme.TEXT, true))
	var laps := UiTheme.make_label(Tr.t("Круг %d") % (railway.laps + 1), 26, UiTheme.MUTE)
	laps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(laps)
	var die_holder := Control.new()
	die_holder.custom_minimum_size = Vector2(0, 130)
	box.add_child(die_holder)
	die_holder.draw.connect(func() -> void: _draw_die(die_holder))
	_die_box = die_holder
	_result_label = UiTheme.make_label("", 22, UiTheme.BRASS)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size.x = inner.size.x
	box.add_child(_result_label)
	if railway.double_next:
		var star := UiTheme.make_label(Tr.t("Звезда: следующая награда ×2"), 22, Color(0.98, 0.84, 0.35))
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(star)
	_roll_button = UiTheme.make_key(Tr.t("Бросить кубик") if railway.tickets > 0 else Tr.t("Нет жетонов"), 30, "brass")
	_roll_button.custom_minimum_size = Vector2(inner.size.x * 0.8, 92)
	_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_button.disabled = railway.tickets <= 0
	_roll_button.pressed.connect(func() -> void:
			if not _busy:
				journal.cart_roll.emit())
	box.add_child(_roll_button)
	var wait := state.ad_remaining("tickets")
	var ad := UiTheme.make_key(Tr.t("Жетоны +%d (реклама)") % Railway.AD_TICKETS if wait <= 0.0 else JournalScreen._format_time(wait), 22, "felt")
	JournalScreen.track_ad(ad, "tickets", Tr.t("Жетоны +%d (реклама)") % Railway.AD_TICKETS)
	ad.custom_minimum_size = Vector2(inner.size.x * 0.8, 72)
	ad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ad.disabled = wait > 0.0
	ad.pressed.connect(func() -> void: journal.ad_requested.emit("tickets"))
	box.add_child(ad)


func _draw() -> void:
	# подложка шахты под кольцом
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.06))
	for i in Railway.BOARD.size():
		var kind := str(Railway.BOARD[i])
		var rect := _cell_rect(i)
		var tone: Color = CELL_TONES.get(kind, Color(0.13, 0.15, 0.14))
		var edge := UiTheme.BRASS if kind == "start" or i == _landed else UiTheme.LINE_STRONG
		draw_style_box(UiTheme.panel_style(tone, edge, 4 if i == _landed else 2, 12, 0), rect)
	# рельсы: от центра каждой клетки к соседям по кольцу (шпалы и две нитки стали), видны и в зазорах
	for i in Railway.BOARD.size():
		var a := _track_point(i)
		var b := _track_point((i + 1) % Railway.BOARD.size())
		_draw_rails(a, b)


func _track_point(i: int) -> Vector2:
	var rect := _cell_rect(i)
	return rect.position + Vector2(_cell * 0.5, _cell - 26.0)


func _draw_rails(a: Vector2, b: Vector2) -> void:
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var length := a.distance_to(b)
	var sleeper := Color(0.36, 0.23, 0.13)
	var steps := int(length / 18.0)
	for k in steps + 1:
		var p := a + direction * (k * length / maxf(1.0, float(steps)))
		draw_line(p - normal * 15.0, p + normal * 15.0, sleeper, 6.0)
	var steel := Color(0.67, 0.72, 0.77)
	draw_line(a - normal * 9.0, b - normal * 9.0, steel, 4.0)
	draw_line(a + normal * 9.0, b + normal * 9.0, steel, 4.0)


## Кубик: кость слоновой кости с тёмными точками; во время броска чуть покачивается.
func _draw_die(holder: Control) -> void:
	var side := 112.0
	var center := Vector2(holder.size.x * 0.5, holder.size.y * 0.5)
	holder.draw_set_transform(center, sin(_die_spin * 30.0) * 0.25 if _die_spin > 0.0 else 0.0, Vector2.ONE)
	var rect := Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side))
	holder.draw_style_box(UiTheme.panel_style(Color(0.94, 0.91, 0.84), Color(0.04, 0.07, 0.06), 4, 18, 0), rect)
	var spots := {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
			4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
			5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
			6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
	for spot in spots[clampi(_die_value, 1, 6)]:
		var p: Vector2 = spot * 30.0
		holder.draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color(0.10, 0.10, 0.09))
	holder.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Кубик крутится, затем вагонетка проезжает по клеткам last_path; в конце — подпись с наградой.
func _animate() -> void:
	_busy = true
	var railway := state.railway
	var path: Array = railway.last_path.duplicate()
	var start := posmod(int(path[0]) - 1, Railway.BOARD.size()) if not path.is_empty() else railway.pos
	_cart.position = _cart_spot(start)
	var tween := create_tween()
	var holder := _die_box
	for k in 8:
		tween.tween_callback(func() -> void:
				_die_value = randi_range(1, 6)
				_die_spin = 1.0
				if holder != null:
					holder.queue_redraw())
		tween.tween_interval(0.05)
	tween.tween_callback(func() -> void:
			_die_value = railway.last_roll
			_die_spin = 0.0
			if holder != null:
				holder.queue_redraw())
	for cell in path:
		tween.tween_property(_cart, "position", _cart_spot(int(cell)) + Vector2(0, -14), STEP_SECONDS * 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_cart, "position", _cart_spot(int(cell)), STEP_SECONDS * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
			_busy = false
			_landed = railway.pos
			queue_redraw()
			_result_label.text = result_text(railway.last_result)
			var pop := create_tween()
			_cart.pivot_offset = _cart.size * 0.5
			pop.tween_property(_cart, "scale", Vector2(1.25, 1.25), 0.08)
			pop.tween_property(_cart, "scale", Vector2.ONE, 0.12))


## Подпись итога броска: клетка, награда, круг.
static func result_text(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var parts: Array[String] = []
	if bool(result.get("arrow", false)):
		parts.append(Tr.t("Стрелка: ещё +%d") % Railway.ARROW_STEPS)
	match str(result.get("cell", "")):
		"star":
			parts.append(Tr.t("Звезда: следующая награда ×2"))
		"collapse":
			parts.append(Tr.t("Завал: пусто"))
	if result.has("coins"):
		parts.append(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])))
	if result.has("diamonds"):
		parts.append(Tr.t("Алмазы: +%d") % int(result["diamonds"]))
	if result.has("count"):
		parts.append(Tr.t("Находки: +%d") % int(result["count"]))
	if result.has("picks"):
		parts.append(Tr.t("Кирки +%d") % int(result["picks"]))
	if int(result.get("dynamite", 0)) > 0:
		parts.append(Tr.t("Динамит +%d") % int(result["dynamite"]))
	if bool(result.get("doubled", false)):
		parts.append("×2")
	if result.has("lap"):
		var lap: Dictionary = result["lap"]
		var lap_text := Tr.t("Круг пройден") + ": " + Tr.t("Алмазы: +%d") % int(lap["diamonds"]) + ", " + Tr.t("Кирки +%d") % int(lap["picks"])
		if int(lap["points"]) > 0:
			lap_text += ", " + Tr.t("Очко навыков +1")
		parts.append(lap_text)
	return "\n".join(parts) if parts.size() > 2 else ", ".join(parts)
