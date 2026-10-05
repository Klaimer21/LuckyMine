class_name SeasonFx
extends Control
## Частицы сезона поверх стола и под интерфейсом: зимой снег падает, на Хэллоуин поднимаются тёплые искры.
## «Меньше эффектов» отключает частицы, на низком качестве их вдвое меньше. Ввод не перехватывают.

var _snow: CPUParticles2D
var _embers: CPUParticles2D
var _reduced := false
var _quality := 1


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
