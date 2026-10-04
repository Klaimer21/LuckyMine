class_name MineTable
extends Node3D
## Рудный стол. Глыба камня падает, кувыркаясь, и разлетается о стол: крошка — частицы (считает видеокарта,
## GPUParticles3D, пул из POOL выбросов), а руда внутри — один настоящий маленький самородок или алмаз:
## он подпрыгивает, лежит, поблёскивая, и улетает искрами к счётчику. Деньги не зависят от картинки: при очень
## быстром «Камнепаде» глыбы укрупняются («×N»), а выбросы становятся мощнее.

signal landed(payout: float, real: bool)       # real = false: монеты засчитаны без глыбы (слишком много на экране)
signal collected(screen_pos: Vector2, color: Color)
signal boss_spawned(zone: int)
signal boss_defeated(zone: int)
signal boss_gone
signal boss_hit
signal golden_spawned
signal golden_hit
signal golden_missed
signal biome_changed(index: int)
signal ore_collected(ore: int)                 # находка подобрана (самородок/алмаз улетел или рассыпался сразу)
signal gem_spawned(screen_pos: Vector2, ore: int)  # из камня вылетела руда: блик
signal detonated(screen_pos: Vector2)           # взрыв динамита: волна и вспышка
signal ore_found(ore: int)                     # выпала редкая руда (золото, кристалл)

const TABLE_SIZE := Vector2(6.6, 6.2)
const GRAVITY := 34.0
const AREA := Vector2(2.6, 2.3)                # где могут упасть глыбы (полуразмеры)
const CAMERA_TARGET_Z := 0.3
const BASE_SIZE := 0.7
const BOSS_SIZE := 2.1                        # «Хранитель зоны»: большая глыба с геодой, появляется при входе в новую зону
const BOSS_GRAVITY := 7.0
const BOSS_LIFETIME := 90.0                   # через сколько секунд рассыпается сама
const BOSS_REWARD_SECONDS := 300.0            # награда монетами: секунд дохода
const GOLDEN_FIRST := 20.0                    # через сколько секунд после запуска первая золотая глыба
const GOLDEN_MIN := 50.0
const GOLDEN_MAX := 80.0
const GOLDEN_GRAVITY := 2.6                   # золотая глыба падает медленно: успеть коснуться
const GOLDEN_SIZE := 1.15
## Алмазные жилы: сколько алмазов в час «просто за игру» по зонам. Шанс у одной глыбы считается от видимой скорости
## падения, поэтому поток алмазов не растёт вместе с «Камнепадом» (иначе лавка обесценилась бы). См. tools/economy_sim.py.
const DIAMOND_PER_HOUR := [0, 140, 180, 230, 300, 400, 500]
const POOL := 64                               # выбросов частиц в пуле (по качеству используется 24 / 40 / 64)
const POOL_SIZES := [24, 40, 64]
const STONE_AMOUNT := 120
const GEM_LIMITS := [20, 30, 45]               # находок на столе одновременно
const GEM_SIZES := [0.0, 0.26, 0.26, 0.32, 0.38]   # размер самородка или алмаза по руде
const GEM_REST := [0.0, 0.7, 0.7, 1.1, 1.6]        # сколько секунд лежит на столе
const FIELD_TEXTURE := "res://assets/bg/field.png"
const BACKGROUND_BASE := "res://assets/bg/background"        # общий фон; для зоны N — background_N (png или jpg)
const FIELD_TEXTURE_ZONE := "res://assets/bg/field_%d.png"
const BACKGROUND_ZONE := "res://assets/bg/background_%d"
const BACKGROUND_PLANET := "res://assets/bg/planet%d_%d"     # свой набор фонов планеты (planet1_N — Марс); иначе фоны Земли с оттенком
const LIFETIME := 2.0
const ROCK_LIMITS := [40, 60, 90]              # глыб в воздухе одновременно по качеству
const TAP_LIMITS := [8, 12, 16]                # глыб за один «Обвал» по качеству; остальное укрупняет те же
const MAX_POPUPS := 10
const VISUAL_RATES := [10.0, 20.0, 35.0]       # глыб в секунду на картинке по качеству; выше — укрупнение целыми «×N»
const PARTICLE_RATIOS := [0.35, 0.7, 1.0]      # доля частиц в выбросе по качеству

## Руда по ценности выпавшего числа (доля от максимума): камень, медь, железо, золото, кристалл.
const ORE_LIMITS := [0.75, 0.88, 0.96]        # доля от максимума: медь, железо, золото (алмаз — только жила); руда в ~25% глыб
## Цвета руды: камень, медь, железо, золото, кристалл (алмаз).
const ORE_COLORS := [Color(0.64, 0.65, 0.62), Color(0.78, 0.47, 0.30), Color(0.50, 0.58, 0.68),
		Color(0.92, 0.74, 0.32), Color(0.55, 0.86, 0.90)]
## Породы: основной цвет глыб и крошки.
const STYLES := [Color(0.58, 0.59, 0.58), Color(0.30, 0.31, 0.34), Color(0.70, 0.60, 0.46), Color(0.82, 0.82, 0.80),
		Color(0.14, 0.13, 0.17), Color(0.22, 0.38, 0.70), Color(0.18, 0.52, 0.38),
		Color(0.80, 0.56, 0.20), Color(0.66, 0.12, 0.18), Color(0.45, 0.28, 0.62)]


