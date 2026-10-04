class_name RockMesh
extends RefCounted
## Глыба камня: икосаэдр, разбитый один раз на 80 граней, с неровным радиусом у каждой вершины и плоскими
## нормалями (гранёный вид). У каждой грани чуть свой оттенок серого (цвет вершин умножается на цвет материала).
## Вариантов несколько, чтобы камни не повторялись.

const VARIANTS := 4

static var _cache: Dictionary = {}


static func get_mesh(variant: int) -> ArrayMesh:
	var key := variant % VARIANTS
	if not _cache.has(key):
		_cache[key] = _build(1000 + key * 77)
	return _cache[key]


static func _build(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for v in [Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
			Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
			Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)]:
		verts.append((v as Vector3).normalized())
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
			[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]

	# одно разбиение: каждая грань на четыре
	var midpoints: Dictionary = {}
	var fine: Array = []
	for f in faces:
		var a: int = f[0]
		var b: int = f[1]
		var c: int = f[2]
		var ab := _midpoint(verts, midpoints, a, b)
		var bc := _midpoint(verts, midpoints, b, c)
		var ca := _midpoint(verts, midpoints, c, a)
		fine.append([a, ab, ca])
		fine.append([b, bc, ab])
		fine.append([c, ca, bc])
		fine.append([ab, bc, ca])

	# неровный радиус и приплюснутая форма
	var points: Array[Vector3] = []
	for v in verts:
		var radius := 0.72 + rng.randf() * 0.34
		points.append(v * radius * Vector3(1.0, 0.82, 0.92))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in fine:
		var pa: Vector3 = points[f[0]]
		var pb: Vector3 = points[f[1]]
		var pc: Vector3 = points[f[2]]
		var normal := (pb - pa).cross(pc - pa).normalized()
		var outward := (pa + pb + pc) / 3.0
		if normal.dot(outward) < 0.0:
			normal = -normal
		# лицевая сторона в Godot — по часовой стрелке: геометрическая нормаль смотрит внутрь
		var order := [pa, pb, pc]
		if (pb - pa).cross(pc - pa).dot(outward) > 0.0:
			order = [pa, pc, pb]
		var shade := 0.86 + rng.randf() * 0.18
		for p in order:
			st.set_color(Color(shade, shade, shade))
			st.set_normal(normal)
			st.add_vertex(p)
	return st.commit()


static func _midpoint(verts: Array[Vector3], cache: Dictionary, a: int, b: int) -> int:
	var key := mini(a, b) * 1000 + maxi(a, b)
	if cache.has(key):
		return cache[key]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1
