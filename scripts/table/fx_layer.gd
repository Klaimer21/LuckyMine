class_name FxLayer
extends Control
## 2D-эффекты поверх стола: искры цвета руды летят от места удара к счётчику, круги от касаний.

signal spark_arrived

const MAX_SPARKS := 160

var target := Vector2(120, 120)

var _sparks: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
var _blasts: Array[Dictionary] = []
var _flash := 0.0
var _rng := RandomNumberGenerator.new()


var reduced := false                   # «Меньше эффектов»: без вспышек (искры к счётчику остаются)


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


func emit_sparks(from: Vector2, color: Color = UiTheme.BRASS) -> void:
	if _sparks.size() > MAX_SPARKS:
		return
	for i in 4:
		_sparks.append({
			"from": from + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 10.0)),
			"ctrl": Vector2(_rng.randf_range(160.0, size.x - 160.0), _rng.randf_range(300.0, 700.0)),
			"t": -_rng.randf_range(0.0, 0.12), "dur": _rng.randf_range(0.55, 0.8),
			"r": _rng.randf_range(5.0, 8.0), "color": color,
		})


## Короткий четырёхлучевой блик на месте вылета редкой руды.
func glint(at: Vector2, color: Color = Color(1.0, 0.97, 0.85)) -> void:
	if reduced:
		return
	if _glints.size() < 12:
		_glints.append({"pos": at, "t": 0.0, "color": color})


## Взрыв динамита: расходящаяся волна и короткая вспышка.
func blast(at: Vector2) -> void:
	if reduced:
		return
	_blasts.append({"pos": at, "t": 0.0})
	_flash = 0.35


func ripple(at: Vector2) -> void:
	_ripples.append({"pos": at, "t": 0.0})


func _process(delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		_sparks[i]["t"] += delta
		if _sparks[i]["t"] >= _sparks[i]["dur"]:
			_sparks.remove_at(i)
			spark_arrived.emit()
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i]["t"] += delta
		if _ripples[i]["t"] > 0.6:
			_ripples.remove_at(i)
	_flash = maxf(0.0, _flash - delta * 1.2)
	for i in range(_blasts.size() - 1, -1, -1):
		_blasts[i]["t"] += delta
		if _blasts[i]["t"] > 0.7:
			_blasts.remove_at(i)
	for i in range(_glints.size() - 1, -1, -1):
		_glints[i]["t"] += delta
		if _glints[i]["t"] > 0.45:
			_glints.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for spark in _sparks:
		var t: float = spark["t"]
		if t < 0.0:
			continue
		var u := t / float(spark["dur"])
		var e := u * u * (3.0 - 2.0 * u)
		var a: Vector2 = spark["from"]
		var c: Vector2 = spark["ctrl"]
		var pos := a.lerp(c, e).lerp(c.lerp(target, e), e)
		draw_circle(pos, float(spark["r"]) * (1.0 - 0.4 * u), Color(spark["color"], minf(1.0, (1.0 - u) * 1.6)))
	for ring in _ripples:
		var u := float(ring["t"]) / 0.6
		draw_arc(ring["pos"], 24.0 + 90.0 * u, 0.0, TAU, 40, Color(UiTheme.BRASS, 0.5 * (1.0 - u)), 3.0, true)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.94, 0.78, _flash * 0.5))
	for b in _blasts:
		var u := float(b["t"]) / 0.7
		var e := 1.0 - pow(1.0 - u, 3.0)
		draw_arc(b["pos"], 40.0 + 1100.0 * e, 0.0, TAU, 96, Color(UiTheme.BRASS, 0.8 * (1.0 - u)), 14.0 * (1.0 - u) + 2.0, true)
		draw_arc(b["pos"], 20.0 + 700.0 * e, 0.0, TAU, 96, Color(1.0, 0.95, 0.8, 0.5 * (1.0 - u)), 6.0 * (1.0 - u) + 1.0, true)
	for g in _glints:
		var u := float(g["t"]) / 0.45
		var reach := 70.0 * sin(u * PI)
		var tint: Color = g["color"]
		var center: Vector2 = g["pos"]
		var line_color := Color(tint, 1.0 - u)
		draw_line(center - Vector2(reach, 0.0), center + Vector2(reach, 0.0), line_color, 3.0, true)
		draw_line(center - Vector2(0.0, reach), center + Vector2(0.0, reach), line_color, 3.0, true)
		draw_circle(center, 8.0 * (1.0 - u), line_color)