class Rock extends RefCounted:
	var node: MeshInstance3D
	var x := 0.0
	var z := 0.0
	var y0 := 0.0
	var vy0 := 0.0
	var fall_time := 1.0
	var t := 0.0
	var axis := Vector3.UP
	var phi0 := 0.0
	var yaw := 0.0
	var size := BASE_SIZE
	var weight := 1.0
	var payout := 0.0
	var ore := 0
	var gravity := GRAVITY
	var golden := false


class Boss extends RefCounted:
	var node: MeshInstance3D
	var label: Label3D
	var hp := 10
	var max_hp := 10
	var zone := 1
	var y0 := 0.0
	var t := 0.0
	var fall_time := 1.0
	var landed := false
	var age := 0.0


class Gem extends RefCounted:
	var node: MeshInstance3D
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var size := 0.3
	var ore := 1
	var t := 0.0
	var bounces := 0
	var rest_time := 0.0
	var spin := Vector3.UP
	var angle := 0.0
	var weight := 1.0
	var leaving := -1.0        # >= 0: идёт «подъём» перед исчезновением


var state: ClickerState
var show_popups := true
var auto_throw := true
var quality := 1
var stress_rate := 0.0          # тест нагрузки: искусственная скорость падения глыб (0 — обычная игра)
var camera: Camera3D

var _rocks: Array[Rock] = []
var _rock_pool: Array[MeshInstance3D] = []     # скрытые узлы глыб на повторное использование
var _gems: Array[Gem] = []
var _popup_count := 0
var _sun: DirectionalLight3D
var _style := 0
var _biome := 0
var _environment: Environment
var _backdrops: Array[TextureRect] = []
var _backdrop_root: Control
var _backdrop_front := 0
var _time := 0.0
var _floor_material: StandardMaterial3D
var _floor_gradient: Gradient
var _stone_base := Color.WHITE
var _planet_tint := Color.WHITE
var _golden: Rock
var _planet := 0
var _boss: Boss
var _golden_timer := GOLDEN_FIRST
var _gold_rock_material: StandardMaterial3D
var _golden_material: StandardMaterial3D
var _gold_process: ParticleProcessMaterial
var _rng := RandomNumberGenerator.new()
var _carry := 0.0
var _shake := 0.0
var _rock_materials: Array[StandardMaterial3D] = []
var _stone_process: Array[ParticleProcessMaterial] = []
var _gem_materials: Array[StandardMaterial3D] = []
var _gem_meshes: Array[Mesh] = []
var _stone_emitters: Array[GPUParticles3D] = []
var _next_emitter := 0
var _stone_mesh_material: StandardMaterial3D


func setup(p_state: ClickerState) -> void:
	state = p_state
	_rng.randomize()
	_build_materials()
	_build_environment()
	_build_table()
	_build_emitters()


func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	if _sun != null:
		_sun.shadow_enabled = quality >= 1
		_sun.shadow_blur = [1.0, 1.6, 2.2][quality]


func set_style(index: int) -> void:
	_style = clampi(index, 0, STYLES.size() - 1)
	_refresh_palette()


## Зона шахты: цвет пола, света, пород, фон. animate — показать переход (тряска и обвал глыб).
## Планета: общий оттенок мира (пол, породы, фон, свет) поверх оттенка зоны.
func set_planet(planet: int) -> void:
	_planet = planet % Biomes.PLANETS.size()
	_planet_tint = Biomes.planet_tint(planet)
	if _backdrop_root != null:
		_backdrop_root.modulate = _planet_tint
	set_biome(_biome)


func set_biome(index: int, animate := false) -> void:
	_biome = clampi(index, 0, Biomes.LIST.size() - 1)
	var data: Dictionary = Biomes.LIST[_biome]
	if _floor_gradient != null:
		var floor_colors := PackedColorArray()
		for c in data["floor"]:
			floor_colors.append((c as Color) * _planet_tint)
		_floor_gradient.colors = floor_colors
	var zone_field := FIELD_TEXTURE_ZONE % _biome
	if ResourceLoader.exists(zone_field):
		_floor_material.albedo_texture = load(zone_field) as Texture2D
	_sun.light_color = (data["sun"] as Color).lerp(_planet_tint, 0.25)
	_stone_base = (data["tint"] as Color) * _planet_tint
	_refresh_palette()
	_apply_backdrop(not animate)
	if animate:
		celebrate()
		biome_changed.emit(_biome)
		var zone := _biome
		get_tree().create_timer(2.5).timeout.connect(func() -> void: spawn_boss(zone))


## Убирает со стола всё без выплаты: глыбы в воздухе, находки, золотую глыбу и хранителя.
## Нужно при сбросе («Новая шахта», «Новая планета»): цена глыбы фиксируется при падении, и старые
## глыбы с прежними (высокими) множителями иначе заплатили бы после сброса.
func clear_field() -> void:
	for rock in _rocks:
		_release_rock_node(rock.node)
	_rocks.clear()
	_golden = null
	for gem in _gems:
		gem.node.queue_free()
	_gems.clear()
	if _boss != null:
		_boss.node.queue_free()
		_boss.label.queue_free()
		_boss = null
	_carry = 0.0


## Праздничный обвал: тряска и 14 глыб (новая зона, «Новая шахта»).
func celebrate() -> void:
	_shake = 1.0
	for i in 14:
		_request(_rng.randf_range(-AREA.x, AREA.x), _rng.randf_range(-AREA.y, AREA.y), 1.0, true)


## Цвета пород и крошки: выбранная порода, умноженная на оттенок зоны.
func _refresh_palette() -> void:
	for i in STYLES.size():
		var base: Color = (STYLES[i] as Color) * _stone_base
		_rock_materials[i].albedo_color = base
		_stone_process[i] = _make_process(base.darkened(0.15), base.lightened(0.1), 2.0, 6.5, 0.5, 1.3, 80.0)


