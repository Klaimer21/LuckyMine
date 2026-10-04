class_name GemMesh
extends RefCounted
## Огранённый алмаз единичного радиуса: плоская площадка сверху, корона, пояс и острый «кюлет» снизу.
## Грани плоские (нормали по граням), поэтому свет даёт чёткие блики.

const SIDES := 8

static var _diamond: ArrayMesh


static func diamond() -> ArrayMesh:
	if _diamond == null:
		_diamond = _build_diamond()
	return _diamond


static func _build_diamond() -> ArrayMesh:
	var crown_h := 0.38
	var pavilion_h := 0.95
	var table_r := 0.56
	var top: Array[Vector3] = []
	var girdle: Array[Vector3] = []
	for i in SIDES:
		var a := TAU * float(i) / SIDES
		top.append(Vector3(cos(a) * table_r, crown_h, sin(a) * table_r))
		var b := TAU * (float(i) + 0.5) / SIDES
		girdle.append(Vector3(cos(b), 0.0, sin(b)))
	var culet := Vector3(0.0, -pavilion_h, 0.0)
	var center := Vector3(0.0, crown_h, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SIDES:
		var j := (i + 1) % SIDES
		_tri(st, center, top[i], top[j])                  # площадка
		_tri(st, top[i], girdle[i], top[j])               # корона: треугольники и ромбы
		_tri(st, top[j], girdle[i], girdle[j])
		_tri(st, girdle[i], culet, girdle[j])             # павильон
		var prev := (i + SIDES - 1) % SIDES
		_tri(st, top[i], girdle[prev], girdle[i])
	return st.commit()


## Треугольник с плоской нормалью наружу; лицевая сторона по часовой стрелке (геометрическая нормаль внутрь).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var outward := (a + b + c) / 3.0 - Vector3(0.0, 0.1, 0.0)
	var cross := (b - a).cross(c - a)
	if cross.dot(outward) > 0.0:
		var tmp := b
		b = c
		c = tmp
		cross = (b - a).cross(c - a)
	var normal := -cross.normalized()
	for p in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(p)
