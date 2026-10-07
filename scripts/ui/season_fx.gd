class_name SeasonFx
extends Control
## Частицы сезона поверх стола и под интерфейсом: зимой снег падает, на Хэллоуин поднимаются тёплые искры.
## «Меньше эффектов» отключает частицы, на низком качестве их вдвое меньше. Ввод не перехватывают.

var _snow: CPUParticles2D
var _embers: CPUParticles2D
var _reduced := false
var _quality := 1

## Пиксельные украшения сезона (assets/pixel/seasons): медленно проплывают по экрану под интерфейсом.
const DECOR := {
	"winter": ["ornament", "candy_cane", "mitten", "holly", "gift", "snowman", "fir"],
	"halloween": ["pumpkin", "ghost", "bat", "candy", "skull", "black_cat"],
}
const DECOR_PIXEL := 3.0                  # спрайт 28x28 показывается 84x84
const MAX_DECOR := 5
var _season := ""
var _decor: Array[Dictionary] = []
var _spawn_in := 2.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snow = _make_layer(Color(1, 1, 1, 0.9), Vector2(0, 1), 44.0, 86.0, 11.0)
	_embers = _make_layer(Color(1.0, 0.62, 0.18, 0.85), Vector2(0, -1), 70.0, 130.0, 13.0)
	_embers.color_ramp = _ember_ramp()
	add_child(_snow)
	add_child(_embers)
	resized.connect(_layout)
	_layout()
	_rng.randomize()
	set_process(false)


func _make_layer(color: Color, direction: Vector2, speed_min: float, speed_max: float, lifetime: float) -> CPUParticles2D:
	var layer := CPUParticles2D.new()
	layer.emitting = false
	layer.amount = 60
	layer.lifetime = lifetime
	layer.preprocess = lifetime
	layer.direction = direction
	layer.spread = 14.0
	layer.gravity = Vector2.ZERO
	layer.initial_velocity_min = speed_min
	layer.initial_velocity_max = speed_max
	layer.scale_amount_min = 5.0
	layer.scale_amount_max = 11.0
	layer.color = color
	layer.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	layer.local_coords = false
	return layer


func _ember_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.65, 0.2, 0.0), Color(1.0, 0.6, 0.15, 0.9), Color(0.72, 0.3, 0.9, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	return ramp


func _layout() -> void:
	var width := maxf(size.x, 1080.0)
	var height := maxf(size.y, 1920.0)
	_snow.position = Vector2(width * 0.5, -20.0)
	_snow.emission_rect_extents = Vector2(width * 0.5, 10.0)
	_embers.position = Vector2(width * 0.5, height * 0.78)      # над нижней панелью, иначе искры прячутся за ней
	_embers.emission_rect_extents = Vector2(width * 0.5, 10.0)


## id — сезон (Seasons), reduced — «Меньше эффектов», quality — качество графики 0…2.
func apply(id: String, reduced: bool, quality: int) -> void:
	_reduced = reduced
	_quality = quality
	_snow.amount = 45 if quality == 0 else 90
	_embers.amount = 36 if quality == 0 else 70
	_snow.emitting = id == "winter" and not reduced
	_embers.emitting = id == "halloween" and not reduced
	_season = id if DECOR.has(id) and not reduced else ""
	set_process(_season != "" or not _decor.is_empty())
	if _season == "":
		for item in _decor:
			(item["node"] as Node).queue_free()
		_decor.clear()


func _process(delta: float) -> void:
	_clock += delta
	var width := maxf(size.x, 1080.0)
	var height := maxf(size.y, 1920.0)
	if _season != "":
		_spawn_in -= delta
		var limit := MAX_DECOR - (2 if _quality == 0 else 0)
		if _spawn_in <= 0.0 and _decor.size() < limit:
			_spawn_in = _rng.randf_range(3.0, 6.0)
			_spawn_decor(width, height)
	for i in range(_decor.size() - 1, -1, -1):
		var item := _decor[i]
		var node := item["node"] as TextureRect
		var kind := str(item["kind"])
		item["t"] += delta
		var t: float = item["t"]
		var sway := sin(t * float(item["freq"]) + float(item["phase"])) * float(item["amp"])
		if kind == "bat":
			node.position = Vector2(float(item["x0"]) + t * float(item["speed"]) * float(item["dir"]), float(item["y0"]) + sway)
		elif _season == "halloween":
			node.position = Vector2(float(item["x0"]) + sway, float(item["y0"]) - t * float(item["speed"]))      # поднимаются
		else:
			node.position = Vector2(float(item["x0"]) + sway, float(item["y0"]) + t * float(item["speed"]))       # падают
		node.modulate.a = 0.9 * minf(1.0, minf(t * 1.5, (float(item["life"]) - t) * 1.5))
		if t >= float(item["life"]) or _season == "":
			node.queue_free()
			_decor.remove_at(i)
	if _season == "" and _decor.is_empty():
		set_process(false)


func _spawn_decor(width: float, height: float) -> void:
	var names: Array = DECOR[_season]
	var kind := str(names[_rng.randi() % names.size()])
	var path := "res://assets/pixel/seasons/%s.png" % kind
	if not ResourceLoader.exists(path):
		return
	var node := TextureRect.new()
	node.texture = load(path)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = Vector2(28.0, 28.0) * DECOR_PIXEL
	node.modulate.a = 0.0
	add_child(node)
	var speed := _rng.randf_range(70.0, 110.0)
	var item := {"node": node, "kind": kind, "t": 0.0, "phase": _rng.randf() * TAU, "freq": _rng.randf_range(0.7, 1.4),
			"amp": _rng.randf_range(26.0, 60.0), "x0": _rng.randf_range(60.0, width - 150.0), "speed": speed, "dir": 1.0, "y0": 0.0, "life": 0.0}
	if kind == "bat":
		item["dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
		item["x0"] = -100.0 if item["dir"] > 0.0 else width + 20.0
		item["y0"] = _rng.randf_range(260.0, height * 0.7)
		item["speed"] = _rng.randf_range(150.0, 230.0)
		item["amp"] = 40.0
		item["freq"] = 2.2
		item["life"] = (width + 140.0) / float(item["speed"])
		node.flip_h = item["dir"] < 0.0
	elif _season == "halloween":
		item["y0"] = height * 0.78
		item["life"] = (height * 0.78 + 100.0) / speed
	else:
		item["y0"] = -100.0
		item["life"] = (height * 0.8) / speed
	_decor.append(item)