## Путь к картинке без расширения: сначала png, потом jpg; пустая строка, если файла нет.
func _find_image(base: String) -> String:
	for ext in ["png", "jpg"]:
		var path: String = base + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""


## Фон зоны (background_N, иначе общий background). Смена идёт плавным наплывом, при запуске — сразу.
func _apply_backdrop(instant := false) -> void:
	if _backdrops.is_empty():
		return
	var path := ""
	var own := false
	if _planet > 0:
		path = _find_image(BACKGROUND_PLANET % [_planet, _biome])
		own = path != ""
	if path == "":
		path = _find_image(BACKGROUND_ZONE % _biome)
	if path == "":
		path = _find_image(BACKGROUND_BASE)
	# свой фон планеты уже нужного цвета, остальные фоны красим оттенком планеты
	_backdrop_root.modulate = Color.WHITE if own else _planet_tint
	var texture: Texture2D = load(path) as Texture2D if path != "" else null
	var back := _backdrops[1 - _backdrop_front]
	var front := _backdrops[_backdrop_front]
	if front.texture == texture and texture != null:
		return
	back.texture = texture
	_backdrop_root.move_child(back, -1)
	if instant:
		back.modulate.a = 1.0
		front.modulate.a = 0.0
	else:
		back.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(back, "modulate:a", 1.0, 1.6)
		tween.tween_callback(func() -> void: front.modulate.a = 0.0)
	_backdrop_front = 1 - _backdrop_front


## Золотой облик глыб и крошки только у «Золотой лихорадки» (×7); малый «Золотой запал» ×2 виден лишь в шапке.
func _rush_active() -> bool:
	return state.boost_time > 0.0 and state.boost_factor >= ClickerState.BOOST_FACTOR


## Где стол на экране: прямоугольник по углам стола (для подсветки в обучении).
func screen_rect() -> Rect2:
	var a := camera.unproject_position(Vector3(-TABLE_SIZE.x * 0.5, 0.0, -TABLE_SIZE.y * 0.5))
	var b := camera.unproject_position(Vector3(TABLE_SIZE.x * 0.5, 0.0, TABLE_SIZE.y * 0.5))
	return Rect2(a, b - a).abs()


func rock_count() -> int:
	return _rocks.size()


func max_visual_rate() -> float:
	return VISUAL_RATES[quality]


# ---------- Броски ----------

## Касание экрана: глыбы падают вокруг точки стола под пальцем.
func tap(screen_pos: Vector2) -> void:
	if _golden != null:
		var golden_screen := camera.unproject_position(_golden.node.global_position)
		if golden_screen.distance_to(screen_pos) < 190.0:
			_hit_golden()
			return
	if _boss != null and _boss.landed:
		if camera.unproject_position(_boss.node.global_position).distance_to(screen_pos) < 230.0:
			hit_boss(1)
			return
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return
	var hit := origin + dir * (-origin.y / dir.y)
	_throw_batch(state.rocks_per_throw(), Vector2(hit.x, hit.z), true)


## Кнопка «Обвал»: глыбы падают в случайные места.
func throw_now() -> void:
	_throw_batch(state.rocks_per_throw(), Vector2.ZERO, false)


func _throw_batch(count: int, center: Vector2, has_center: bool) -> void:
	var shown := mini(count, TAP_LIMITS[quality])
	@warning_ignore("integer_division")
	var base := count / shown
	var extra := count % shown
	for i in shown:
		var x := _rng.randf_range(-AREA.x, AREA.x)
		var z := _rng.randf_range(-AREA.y, AREA.y)
		if has_center:
			var spread := (float(i) - (shown - 1) * 0.5) * 0.45
			x = center.x + spread + _rng.randf_range(-0.2, 0.2)
			z = center.y + _rng.randf_range(-0.35, 0.35)
		_request(x, z, float(base + (1 if i < extra else 0)), true)


func _process(delta: float) -> void:
	if state == null:
		return
	if auto_throw or stress_rate > 0.0:
		var rate := maxf(state.rain_rate() if auto_throw else 0.0, stress_rate)
		var weight := 1.0
		if rate > max_visual_rate():
			weight = ceilf(rate / max_visual_rate())
			rate /= weight
		_carry += rate * delta
		while _carry >= 1.0:
			_carry -= 1.0
			_request(_rng.randf_range(-AREA.x, AREA.x), _rng.randf_range(-AREA.y, AREA.y), weight, false)
	if stress_rate <= 0.0 and _golden == null:
		_golden_timer -= delta
		if _golden_timer <= 0.0:
			_spawn_golden()
			_golden_timer = _rng.randf_range(GOLDEN_MIN, GOLDEN_MAX) * state.golden_interval_factor()
	_step(minf(delta, 0.05))
	_step_gems(minf(delta, 0.05))
	_step_boss(minf(delta, 0.05))
	_update_shake(delta)


## Одна глыба (возможно, укрупнённая). Если на экране слишком много — монеты без картинки.
func _request(x: float, z: float, weight: float, by_hand: bool) -> void:
	var value := _rng.randi_range(1, state.max_face())
	var payout := state.payout(value) if weight <= 1.0 else weight * state.average_value()
	if _rocks.size() >= ROCK_LIMITS[quality]:
		landed.emit(payout, false)
		return
	var rock := Rock.new()
	rock.x = clampf(x, -AREA.x, AREA.x)
	rock.z = clampf(z, -AREA.y, AREA.y)
	rock.weight = weight
	rock.payout = payout
	rock.size = BASE_SIZE * clampf(1.0 + 0.22 * log(weight) / log(2.0), 1.0, 1.9) * _rng.randf_range(0.9, 1.1)
	var ratio := float(value) / float(state.max_face())
	rock.ore = 0
	for i in ORE_LIMITS.size():
		if ratio >= ORE_LIMITS[i]:
			rock.ore = i + 1
	if weight > 1.0:
		rock.ore = maxi(rock.ore, 2)       # укрупнённая глыба — всегда с рудой
	rock.ore = mini(rock.ore, int(Biomes.LIST[_biome]["max_ore"]))   # зона ограничивает редкость
	var vis_rate := minf(state.rain_rate(), max_visual_rate()) if auto_throw else 1.0
	var vein_chance := float(DIAMOND_PER_HOUR[_biome]) / 3600.0 * state.diamond_chance_factor() / maxf(vis_rate, 0.2)
	if _rng.randf() < minf(vein_chance, 0.5):
		rock.ore = 4                                                  # алмазная жила: редкая находка, вдвое-втрое дороже
		rock.payout *= 3.0
	elif _rng.randf() < state.lucky_rock_chance():
		rock.ore = maxi(rock.ore, 3)                                  # навык «Фарт шахтёра»: счастливая глыба
		rock.payout *= 5.0
	rock.vy0 = -14.0 if by_hand else -2.0
	rock.y0 = _start_height(rock.z) + rock.size
	var drop := rock.y0 - rock.size * 0.5
	rock.fall_time = (rock.vy0 + sqrt(rock.vy0 * rock.vy0 + 2.0 * GRAVITY * drop)) / GRAVITY
	rock.axis = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
	rock.phi0 = _rng.randf_range(4.0, 8.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	rock.yaw = _rng.randf_range(-PI, PI)

	rock.node = _acquire_rock_node(RockMesh.get_mesh(_rng.randi() % RockMesh.VARIANTS), 			_gold_rock_material if _rush_active() else _rock_materials[_style], rock)
	_rocks.append(rock)


func _start_height(z: float) -> float:
	var up := camera.global_transform.basis.y
	var view := get_viewport().get_visible_rect().size
	var half_height := camera.size * 0.5 * view.y / view.x
	return (half_height + 1.0 - (z - CAMERA_TARGET_Z) * up.z) / up.y


# ---------- Пул узлов глыб ----------

const ROCK_POOL_MAX := 128


## Узел для глыбы: берётся из пула или создаётся. Состояние сбрасывается полностью.
func _acquire_rock_node(mesh: Mesh, material: Material, rock: Rock) -> MeshInstance3D:
	var node: MeshInstance3D
	if _rock_pool.is_empty():
		node = MeshInstance3D.new()
		add_child(node)
	else:
		node = _rock_pool.pop_back()
	node.mesh = mesh
	node.material_override = material
	node.position = Vector3(rock.x, rock.y0, rock.z)
	node.basis = Basis.from_scale(Vector3.ONE * rock.size)
	node.visible = true
	return node


func _release_rock_node(node: MeshInstance3D) -> void:
	if _rock_pool.size() < ROCK_POOL_MAX:
		node.visible = false
		_rock_pool.append(node)
	else:
		node.queue_free()


# ---------- Шаг симуляции ----------

func _step(dt: float) -> void:
	for i in range(_rocks.size() - 1, -1, -1):
		var rock := _rocks[i]
		rock.t += dt
		if rock.t >= rock.fall_time:
			_impact(rock)
			_release_rock_node(rock.node)
			_rocks.remove_at(i)
			continue
		var y := rock.y0 + rock.vy0 * rock.t - 0.5 * rock.gravity * rock.t * rock.t
		rock.node.position = Vector3(rock.x, y, rock.z)
		var k := pow(1.0 - rock.t / rock.fall_time, 1.2)
		rock.node.basis = Basis(Vector3.UP, rock.yaw) * Basis(rock.axis, rock.phi0 * k) \
				* Basis.from_scale(Vector3.ONE * rock.size)


## Удар: глыба исчезает, на её месте выброс крошки и (если есть руда) настоящий самородок или алмаз.
func _impact(rock: Rock) -> void:
	var pos := Vector3(rock.x, rock.size * 0.45, rock.z)
	if rock.golden:
		_golden = null
		golden_missed.emit()
	_burst(pos, rock)
	landed.emit(rock.payout, true)
	if rock.ore >= 3:
		ore_found.emit(rock.ore)
	if rock.ore > 0 and _gems.size() < GEM_LIMITS[quality]:
		_spawn_gem(pos, rock)
	else:
		collected.emit(camera.unproject_position(pos), ORE_COLORS[rock.ore])
		if rock.ore > 0:
			ore_collected.emit(rock.ore)
	var rate_boost := 1.0 + 0.35 * log(maxf(state.rain_rate(), 1.0)) / log(10.0)   # чем больше добыча, тем яростнее
	_shake = minf(0.7, _shake + (0.10 + 0.07 * log(rock.weight + 1.0)) * rate_boost / (1.0 + 0.04 * _rocks.size()))
	if show_popups and _popup_count < MAX_POPUPS:
		_popup("+" + NumberFormat.short(rock.payout), pos, ORE_COLORS[rock.ore] if rock.ore > 0 else UiTheme.TEXT,
				rock.ore >= 4)


func _burst(pos: Vector3, rock: Rock) -> void:
	_burst_at(pos, rock.weight)


func _burst_at(pos: Vector3, weight: float) -> void:
	var slot := _next_emitter
	_next_emitter = (_next_emitter + 1) % POOL_SIZES[quality]
	var strength: float = clampf(0.55 + 0.15 * log(weight) / log(2.0), 0.55, 1.0) * PARTICLE_RATIOS[quality]
	var stone := _stone_emitters[slot]
	stone.global_position = pos
	stone.process_material = _gold_process if _rush_active() else _stone_process[_style]
	stone.amount_ratio = strength
	stone.restart()


# ---------- Золотая глыба и «Динамит» ----------

## Редкая золотая глыба: медленно падает, и её можно успеть коснуться (×7 на 15 секунд).
func _spawn_golden() -> void:
	var rock := Rock.new()
	rock.golden = true
	rock.size = GOLDEN_SIZE
	rock.gravity = GOLDEN_GRAVITY
	rock.x = _rng.randf_range(-AREA.x * 0.8, AREA.x * 0.8)
	rock.z = _rng.randf_range(-AREA.y * 0.8, AREA.y * 0.8)
	rock.payout = state.average_value() * 10.0      # утешительный приз, если упустили
	rock.ore = 3
	rock.vy0 = -0.4
	rock.y0 = _start_height(rock.z) + rock.size
	var drop := rock.y0 - rock.size * 0.5
	rock.fall_time = (rock.vy0 + sqrt(rock.vy0 * rock.vy0 + 2.0 * rock.gravity * drop)) / rock.gravity
	rock.axis = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
	rock.phi0 = _rng.randf_range(2.0, 3.5) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	rock.yaw = _rng.randf_range(-PI, PI)
	rock.node = _acquire_rock_node(RockMesh.get_mesh(2), _golden_material, rock)
	_rocks.append(rock)
	_golden = rock
	golden_spawned.emit()


func _hit_golden() -> void:
	var rock := _golden
	_golden = null
	var pos := rock.node.global_position
	_rocks.erase(rock)
	_release_rock_node(rock.node)
	_burst_at(pos, 8.0)
	_burst_at(pos + Vector3(0.4, 0.0, 0.2), 8.0)
	for i in 5:
		_spawn_gem_ore(pos, 3, 1.0)
	collected.emit(camera.unproject_position(pos), ORE_COLORS[3])
	landed.emit(state.average_value() * 25.0, true)
	_shake = 1.0
	golden_hit.emit()


## «Динамит»: всё, что в воздухе, разбивается сразу; находки на столе подбираются; плюс крупная награда.
func detonate() -> void:
	for i in range(_rocks.size() - 1, -1, -1):
		var rock := _rocks[i]
		if rock.golden:
			continue
		_impact(rock)
		_release_rock_node(rock.node)
		_rocks.remove_at(i)
	for gem in _gems:
		if gem.leaving < 0.0:
			gem.leaving = 0.0
			collected.emit(camera.unproject_position(gem.pos), ORE_COLORS[gem.ore])
			ore_collected.emit(gem.ore)
	for i in 8 + 4 * quality:
		_burst_at(Vector3(_rng.randf_range(-AREA.x, AREA.x), 0.4, _rng.randf_range(-AREA.y, AREA.y)), 4.0)
	# взрыв выбивает из породы руду: золото и железо, изредка алмаз
	for i in state.dynamite_finds():
		var ore := 3 if _rng.randf() < 0.4 else 2
		if _rng.randf() < 0.05 * state.diamond_chance_factor():
			ore = 4
		_spawn_gem_ore(Vector3(_rng.randf_range(-AREA.x, AREA.x) * 0.6, 0.4, _rng.randf_range(-AREA.y, AREA.y) * 0.6), ore, 1.0)
	detonated.emit(camera.unproject_position(Vector3(0.0, 0.4, 0.0)))
	if _boss != null and _boss.landed:
		hit_boss(8)
	var bonus := state.income_per_second() * state.dynamite_seconds()
	landed.emit(bonus, true)
	_popup("+" + NumberFormat.short(bonus), Vector3(0.0, 1.2, 0.0), UiTheme.BRASS, true)
	_shake = 1.6
	if state.dynamite_chain() > 0.0:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _chain_blast(bonus * state.dynamite_chain()))


## Навык «Цепной взрыв»: второй взрыв через секунду.
func _chain_blast(bonus: float) -> void:
	for i in 6:
		_burst_at(Vector3(_rng.randf_range(-AREA.x, AREA.x), 0.4, _rng.randf_range(-AREA.y, AREA.y)), 4.0)
	landed.emit(bonus, true)
	_popup("+" + NumberFormat.short(bonus), Vector3(0.0, 1.2, 0.5), UiTheme.BRASS, false)
	_shake = 0.9


# ---------- Хранитель зоны ----------

## Большая глыба с геодой: падает медленно, садится в центр и держится BOSS_LIFETIME секунд. Бейте по ней касаниями
## (динамит снимает сразу 8); внутри геода: награда монетами, поток находок и алмазы (их выдаёт main).
## Вызвать хранителя за алмазы: false, если он уже на столе.
func summon_boss(zone: int) -> bool:
	if _boss != null:
		return false
	spawn_boss(zone)
	return _boss != null


## Вызвать золотую глыбу за алмазы: false, если она уже на столе.
func summon_golden() -> bool:
	if _golden != null:
		return false
	_spawn_golden()
	_golden_timer = _rng.randf_range(GOLDEN_MIN, GOLDEN_MAX) * state.golden_interval_factor()
	return _golden != null


func spawn_boss(zone: int) -> void:
	if _boss != null or state == null:
		return
	var boss := Boss.new()
	boss.zone = zone
	boss.max_hp = maxi(4, int(round((12 + 4 * zone) * state.boss_hp_factor())))
	boss.hp = boss.max_hp
	boss.y0 = _start_height(-0.3) + BOSS_SIZE
	boss.fall_time = sqrt(2.0 * (boss.y0 - BOSS_SIZE * 0.5) / BOSS_GRAVITY)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.40, 0.40, 0.43)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = ORE_COLORS[mini(4, zone + 1)]
	material.emission_energy_multiplier = 0.22
	boss.node = MeshInstance3D.new()
	boss.node.mesh = RockMesh.get_mesh(3)
	boss.node.material_override = material
	boss.node.scale = Vector3.ONE * BOSS_SIZE
	boss.node.position = Vector3(0.0, boss.y0, -0.3)
	add_child(boss.node)
	boss.label = Label3D.new()
	boss.label.text = str(boss.hp)
	boss.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	boss.label.no_depth_test = true
	boss.label.font_size = 80
	boss.label.pixel_size = 0.009
	boss.label.outline_size = 14
	boss.label.modulate = UiTheme.BRASS
	boss.label.font = UiTheme.text_font(true)
	boss.label.visible = false
	add_child(boss.label)
	_boss = boss
	boss_spawned.emit(zone)


func _step_boss(dt: float) -> void:
	if _boss == null:
		return
	var boss := _boss
	boss.t += dt
	if not boss.landed:
		if boss.t >= boss.fall_time:
			boss.landed = true
			boss.node.position = Vector3(0.0, BOSS_SIZE * 0.5, -0.3)
			boss.label.visible = true
			_burst_at(boss.node.position, 8.0)
			_shake = 1.0
		else:
			boss.node.position.y = boss.y0 - 0.5 * BOSS_GRAVITY * boss.t * boss.t
			boss.node.rotation.y += dt * 0.8
		return
	boss.age += dt
	boss.label.global_position = boss.node.position + Vector3(0.0, BOSS_SIZE * 0.5 + 0.9, 0.0)
	if boss.age >= BOSS_LIFETIME:
		_burst_at(boss.node.position, 8.0)
		boss.node.queue_free()
		boss.label.queue_free()
		_boss = null
		boss_gone.emit()


func hit_boss(damage: int) -> void:
	if _boss == null:
		return
	var boss := _boss
	boss_hit.emit()
	boss.hp = maxi(0, boss.hp - damage)
	boss.label.text = str(boss.hp)
	_burst_at(boss.node.position + Vector3(_rng.randf_range(-0.8, 0.8), 0.4, _rng.randf_range(-0.8, 0.8)), 2.0)
	_shake = minf(1.0, _shake + 0.3)
	var tween := create_tween()
	boss.node.scale = Vector3.ONE * BOSS_SIZE * 1.09
	tween.tween_property(boss.node, "scale", Vector3.ONE * BOSS_SIZE, 0.12)
	if boss.hp <= 0:
		_break_boss()


func _break_boss() -> void:
	var boss := _boss
	_boss = null
	var pos := boss.node.position
	boss.node.queue_free()
	boss.label.queue_free()
	for i in 3:
		_burst_at(pos + Vector3(_rng.randf_range(-0.8, 0.8), 0.3, _rng.randf_range(-0.8, 0.8)), 10.0)
	var ore := mini(4, boss.zone + 1)
	for i in 4 + boss.zone:
		_spawn_gem_ore(pos, ore, 1.0)
	var payout := state.income_per_second() * BOSS_REWARD_SECONDS * state.boss_reward_factor()
	landed.emit(payout, true)
	_popup("+" + NumberFormat.short(payout), pos + Vector3(0.0, 1.6, 0.0), UiTheme.BRASS, true)
	_shake = 1.0
	boss_defeated.emit(boss.zone)


# ---------- Самородки и алмазы ----------

func _spawn_gem(pos: Vector3, rock: Rock) -> void:
	_spawn_gem_ore(pos, rock.ore, rock.weight)


func _spawn_gem_ore(pos: Vector3, ore: int, weight: float) -> void:
	var gem := Gem.new()
	gem.ore = ore
	gem.weight = weight
	gem.size = float(GEM_SIZES[ore]) * clampf(1.0 + 0.2 * log(weight) / log(2.0), 1.0, 1.6)
	gem.pos = pos + Vector3(0.0, 0.1, 0.0)
	gem.vel = Vector3(_rng.randf_range(-1.8, 1.8), _rng.randf_range(6.0, 8.5), _rng.randf_range(-1.8, 1.8))
	gem.spin = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
	gem.angle = _rng.randf() * TAU
	gem.node = MeshInstance3D.new()
	gem.node.mesh = _gem_meshes[ore]
	gem.node.material_override = _gem_materials[ore]
	gem.node.position = gem.pos
	gem.node.scale = Vector3.ONE * gem.size
	add_child(gem.node)
	_gems.append(gem)
	if ore >= 2:
		gem_spawned.emit(camera.unproject_position(pos), ore)


func _step_gems(dt: float) -> void:
	var half_x := TABLE_SIZE.x * 0.5 - 0.3
	var half_z := TABLE_SIZE.y * 0.5 - 0.3
	for i in range(_gems.size() - 1, -1, -1):
		var gem := _gems[i]
		gem.t += dt
		if gem.leaving >= 0.0:
			gem.leaving += dt
			var k := clampf(gem.leaving / 0.28, 0.0, 1.0)
			gem.node.position = gem.pos + Vector3(0.0, 1.6 * k * k, 0.0)
			gem.node.scale = Vector3.ONE * gem.size * (1.0 - k) * (1.0 + 0.5 * k)
			gem.angle += 14.0 * dt
			gem.node.basis = Basis(gem.spin, gem.angle) * Basis.from_scale(Vector3.ONE * gem.size * (1.0 - k))
			if k >= 1.0:
				gem.node.queue_free()
				_gems.remove_at(i)
			continue
		var floor_y: float = gem.size * 0.5
		if gem.bounces < 3:
			gem.vel.y -= GRAVITY * dt
			gem.pos += gem.vel * dt
			gem.pos.x = clampf(gem.pos.x, -half_x, half_x)
			gem.pos.z = clampf(gem.pos.z, -half_z, half_z)
			gem.angle += 8.0 * dt * (1.0 - gem.bounces * 0.3)
			if gem.pos.y <= floor_y:
				gem.pos.y = floor_y
				gem.vel.y = -gem.vel.y * 0.42
				gem.vel.x *= 0.55
				gem.vel.z *= 0.55
				gem.bounces += 1
				if absf(gem.vel.y) < 1.5:
					gem.bounces = 3
					gem.vel = Vector3.ZERO
		else:
			gem.pos.y = floor_y
			gem.rest_time += dt
			gem.angle += 1.3 * dt                       # медленно крутится, ловя свет
			if gem.rest_time >= float(GEM_REST[gem.ore]):
				gem.leaving = 0.0
				collected.emit(camera.unproject_position(gem.pos), ORE_COLORS[gem.ore])
				ore_collected.emit(gem.ore)
		gem.node.position = gem.pos
		gem.node.basis = Basis(gem.spin, gem.angle) * Basis.from_scale(Vector3.ONE * gem.size)


## Лёгкая тряска камеры от ударов: хаос, но недолго.
func _update_shake(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.6)
	var amount := _shake * _shake * 0.09
	var jitter := Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))
	camera.h_offset = jitter.x
	camera.v_offset = jitter.y
	# фон отстаёт от камеры и медленно «дышит»: глубина без лишних слоёв
	if _backdrop_root != null:
		_time += delta
		_backdrop_root.pivot_offset = _backdrop_root.size * 0.5
		_backdrop_root.scale = Vector2.ONE * (1.07 + 0.012 * sin(_time * 0.22))
		_backdrop_root.position = -jitter * 70.0


func _popup(text: String, at: Vector3, color: Color, big: bool) -> void:
	_popup_count += 1
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 70 if big else 52
	label.pixel_size = 0.0065
	label.outline_size = 12
	label.modulate = color
	label.font = UiTheme.text_font(true)
	add_child(label)
	label.global_position = at + Vector3(_rng.randf_range(-0.25, 0.25), 1.0, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.1, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.finished.connect(func() -> void:
			_popup_count -= 1
			label.queue_free())


# ---------- Материалы и частицы ----------

func _build_materials() -> void:
	for base in STYLES:
		var material := StandardMaterial3D.new()
		material.albedo_color = base
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		_rock_materials.append(material)
		_stone_process.append(_make_process(base.darkened(0.15), base.lightened(0.1), 2.0, 6.5, 0.5, 1.3, 80.0))
	var stone_mat := StandardMaterial3D.new()
	stone_mat.vertex_color_use_as_albedo = true
	stone_mat.roughness = 1.0
	_stone_mesh_material = stone_mat

	# золото для «лихорадки» и золотой глыбы
	_gold_rock_material = StandardMaterial3D.new()
	_gold_rock_material.albedo_color = Color(0.86, 0.68, 0.30)
	_gold_rock_material.vertex_color_use_as_albedo = true
	_gold_rock_material.metallic = 0.85
	_gold_rock_material.roughness = 0.35
	_golden_material = StandardMaterial3D.new()
	_golden_material.albedo_color = Color(0.95, 0.76, 0.30)
	_golden_material.vertex_color_use_as_albedo = true
	_golden_material.metallic = 0.95
	_golden_material.roughness = 0.2
	_golden_material.emission_enabled = true
	_golden_material.emission = Color(0.9, 0.62, 0.2)
	_golden_material.emission_energy_multiplier = 0.3
	_gold_process = _make_process(Color(0.85, 0.66, 0.26), Color(0.98, 0.85, 0.45), 2.0, 6.5, 0.5, 1.3, 80.0)

	# самородки: металл с неровной формой; алмаз: огранка с чёткими бликами
	var nugget_mesh := RockMesh.get_mesh(1)
	var diamond_mesh := GemMesh.diamond()
	for i in ORE_COLORS.size():
		var material := StandardMaterial3D.new()
		var color: Color = ORE_COLORS[i]
		material.albedo_color = color
		match i:
			1, 2:
				material.metallic = 0.75
				material.roughness = 0.38
			3:
				material.metallic = 0.95
				material.roughness = 0.24
			4:
				material.metallic = 0.15
				material.roughness = 0.06
				material.emission_enabled = true
				material.emission = color
				material.emission_energy_multiplier = 0.18
		_gem_materials.append(material)
		_gem_meshes.append(diamond_mesh if i == 4 else nugget_mesh)


func _make_process(color_a: Color, color_b: Color, speed_min: float, speed_max: float, size_min: float,
		size_max: float, spread: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.25
	m.direction = Vector3.UP
	m.spread = spread
	m.initial_velocity_min = speed_min
	m.initial_velocity_max = speed_max
	m.gravity = Vector3(0.0, -18.0, 0.0)
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.angular_velocity_min = -540.0
	m.angular_velocity_max = 540.0
	m.scale_min = size_min
	m.scale_max = size_max
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = curve
	m.scale_curve = curve_texture
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color_a, color_b])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	m.color_initial_ramp = ramp
	m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	m.collision_bounce = 0.35
	m.collision_friction = 0.8
	return m


func _build_emitters() -> void:
	# пол для частиц: тонкая коробка по размеру стола
	var floor_box := GPUParticlesCollisionBox3D.new()
	floor_box.size = Vector3(TABLE_SIZE.x, 0.4, TABLE_SIZE.y)
	floor_box.position = Vector3(0.0, -0.2, 0.0)
	add_child(floor_box)
	var shard := BoxMesh.new()
	shard.size = Vector3(0.09, 0.07, 0.11)
	shard.material = _stone_mesh_material
	for i in POOL:
		_stone_emitters.append(_make_emitter(shard, STONE_AMOUNT, _stone_process[0]))


func _make_emitter(mesh: Mesh, amount: int, process: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = LIFETIME
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.draw_pass_1 = mesh
	p.process_material = process
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 8, 12))
	add_child(p)
	return p


# ---------- Сцена ----------

func _any_background() -> bool:
	if _find_image(BACKGROUND_BASE) != "":
		return true
	for i in Biomes.LIST.size():
		if _find_image(BACKGROUND_ZONE % i) != "":
			return true
	return false


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = UiTheme.BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.9, 0.85)
	environment.ambient_light_energy = 0.4
	env.environment = environment
	add_child(env)
	# свой фон: assets/bg/background.png рисуется позади 3D-сцены (если файла нет, фон — тёмный цвет)
	_environment = environment
	if _any_background():
		environment.background_mode = Environment.BG_CANVAS
		environment.background_canvas_max_layer = -1
		var layer := CanvasLayer.new()
		layer.layer = -1
		add_child(layer)
		_backdrop_root = Control.new()
		_backdrop_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_backdrop_root)
		for i in 2:
			var backdrop := TextureRect.new()
			backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			backdrop.modulate.a = 0.0
			_backdrop_root.add_child(backdrop)
			_backdrops.append(backdrop)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	_sun.light_energy = 1.25
	_sun.light_color = Color(1.0, 0.96, 0.88)
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.6
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 7.6
	camera.near = 0.1
	camera.far = 80.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 14.0, CAMERA_TARGET_Z + 8.6), Vector3(0.0, 0.0, CAMERA_TARGET_Z))


## Поле: каменный пол шахты в раме из брёвен с железными угловыми стойками. Свой рисунок пола — assets/bg/field.png.
## Мягкая тень вокруг поля: сажает его на фон.
func _build_ground_shadow() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	var plane := PlaneMesh.new()
	plane.size = Vector2(TABLE_SIZE.x + 6.0, TABLE_SIZE.y + 6.0)
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = material
	instance.position = Vector3(0.0, -0.41, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_table() -> void:
	_build_ground_shadow()
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.10, 0.12, 0.12)
	rock.roughness = 1.0
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.25, 0.17, 0.10)
	timber.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.19, 0.20, 0.21)
	iron.metallic = 0.65
	iron.roughness = 0.45
	_add_box(Vector3(0.0, -0.2, 0.0), Vector3(TABLE_SIZE.x, 0.4, TABLE_SIZE.y), rock)
	var floor_plane := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = TABLE_SIZE
	floor_plane.mesh = plane
	_floor_material = _make_floor_material()
	floor_plane.material_override = _floor_material
	floor_plane.position = Vector3(0.0, 0.002, 0.0)
	add_child(floor_plane)

	var thickness := 0.26
	var height := 0.34
	var half_x := TABLE_SIZE.x / 2.0 + thickness / 2.0
	var half_z := TABLE_SIZE.y / 2.0 + thickness / 2.0
	_add_box(Vector3(0.0, height / 2.0 - 0.2, -half_z), Vector3(TABLE_SIZE.x + 2.0 * thickness, height, thickness), timber)
	_add_box(Vector3(0.0, height / 2.0 - 0.2, half_z), Vector3(TABLE_SIZE.x + 2.0 * thickness, height, thickness), timber)
	_add_box(Vector3(-half_x, height / 2.0 - 0.2, 0.0), Vector3(thickness, height, TABLE_SIZE.y), timber)
	_add_box(Vector3(half_x, height / 2.0 - 0.2, 0.0), Vector3(thickness, height, TABLE_SIZE.y), timber)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_add_box(Vector3(corner.x * half_x, 0.2, corner.y * half_z), Vector3(0.34, 0.8, 0.34), iron)


func _make_floor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	if ResourceLoader.exists(FIELD_TEXTURE):
		material.albedo_texture = load(FIELD_TEXTURE) as Texture2D
		return material
	# процедурная порода: тёмный сланец с прожилками
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_octaves = 5
	var gradient := Gradient.new()
	_floor_gradient = gradient
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.8, 1.0])
	gradient.colors = PackedColorArray([Color(0.10, 0.12, 0.12), Color(0.17, 0.19, 0.19),
			Color(0.24, 0.25, 0.23), Color(0.30, 0.29, 0.25)])
	var albedo := NoiseTexture2D.new()
	albedo.width = 512
	albedo.height = 512
	albedo.noise = noise
	albedo.color_ramp = gradient
	albedo.seamless = true
	material.albedo_texture = albedo
	var bump := NoiseTexture2D.new()
	bump.width = 512
	bump.height = 512
	bump.noise = noise
	bump.as_normal_map = true
	bump.bump_strength = 7.0
	bump.seamless = true
	material.normal_enabled = true
	material.normal_texture = bump
	material.normal_scale = 0.9
	material.uv1_scale = Vector3(2.0, 2.0, 1.0)
	return material


func _add_box(pos: Vector3, box_size: Vector3, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)
