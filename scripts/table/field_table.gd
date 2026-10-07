class_name FieldTable
extends Node2D
## Рудное поле, 2D: «производственная линия» на всю площадку. Из ворот выкатываются глыбы и разбиваются у дробилки
## (тут деньги засчитываются, как раньше при падении), руда и самородки едут дальше по змеевидной ленте через машины-«здания»
## (Дробилка, Конвейер, Лаборатория, Подрывник, Лебёдка, Вагонетка) в хранилище. Касание: глыбы падают под палец.
## Рисуется одним CanvasItem (спрайты, крошка квадратами), без 3D, физики и теней: лёгкое для телефонов.
## Интерфейс совпадает с прежним MineTable (сигналы и методы), поэтому main и остальные окна не меняются.

signal landed(payout: float, real: bool)       # real = false: монеты засчитаны без глыбы (слишком много на экране)
signal collected(screen_pos: Vector2, color: Color)
signal boss_spawned(zone: int)
signal boss_defeated(zone: int)
signal boss_gone
signal boss_hit
signal golden_spawned
signal tapped(screen_pos: Vector2)
signal golden_hit
signal golden_caught_at(screen_pos: Vector2)
signal golden_missed
signal biome_changed(index: int)
signal ore_collected(ore: int)
signal gem_spawned(screen_pos: Vector2, ore: int)
signal blasted
signal detonated(screen_pos: Vector2)
signal ore_found(ore: int)
signal fx_requested(kind: String, pos: Vector2, pixel: float)   # пиксельный эффект поверх поля (его рисует FxLayer в main)

const FIELD_TOP := 408.0                         # под шапкой и кнопкой «Новая шахта»
const FIELD_BOTTOM_GAP := 358.0                  # от низа экрана: нижняя панель 350 и зазор
const LEFT_FRAC := 0.10
const RIGHT_FRAC := 0.90
const CORNER := 36.0                             # срез углов ленты
const BELT_WIDTH := 40.0
## Машины, у которых на ленте есть визуальный эффект (проходящая руда); остальные просто стоят.
const BUILDINGS := {
	"crusher": [0, 0.35], "conveyor": [0, 0.74], "lab": [1, 0.66], "blaster": [2, 0.30], "winch": [2, 0.70], "cart": [3, 0.58],
}
## Где стоят здания: по ходам ленты [id, доля ширины]. Лента змейкой: слева направо, справа налево и так далее. Ходов 4;
## пятый (Марс и Луна) и шестой (Титан и Венера) добавляются, когда открыты машины этих планет.
const SLOTS := [
	[["crusher", 0.35], ["conveyor", 0.74]],
	[["lab", 0.66]],
	[["blaster", 0.30], ["winch", 0.70]],
	[["cart", 0.58]],
	[["rover", 0.20], ["compressor", 0.42], ["excavator", 0.64], ["catapult", 0.86]],
	[["reactor", 0.20], ["burner", 0.42], ["acid", 0.64], ["solar", 0.86]],
]
const BREAK_FRAC := 0.15                         # где на первом ходу глыбы разбиваются (деньги)
const GATE_X := 26.0
const ROLL_SPEED := 470.0
const ITEM_SPEED := 200.0
const GRAVITY := 2600.0
const BASE_SIZE := 64.0
const BOSS_SIZE := 280.0
const BOSS_LIFETIME := 90.0
const BOSS_REWARD_SECONDS := 300.0
const GOLDEN_FIRST := 20.0
const GOLDEN_MIN := 50.0
const GOLDEN_MAX := 80.0
const GOLDEN_SIZE := 108.0
const GOLDEN_FALL_SPEED := 130.0
const DIAMOND_PER_HOUR := [0, 140, 180, 230, 300, 400, 500]
const FIRST_DIAMOND_PITY := 240.0
const ORE_LIMITS := [0.75, 0.88, 0.96]
const GEM_LIMITS := [20, 30, 45]
const GEM_REST := [0.0, 0.7, 0.7, 1.1, 1.6]
const GEM_SIZES := [0.0, 40.0, 40.0, 48.0, 56.0]
const ROCK_LIMITS := [40, 60, 90]
const TAP_LIMITS := [8, 12, 16]
const ITEM_LIMITS := [14, 24, 36]
const CRUMB_LIMITS := [90, 150, 220]
const VISUAL_RATES := [10.0, 20.0, 35.0]       # глыб в секунду в расчёте (экономика): выше — укрупнение целыми «×N»
const DRAW_RATES := [3.0, 4.5, 6.0]            # крупных глыб в секунду на экране: расчётные глыбы склеиваются в них, итог тот же
const MAX_POPUPS := 10
const ORE_COLORS := [Color(0.64, 0.65, 0.62), Color(0.78, 0.47, 0.30), Color(0.50, 0.58, 0.68),
		Color(0.92, 0.74, 0.32), Color(0.55, 0.86, 0.90)]
const ORE_SPRITES := ["rock", "ore_copper", "ore_iron", "ore_gold", "ore_diamond"]
const STYLES := [Color(0.58, 0.59, 0.58), Color(0.30, 0.31, 0.34), Color(0.70, 0.60, 0.46), Color(0.82, 0.82, 0.80),
		Color(0.14, 0.13, 0.17), Color(0.22, 0.38, 0.70), Color(0.18, 0.52, 0.38),
		Color(0.80, 0.56, 0.20), Color(0.66, 0.12, 0.18), Color(0.45, 0.28, 0.62)]


class Rock extends RefCounted:
	var mode := 0                # 0 катится по ленте от ворот, 1 падает под палец, 2 золотая (медленно падает)
	var pos := Vector2.ZERO      # точка на земле
	var h := 0.0                 # высота над землёй (падение)
	var vh := 0.0
	var size := BASE_SIZE
	var weight := 1.0
	var payout := 0.0
	var ore := 0
	var golden := false
	var angle := 0.0
	var spin := 0.0
	var break_x := 0.0
	var t := 0.0
	var crit := 0                        # 2 — критический обвал (×5), 1 — удвоение (×2): для надписи над глыбой
	var logic_count := 1                 # сколько расчётных глыб склеено в эту (для счётчика «разбито камней»)
	var extra_ores: Array[int] = []      # руда остальных «настоящих» глыб, из которых собрана эта (учитывается при разбиении)


class Gem extends RefCounted:
	var pos := Vector2.ZERO
	var h := 0.0
	var vh := 0.0
	var vel := Vector2.ZERO
	var ore := 1
	var size := 40.0
	var bounces := 0
	var rest := 0.0
	var leaving := -1.0
	var weight := 1.0


class Boss extends RefCounted:
	var hp := 10
	var max_hp := 10
	var zone := 1
	var pos := Vector2.ZERO
	var h := 700.0
	var landed := false
	var age := 0.0
	var pulse := 0.0
	var label: Label


var state: ClickerState
var show_popups := true
var reduce_motion := false
var auto_throw := true
var quality := 1
var stress_rate := 0.0
var field := Rect2(0.0, FIELD_TOP, 1080.0, 1100.0)

var _rocks: Array[Rock] = []
var _gems: Array[Gem] = []
var _crumbs: Array[Dictionary] = []            # {pos, vel, life, max, size, color}
var _items: Array[Dictionary] = []             # визуальная руда на ленте: {kind, s, lift, lifting, passed, life}
var _boss: Boss
var _golden: Rock
var _rng := RandomNumberGenerator.new()
var _carry := 0.0
var _crusher_carry := 0.0
var _blaster_timer := 0.0
var _golden_timer := GOLDEN_FIRST
var _pity_used := false
var _shake := 0.0
var _time := 0.0
var _belt_phase := 0.0
var _popup_count := 0
var _cart_fx_cooldown := 0.0
var _item_cooldown := 0.0
var _bundles := {}                              # режим -> копится «расчётная» добыча, пока не выкатится на экран одной глыбой
var _bundle_timer := {}
var _popup_cooldown := 0.0
var _combo_label: Label
var _epoch := 0                                  # растёт при сбросе поля: отложенные вызовы сверяют его
var _glint_cooldown := 0.0

var _biome := 0
var _planet := 0
var _planet_tint := Color.WHITE
var _season_tint := Color.WHITE
var _stone_base := Color.WHITE
var _style := 0
var _floor_texture: ImageTexture
var _floor_key := ""

var _path := PackedVector2Array()              # ломаная ленты
var _lengths := PackedFloat32Array()           # длина от начала до каждой точки
var _path_length := 0.0
var _anchors: Dictionary = {}                  # id машины -> точка на ленте
var _station_s: Dictionary = {}                # id машины -> расстояние по ленте
var _break_s := 0.0
var _layout_key := ""
var _lane_count := 4
var _compact := false
var _scale := 3                                  # размер здания в пикселях холста на пиксель спрайта: 3 при четырёх ходах, 2 при пяти и шести
var _stand := 192.0                              # высота здания над лентой
var _spacing := 280.0                            # расстояние между ходами
var _decor: Array[Dictionary] = []             # украшения пола: руда в породе, камни, фонари; не мешают ленте и зданиям

var _backdrop_root: Control
var _backdrops: Array[TextureRect] = []
var _backdrop_front := 0


func setup(p_state: ClickerState) -> void:
	state = p_state
	_combo_label = UiTheme.make_label("", 44, Color(1.0, 0.85, 0.35), true)
	_combo_label.add_theme_constant_override("outline_size", 10)
	_combo_label.add_theme_color_override("font_outline_color", Color(0.04, 0.07, 0.06))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.size = Vector2(420.0, 60.0)
	_combo_label.z_index = 25
	_combo_label.visible = false
	add_child(_combo_label)
	_rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_backdrop()
	_update_layout()
	_refresh_palette()


# ---------- Внешний интерфейс (как у прежнего стола) ----------

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)


func set_style(index: int) -> void:
	_style = clampi(index, 0, STYLES.size() - 1)


func set_planet(planet: int) -> void:
	_planet = planet % Biomes.PLANETS.size()
	_planet_tint = Biomes.planet_tint(planet)
	if _backdrop_root != null:
		_backdrop_root.modulate = _planet_tint * _season_tint
	set_biome(_biome)


func set_season_tint(tint: Color) -> void:
	_season_tint = tint
	set_planet(_planet)


func set_biome(index: int, animate := false) -> void:
	_biome = clampi(index, 0, Biomes.LIST.size() - 1)
	var data: Dictionary = Biomes.LIST[_biome]
	_stone_base = (data["tint"] as Color) * _planet_tint * _season_tint
	_refresh_palette()
	if not _anchors.is_empty():
		_build_decor()
	_apply_backdrop(not animate)
	if animate:
		celebrate()
		biome_changed.emit(_biome)
		var zone := _biome
		var epoch := _epoch
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if is_inside_tree() and epoch == _epoch:
					spawn_boss(zone))


func clear_field() -> void:
	_epoch += 1                                    # отложенные взрывы и хранитель после сброса уже не платят
	_bundles.clear()
	_bundle_timer.clear()
	_rocks.clear()
	_golden = null
	_gems.clear()
	_items.clear()
	_crumbs.clear()
	if _boss != null:
		if _boss.label != null:
			_boss.label.queue_free()
		_boss = null
	_carry = 0.0


func celebrate() -> void:
	_shake = 1.0
	for i in 14:
		_drop(_random_point(), 1.0, true)


func blaster_charge() -> float:
	var interval := state.blaster_interval()
	return 0.0 if interval <= 0.0 else clampf(1.0 - _blaster_timer / interval, 0.0, 1.0)


func screen_rect() -> Rect2:
	return field


func rock_count() -> int:
	return _rocks.size()


func max_visual_rate() -> float:
	return VISUAL_RATES[quality]


## Где стоит машина на ленте (точка, на которой «стоят» её ножки): по ней main ставит ячейку машины.
## Есть ли у машины место на ленте сейчас (машины далёких планет появляются вместе с ходом ленты).
func has_building(id: String) -> bool:
	return _anchors.has(id)


func building_anchor(id: String) -> Vector2:
	return _anchors.get(id, field.get_center())


func tap(screen_pos: Vector2) -> void:
	tapped.emit(screen_pos)
	if _golden != null and _golden_screen().distance_to(screen_pos) < 150.0:
		_hit_golden()
		return
	if _boss != null and _boss.landed and (_boss.pos + Vector2(0.0, -BOSS_SIZE * 0.5)).distance_to(screen_pos) < BOSS_SIZE * 0.75:
		hit_boss(1)
		return
	state.note_tap()
	_throw_batch(state.rocks_per_throw(), screen_pos, true)


func throw_now() -> void:
	state.note_tap()
	_throw_batch(state.rocks_per_throw(), field.get_center(), false)


func detonate() -> void:
	for i in range(_rocks.size() - 1, -1, -1):
		var rock := _rocks[i]
		if rock.golden:
			continue
		_rocks.remove_at(i)
		_impact(rock)
	for gem in _gems:
		if gem.leaving < 0.0:
			gem.leaving = 0.0
			collected.emit(gem.pos, ORE_COLORS[gem.ore])
			ore_collected.emit(gem.ore)
	for i in 8 + 4 * quality:
		_burst(_random_point(), 4.0)
	for i in state.dynamite_finds():
		var ore := 3 if _rng.randf() < 0.4 else 2
		if _rng.randf() < 0.05 * state.diamond_chance_factor():
			ore = 4
		_spawn_gem_ore(_random_point(), ore, 1.0)
	var center := field.get_center()
	detonated.emit(center)
	if _boss != null and _boss.landed:
		hit_boss(8)
	var bonus := state.income_per_second() * state.dynamite_seconds()
	landed.emit(bonus, true)
	_popup("+" + NumberFormat.short(bonus), center + Vector2(0.0, -80.0), UiTheme.BRASS, true)
	_shake = 1.6
	if state.dynamite_chain() > 0.0:
		var chain_epoch := _epoch
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
				if is_inside_tree() and chain_epoch == _epoch:
					_chain_blast(bonus * state.dynamite_chain()))


func summon_boss(zone: int) -> bool:
	if _boss != null:
		return false
	spawn_boss(zone)
	return _boss != null


func summon_golden() -> bool:
	if _golden != null:
		return false
	_spawn_golden()
	_golden_timer = _rng.randf_range(GOLDEN_MIN, GOLDEN_MAX) * state.golden_interval_factor()
	return _golden != null


# ---------- Раскладка: лента, здания, пол ----------

func _update_layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var rect := Rect2(0.0, FIELD_TOP, view.x, maxf(600.0, view.y - FIELD_TOP - FIELD_BOTTOM_GAP))
	var lanes := clampi(state.field_lanes(), 4, SLOTS.size()) if state != null else 4
	var key := "%d,%d,%d" % [int(rect.size.x), int(rect.size.y), lanes]
	if key == _layout_key:
		return
	_layout_key = key
	field = rect
	_lane_count = lanes
	_scale = 3 if lanes <= 5 else 2                  # шесть ходов: здания мельче
	_compact = lanes >= 5                            # на пяти и шести ходах подпись уровня лежит на самом здании, а не под лентой
	_stand = 64.0 * _scale
	_spacing = (rect.size.y - _stand - 12.0 - 76.0) / float(lanes - 1)
	_rebuild_path()
	_floor_key = ""
	_refresh_palette()


func _lane_y(lane: int) -> float:
	return field.position.y + _stand + 12.0 + _spacing * float(lane)


## Масштаб спрайтов зданий (пикселей холста на пиксель картинки) и высота здания над лентой: по ним MachineStrip задаёт размер ячеек.
func building_scale() -> int:
	return _scale


func building_stand() -> float:
	return _stand


## Тесное поле (пять и шесть ходов): подпись уровня поверх здания.
func building_compact() -> bool:
	return _compact


func _rebuild_path() -> void:
	var xl := field.position.x + field.size.x * LEFT_FRAC
	var xr := field.position.x + field.size.x * RIGHT_FRAC
	var c := CORNER
	var points := PackedVector2Array()
	points.append(Vector2(field.position.x + GATE_X, _lane_y(0)))
	for k in _lane_count:
		var y := _lane_y(k)
		var to_right := k % 2 == 0
		var end_x := xr if to_right else xl
		var edge_x := end_x - c if to_right else end_x + c
		if k == _lane_count - 1:
			# последний ход кончается у хранилища
			points.append(Vector2(field.end.x - 72.0 if to_right else field.position.x + 72.0, y))
			break
		points.append(Vector2(edge_x, y))
		points.append(Vector2(end_x, y + c))
		points.append(Vector2(end_x, _lane_y(k + 1) - c))
		points.append(Vector2(edge_x, _lane_y(k + 1)))
	_path = points
	_lengths = PackedFloat32Array()
	var total := 0.0
	for i in _path.size():
		if i > 0:
			total += _path[i].distance_to(_path[i - 1])
		_lengths.append(total)
	_path_length = total
	_anchors.clear()
	_station_s.clear()
	for lane in _lane_count:
		for slot in SLOTS[lane]:
			var point := Vector2(field.position.x + field.size.x * float(slot[1]), _lane_y(lane))
			_anchors[str(slot[0])] = point
			_station_s[str(slot[0])] = _nearest_s(point)
	_break_s = _nearest_s(Vector2(field.position.x + field.size.x * BREAK_FRAC, _lane_y(0)))
	_build_decor()


## Украшения пола: заполняют пустые места между лентой и зданиями (руда, камни, кристаллы, фонари по зоне).
const DECOR_BY_ZONE := [
	["rock", "ore_copper", "rock", "ore_iron"],
	["ore_copper", "rock", "px_lantern", "ore_copper", "px_pickaxe"],
	["ore_iron", "rock", "px_pickaxe", "ore_iron", "px_lantern"],
	["ore_gold", "rock", "px_lantern", "ore_gold", "px_coins"],
	["px_crystal", "ore_diamond", "px_crystal", "rock"],
	["rock", "ore_gold", "px_bomb", "rock"],
	["px_crystal", "ore_diamond", "ore_gold", "px_crystal"],
]


func _build_decor() -> void:
	_decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + _biome * 31
	var names: Array = DECOR_BY_ZONE[clampi(_biome, 0, DECOR_BY_ZONE.size() - 1)]
	var blocked: Array[Rect2] = []
	for id in _anchors:
		var a: Vector2 = _anchors[id]
		blocked.append(Rect2(a + Vector2(-_stand * 0.5 - 20.0, -_stand - 12.0), Vector2(_stand + 40.0, _stand + 92.0)))
	blocked.append(Rect2(_path[0] + Vector2(-GATE_X, -90.0), Vector2(120.0, 180.0)))
	blocked.append(Rect2(_path[_path.size() - 1] + Vector2(-150.0, -70.0), Vector2(300.0, 140.0)))
	var tries := 0
	var targets: Array = [26, 26, 26, 26, 22, 14]
	var target: int = int(targets[clampi(_lane_count - 1, 0, 5)])
	while _decor.size() < target and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(field.position.x + 50.0, field.end.x - 50.0), rng.randf_range(field.position.y + 50.0, field.end.y - 50.0))
		if _distance_to_belt(p) < 70.0:
			continue
		var ok := true
		for r in blocked:
			if r.has_point(p):
				ok = false
				break
		if not ok:
			continue
		for d in _decor:
			if (d["pos"] as Vector2).distance_to(p) < 96.0:
				ok = false
				break
		if ok:
			_decor.append({"pos": p, "sprite": str(names[rng.randi() % names.size()]), "size": [48.0, 60.0, 72.0][rng.randi() % 3]})


func _distance_to_belt(p: Vector2) -> float:
	var best := INF
	for i in range(1, _path.size()):
		var a := _path[i - 1]
		var b := _path[i]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func _nearest_s(point: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var s := 0.0
	while s <= _path_length:
		var d := point_at(s).distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = s
		s += 6.0
	return best


func point_at(s: float) -> Vector2:
	s = clampf(s, 0.0, _path_length)
	for i in range(1, _path.size()):
		if s <= _lengths[i]:
			var span := _lengths[i] - _lengths[i - 1]
			return _path[i - 1].lerp(_path[i], 0.0 if span <= 0.0 else (s - _lengths[i - 1]) / span)
	return _path[_path.size() - 1]


func direction_at(s: float) -> Vector2:
	for i in range(1, _path.size()):
		if s <= _lengths[i]:
			return (_path[i] - _path[i - 1]).normalized()
	return Vector2.LEFT


func _random_point() -> Vector2:
	return Vector2(_rng.randf_range(field.position.x + 70.0, field.end.x - 70.0), _rng.randf_range(field.position.y + 90.0, field.end.y - 90.0))


## Пол поля: пиксельная «порода» цветов зоны (клетка 4 пикселя холста), строится один раз на зону и размер.
func _refresh_palette() -> void:
	var key := "%d|%s|%s|%s" % [_biome, _planet_tint.to_html(), _season_tint.to_html(), _layout_key]
	if key == _floor_key or field.size.x < 10.0:
		return
	_floor_key = key
	var data: Dictionary = Biomes.LIST[_biome]
	var colors: Array = data["floor"]
	var cell := 4
	var w := int(ceil(field.size.x / cell))
	var h := int(ceil(field.size.y / cell))
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1000 + _biome
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	var fine := FastNoiseLite.new()
	fine.seed = 77 + _biome
	fine.noise_type = FastNoiseLite.TYPE_CELLULAR
	fine.frequency = 0.11
	var tint := _planet_tint * _season_tint
	for y in h:
		for x in w:
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var f := fine.get_noise_2d(float(x), float(y))
			var level := clampf(n * 3.2 + f * 0.5 - 0.2, 0.0, 3.0)
			var base: Color = colors[clampi(int(level), 0, 3)]
			if f > 0.62 and (x + y) % 3 == 0:
				base = (colors[clampi(int(level) + 1, 0, 3)] as Color).lightened(0.08)
			image.set_pixel(x, y, Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, 1.0))
	_floor_texture = ImageTexture.create_from_image(image)


# ---------- Фон ----------

const BACKGROUND_BASE := "res://assets/bg/background"
const BACKGROUND_ZONE := "res://assets/bg/background_%d"
const BACKGROUND_PLANET := "res://assets/bg/planet%d_%d"


func _find_image(base: String) -> String:
	for ext in ["png", "jpg"]:
		var path := "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


func _build_backdrop() -> void:
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
	_backdrop_root.modulate = (Color.WHITE if own else _planet_tint) * _season_tint
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


# ---------- Шаг ----------

func _rush_active() -> bool:
	return state.boost_time > 0.0 and state.boost_factor >= ClickerState.BOOST_FACTOR


func _process(delta: float) -> void:
	if state == null:
		return
	_update_layout()
	if auto_throw or stress_rate > 0.0:
		var rate := maxf(state.rain_rate() if auto_throw else 0.0, stress_rate)
		var weight := 1.0
		if rate > max_visual_rate():
			weight = ceilf(rate / max_visual_rate())
			rate /= weight
		_carry += rate * delta
		while _carry >= 1.0:
			_carry -= 1.0
			_request(Vector2(field.position.x + GATE_X, _lane_y(0)), 0, weight, false)
	if auto_throw and stress_rate <= 0.0 and state.crusher_rate() > 0.0:
		var crusher := state.crusher_rate()
		var crusher_weight := 1.0
		var crusher_visual := max_visual_rate() * 0.5
		if crusher > crusher_visual:
			crusher_weight = ceilf(crusher / crusher_visual)
			crusher /= crusher_weight
		_crusher_carry += crusher * delta
		while _crusher_carry >= 1.0:
			_crusher_carry -= 1.0
			var spot: Vector2 = building_anchor("crusher") + Vector2(_rng.randf_range(-50.0, 50.0), _rng.randf_range(-6.0, 6.0))
			_request(spot, 1, crusher_weight, false)
	var blaster_interval := state.blaster_interval()
	if blaster_interval > 0.0 and auto_throw and stress_rate <= 0.0:
		if _blaster_timer <= 0.0 or _blaster_timer > blaster_interval:
			_blaster_timer = blaster_interval
		_blaster_timer -= delta
		if _blaster_timer <= 0.0:
			_blast()
			_blaster_timer = blaster_interval
	elif blaster_interval <= 0.0:
		_blaster_timer = 0.0
	if stress_rate <= 0.0 and _golden == null:
		_golden_timer -= delta
		if _golden_timer <= 0.0:
			_spawn_golden()
			_golden_timer = _rng.randf_range(GOLDEN_MIN, GOLDEN_MAX) * state.golden_interval_factor()
	var dt := minf(delta, 0.05)
	state.tick_combo(delta)
	_update_combo_label()
	_flush_bundles(dt)
	_popup_cooldown = maxf(0.0, _popup_cooldown - dt)
	_glint_cooldown = maxf(0.0, _glint_cooldown - dt)
	_step_rocks(dt)
	_step_gems(dt)
	_step_items(dt)
	_step_crumbs(dt)
	_step_boss(dt)
	_update_shake(delta)
	queue_redraw()


## Одна глыба (возможно, укрупнённая). mode: 0 — выкатывается из ворот и разбивается у дробилки, 1 — падает под палец.
func _request(at: Vector2, mode: int, weight: float, by_hand: bool) -> void:
	var value := _rng.randi_range(1, state.max_face())
	var payout := state.payout(value) if weight <= 1.0 else weight * state.average_value()
	if _rocks.size() >= ROCK_LIMITS[quality]:
		landed.emit(payout, false)
		return
	if by_hand:
		payout *= state.hand_payout_factor() * state.combo_bonus()      # навык «Рука» и «Серия касаний»
	var crit := 0
	if weight <= 1.0:
		# одна настоящая глыба: крит ×5 и удвоение ×2 выпадают по-настоящему; склеенные глыбы платят по среднему (то же математическое ожидание)
		if _rng.randf() < state.crit_chance():
			payout *= ClickerState.CRIT_MULT
			crit = 2
		if _rng.randf() < state.double_chance():
			payout *= 2.0
			crit = maxi(crit, 1)
	else:
		payout *= state.payout_ev()
	var rock := Rock.new()
	rock.mode = mode
	rock.pos = at
	rock.weight = weight
	rock.payout = payout
	rock.crit = crit
	rock.size = BASE_SIZE * clampf(1.0 + 0.22 * log(weight) / log(2.0), 1.0, 1.9) * _rng.randf_range(0.9, 1.1)
	var ratio := float(value) / float(state.max_face())
	rock.ore = 0
	for i in ORE_LIMITS.size():
		if ratio >= ORE_LIMITS[i] - state.ore_shift():
			rock.ore = i + 1
	if weight > 1.0:
		rock.ore = maxi(rock.ore, 2)
	rock.ore = mini(rock.ore, int(Biomes.LIST[_biome]["max_ore"]))
	var vis_rate := minf(state.total_rock_rate(), max_visual_rate()) if auto_throw else 1.0
	var vein_chance := float(DIAMOND_PER_HOUR[_biome]) / 3600.0 * state.diamond_chance_factor() / maxf(vis_rate, 0.2)
	if _rng.randf() < minf(vein_chance, 0.5):
		rock.ore = 4
		rock.payout *= 3.0
	elif _rng.randf() < state.lucky_rock_chance():
		rock.ore = maxi(rock.ore, 3)
		rock.payout *= 5.0
	if int(state.finds[4]) == 0 and not _pity_used and state.play_seconds >= FIRST_DIAMOND_PITY:
		_pity_used = true
		rock.ore = 4
		rock.payout *= 3.0
	rock.spin = _rng.randf_range(3.0, 7.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	if not by_hand:
		_bundle_add(mode, rock)                # автопоток: расчётные глыбы склеиваются в немногие крупные на экране
		return
	_launch(rock, at, mode, by_hand)


## Склейка расчётных глыб автопотока: суммируются выплата и вес, руда копится списком.
func _bundle_add(mode: int, rock: Rock) -> void:
	var bundle: Dictionary = _bundles.get(mode, {"weight": 0.0, "payout": 0.0, "ores": [], "count": 0, "crit": 0, "at": rock.pos})
	bundle["weight"] = float(bundle["weight"]) + rock.weight
	bundle["payout"] = float(bundle["payout"]) + rock.payout
	bundle["count"] = int(bundle["count"]) + 1
	bundle["crit"] = maxi(int(bundle["crit"]), rock.crit)
	if rock.ore > 0:
		(bundle["ores"] as Array).append(rock.ore)
	bundle["at"] = rock.pos
	_bundles[mode] = bundle
	if not _bundle_timer.has(mode):
		_bundle_timer[mode] = 0.0


## Выкатывает накопленное на экран одной глыбой (раз в 1 / DRAW_RATES секунд).
func _flush_bundles(dt: float) -> void:
	for mode in _bundles.keys():
		_bundle_timer[mode] = float(_bundle_timer.get(mode, 0.0)) + dt
		if _bundle_timer[mode] < 1.0 / float(DRAW_RATES[quality]):
			continue
		_bundle_timer[mode] = 0.0
		var bundle: Dictionary = _bundles[mode]
		_bundles.erase(mode)
		var rock := Rock.new()
		rock.mode = mode
		rock.weight = float(bundle["weight"])
		rock.payout = float(bundle["payout"])
		rock.logic_count = int(bundle["count"])
		rock.crit = int(bundle["crit"])
		rock.size = BASE_SIZE * clampf(1.0 + 0.22 * log(rock.weight) / log(2.0), 1.0, 1.9) * _rng.randf_range(0.9, 1.1)
		var ores: Array = bundle["ores"]
		ores.sort()
		if not ores.is_empty():
			rock.ore = int(ores.pop_back())
		for extra in ores:
			rock.extra_ores.append(int(extra))
		rock.spin = _rng.randf_range(3.0, 7.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
		_launch(rock, bundle["at"], mode, false)


## Ставит глыбу в игру: ворота (mode 0), падение рядом с Дробилкой или под палец (mode 1). Если на экране слишком много, платим без картинки.
func _launch(rock: Rock, at: Vector2, mode: int, by_hand: bool) -> void:
	if _rocks.size() >= ROCK_LIMITS[quality]:
		landed.emit(rock.payout, false)
		for ore in rock.extra_ores:
			ore_collected.emit(ore)
		if rock.ore > 0:
			ore_collected.emit(rock.ore)
		return
	rock.pos = at
	if mode == 0:
		# каждая глыба разбивается в своей точке первого хода и чуть в стороне от центра ленты: не одно место, как у автокликера
		rock.break_x = field.position.x + field.size.x * _rng.randf_range(BREAK_FRAC - 0.07, BREAK_FRAC + 0.08)
		rock.pos.y += _rng.randf_range(-14.0, 14.0)
	else:
		rock.h = (150.0 if not by_hand else 260.0) + _rng.randf_range(0.0, 60.0)
		rock.vh = -60.0 if not by_hand else -500.0
	_rocks.append(rock)


func _drop(at: Vector2, weight: float, by_hand: bool) -> void:
	_request(Vector2(clampf(at.x, field.position.x + 40.0, field.end.x - 40.0), clampf(at.y, field.position.y + 60.0, field.end.y - 60.0)), 1, weight, by_hand)


func _throw_batch(count: int, center: Vector2, has_center: bool) -> void:
	var shown := mini(count, TAP_LIMITS[quality])
	@warning_ignore("integer_division")
	var base := count / shown
	var extra := count % shown
	for i in shown:
		var at := _random_point()
		if has_center:
			at = center + Vector2((float(i) - (shown - 1) * 0.5) * 46.0 + _rng.randf_range(-14.0, 14.0), _rng.randf_range(-40.0, 40.0))
		_drop(at, float(base + (1 if i < extra else 0)), true)


func _step_rocks(dt: float) -> void:
	for i in range(_rocks.size() - 1, -1, -1):
		var rock := _rocks[i]
		rock.t += dt
		match rock.mode:
			0:
				rock.pos.x += ROLL_SPEED * dt
				rock.angle += ROLL_SPEED * dt / (rock.size * 0.5)
				if rock.pos.x >= rock.break_x:
					_rocks.remove_at(i)
					_impact(rock)
			1:
				rock.vh -= GRAVITY * dt
				rock.h += rock.vh * dt
				rock.angle += rock.spin * dt
				if rock.h <= 0.0:
					rock.h = 0.0
					_rocks.remove_at(i)
					_impact(rock)
			2:
				rock.h -= GOLDEN_FALL_SPEED * dt
				rock.angle += rock.spin * dt * 0.4
				rock.pos.x += sin(rock.t * 1.3) * 36.0 * dt
				if rock.h <= 0.0:
					rock.h = 0.0
					_rocks.remove_at(i)
					_impact(rock)


## Удар: глыба разбивается: крошка, деньги, руда (самородок подпрыгивает и улетает к счётчику), выезд руды на ленту.
func _impact(rock: Rock) -> void:
	var pos := rock.pos
	if rock.golden:
		_golden = null
		golden_missed.emit()
	_burst(pos, rock.weight)
	landed.emit(rock.payout, true)
	if rock.logic_count > 1:
		state.rocks_broken += rock.logic_count - 1       # main засчитывает одну; склеенные расчётные глыбы считаются все
	if rock.ore >= 3:
		ore_found.emit(rock.ore)
	var shown_extra := 0
	for extra in rock.extra_ores:                 # руда остальных склеенных глыб: считается, искры только у первых
		if shown_extra < 3:
			collected.emit(pos + Vector2(_rng.randf_range(-30.0, 30.0), -10.0), ORE_COLORS[extra])
			shown_extra += 1
		ore_collected.emit(extra)
		if extra >= 3:
			ore_found.emit(extra)
	if rock.ore > 0 and _gems.size() < GEM_LIMITS[quality]:
		_spawn_gem_ore(pos, rock.ore, rock.weight)
	else:
		collected.emit(pos, ORE_COLORS[rock.ore])
		if rock.ore > 0:
			ore_collected.emit(rock.ore)
	var from_s := -1.0
	if rock.mode == 0:
		from_s = _break_s
	elif absf(pos.y - _lane_y(0)) < 40.0:
		from_s = maxf(0.0, float(_station_s["crusher"]) - 30.0)         # глыбы, брошенные Дробилкой, едут дальше с неё
	if from_s >= 0.0:
		_add_item("nugget" if rock.ore > 0 or _rng.randf() < 0.6 else "rock", from_s)
	var rate_boost := 1.0 + 0.35 * log(maxf(state.total_rock_rate(), 1.0)) / log(10.0)
	_shake = minf(0.7, _shake + (0.10 + 0.07 * log(rock.weight + 1.0)) * rate_boost / (1.0 + 0.04 * _rocks.size()))
	if rock.crit > 0:
		fx_requested.emit("flash", pos + Vector2(0.0, -rock.size * 0.5), 3.0 if rock.crit == 1 else 4.0)
		_shake = maxf(_shake, 0.45 if rock.crit == 2 else 0.25)
	if show_popups and _popup_count < MAX_POPUPS and (_popup_cooldown <= 0.0 or rock.mode != 0 or rock.crit > 0):
		_popup_cooldown = 0.2
		var text := "+" + NumberFormat.short(rock.payout)
		var color: Color = ORE_COLORS[rock.ore] if rock.ore > 0 else UiTheme.TEXT
		if rock.crit == 2:
			text = "×5  " + text
			color = Color(1.0, 0.55, 0.25)
		elif rock.crit == 1:
			text = "×2  " + text
			color = Color(1.0, 0.85, 0.35)
		_popup(text, pos + Vector2(_rng.randf_range(-40.0, 40.0), -rock.size * 0.6 - _rng.randf_range(0.0, 50.0)), color, rock.ore >= 4 or rock.crit == 2)


# ---------- Крошка ----------

func _burst(pos: Vector2, weight: float) -> void:
	var count := int(clampf(10.0 + 5.0 * log(weight + 1.0) / log(2.0), 10.0, 26.0) * [0.5, 0.8, 1.0][quality])
	var base := _stone_color()
	if _rush_active():
		base = Color(0.92, 0.74, 0.32)
	for i in count:
		if _crumbs.size() >= CRUMB_LIMITS[quality]:
			return
		var angle := _rng.randf_range(-PI, 0.0) if _rng.randf() < 0.8 else _rng.randf_range(0.0, PI)
		var speed := _rng.randf_range(160.0, 520.0)
		var shade := _rng.randf_range(0.8, 1.2)
		_crumbs.append({"pos": pos, "vel": Vector2(cos(angle), sin(angle)) * speed, "life": 0.0, "max": _rng.randf_range(0.45, 0.8),
				"size": 8.0 if _rng.randf() < 0.7 else 12.0, "color": Color(base.r * shade, base.g * shade, base.b * shade)})


func _step_crumbs(dt: float) -> void:
	for i in range(_crumbs.size() - 1, -1, -1):
		var crumb := _crumbs[i]
		crumb["life"] += dt
		if crumb["life"] >= crumb["max"]:
			_crumbs.remove_at(i)
			continue
		crumb["vel"] += Vector2(0.0, 1500.0 * dt)
		crumb["pos"] += crumb["vel"] * dt


func _stone_color() -> Color:
	return (STYLES[_style] as Color) * _stone_base


# ---------- Самородки ----------

func _spawn_gem_ore(pos: Vector2, ore: int, weight: float) -> void:
	var gem := Gem.new()
	gem.ore = ore
	gem.weight = weight
	gem.size = float(GEM_SIZES[ore]) * clampf(1.0 + 0.2 * log(weight) / log(2.0), 1.0, 1.5)
	gem.pos = pos
	gem.vh = _rng.randf_range(380.0, 560.0)
	gem.vel = Vector2(_rng.randf_range(-130.0, 130.0), _rng.randf_range(-40.0, 40.0))
	_gems.append(gem)
	if ore >= 2 and (_glint_cooldown <= 0.0 or ore >= 4):
		_glint_cooldown = 0.4
		gem_spawned.emit(pos, ore)


func _step_gems(dt: float) -> void:
	for i in range(_gems.size() - 1, -1, -1):
		var gem := _gems[i]
		if gem.leaving >= 0.0:
			gem.leaving += dt
			if gem.leaving >= 0.28:
				_gems.remove_at(i)
			continue
		if gem.bounces < 3:
			gem.vh -= GRAVITY * 0.55 * dt
			gem.h += gem.vh * dt
			gem.pos += gem.vel * dt
			gem.pos.x = clampf(gem.pos.x, field.position.x + 30.0, field.end.x - 30.0)
			gem.pos.y = clampf(gem.pos.y, field.position.y + 30.0, field.end.y - 30.0)
			if gem.h <= 0.0:
				gem.h = 0.0
				gem.vh = -gem.vh * 0.42
				gem.vel *= 0.55
				gem.bounces += 1
				if absf(gem.vh) < 90.0:
					gem.bounces = 3
					gem.vh = 0.0
		else:
			gem.rest += dt
			if gem.rest >= float(GEM_REST[gem.ore]):
				gem.leaving = 0.0
				collected.emit(gem.pos, ORE_COLORS[gem.ore])
				ore_collected.emit(gem.ore)


# ---------- Лента и машины-здания: визуальный поток руды ----------

func _owned(id: String) -> bool:
	return state.machine_unlocked(id) and state.machine_level(id) > 0


func _item_speed() -> float:
	var factor := 1.0 + 0.03 * float(state.machine_level("conveyor"))
	if state.machine_boost_time > 0.0:
		factor *= 1.5
	return ITEM_SPEED * factor


func _add_item(kind: String, s: float) -> void:
	if reduce_motion or _items.size() >= ITEM_LIMITS[quality] or _item_cooldown > 0.0:
		return
	_item_cooldown = 0.28                      # не чаще нескольких штук в секунду: лента читается, а не забита
	_items.append({"kind": kind, "s": s, "lift": 0.0, "lifting": false, "passed": {}, "life": 0.0})


func _step_items(dt: float) -> void:
	_cart_fx_cooldown = maxf(0.0, _cart_fx_cooldown - dt)
	_item_cooldown = maxf(0.0, _item_cooldown - dt)
	var speed := _item_speed()
	_belt_phase += speed * dt
	for i in range(_items.size() - 1, -1, -1):
		var item := _items[i]
		item["life"] += dt
		if item["lifting"]:
			item["lift"] += dt * 140.0
			if float(item["lift"]) >= 120.0:
				_items.remove_at(i)
				continue
		else:
			item["s"] += speed * dt * (1.2 if item["kind"] != "rock" else 1.0)
		if _station_effects(item, i):
			continue
		if float(item["s"]) >= _path_length:
			_items.remove_at(i)


func _station_effects(item: Dictionary, index: int) -> bool:
	var passed: Dictionary = item["passed"]
	for id in BUILDINGS:
		if passed.has(id) or not _owned(id):
			continue
		var station_s: float = _station_s[id]
		if float(item["s"]) < station_s:
			continue
		passed[id] = true
		var world: Vector2 = _anchors[id]
		match id:
			"crusher":
				fx_requested.emit("flash", world + Vector2(0.0, -30.0), 3.0)
			"lab":
				if item["kind"] == "nugget" and _rng.randf() < 0.35:
					item["kind"] = "gem"
					fx_requested.emit("flash", world + Vector2(0.0, -40.0), 3.0)
			"winch":
				if _rng.randf() < 0.3:
					item["lifting"] = true
			"cart":
				if _cart_fx_cooldown <= 0.0:
					_cart_fx_cooldown = 1.1
					fx_requested.emit("coins", world + Vector2(0.0, -60.0), 3.0)
				if _lane_count == 4:                  # Вагонетка принимает всё, только если дальше нет ходов
					_items.remove_at(index)
					return true
	return false


# ---------- Золотая глыба, Подрывник, хранитель ----------

func _golden_screen() -> Vector2:
	return _golden.pos + Vector2(0.0, -_golden.h - _golden.size * 0.5)


func _spawn_golden() -> void:
	var rock := Rock.new()
	rock.mode = 2
	rock.golden = true
	rock.size = GOLDEN_SIZE
	rock.pos = Vector2(_rng.randf_range(field.position.x + 140.0, field.end.x - 140.0), _rng.randf_range(field.position.y + 280.0, field.end.y - 160.0))
	rock.h = rock.pos.y - field.position.y + 60.0
	rock.payout = state.average_value() * 10.0
	rock.ore = 3
	rock.spin = _rng.randf_range(1.5, 3.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	_rocks.append(rock)
	_golden = rock
	golden_spawned.emit()


func _hit_golden() -> void:
	var rock := _golden
	_golden = null
	var pos := rock.pos + Vector2(0.0, -rock.h - rock.size * 0.5)
	_rocks.erase(rock)
	_burst(pos, 8.0)
	_burst(pos + Vector2(24.0, 12.0), 8.0)
	for i in 5:
		_spawn_gem_ore(pos, 3, 1.0)
	collected.emit(pos, ORE_COLORS[3])
	golden_caught_at.emit(pos)
	landed.emit(state.average_value() * 25.0 * state.golden_payout_factor(), true)
	_shake = 1.0
	golden_hit.emit()


func _blast() -> void:
	var bonus := state.base_income_per_second() * Machines.BLASTER_SECONDS
	var at: Vector2 = building_anchor("blaster")
	for i in 4 + 2 * quality:
		_burst(at + Vector2(_rng.randf_range(-170.0, 170.0), _rng.randf_range(-120.0, 20.0)), 3.0)
	detonated.emit(at + Vector2(0.0, -50.0))
	landed.emit(bonus, true)
	_popup("+" + NumberFormat.short(bonus), at + Vector2(0.0, -170.0), UiTheme.BRASS, true)
	_shake = maxf(_shake, 0.7)
	for i in range(_items.size() - 1, -1, -1):
		if absf(float(_items[i]["s"]) - float(_station_s["blaster"])) < 110.0:
			_items.remove_at(i)
	blasted.emit()


func _chain_blast(bonus: float) -> void:
	for i in 6:
		_burst(_random_point(), 4.0)
	landed.emit(bonus, true)
	_popup("+" + NumberFormat.short(bonus), field.get_center() + Vector2(0.0, -40.0), UiTheme.BRASS, false)
	_shake = 0.9


func spawn_boss(zone: int) -> void:
	if _boss != null or state == null:
		return
	var boss := Boss.new()
	boss.zone = zone
	boss.max_hp = maxi(4, int(round((12 + 4 * zone) * state.boss_hp_factor())))
	boss.hp = boss.max_hp
	boss.pos = field.get_center() + Vector2(0.0, 40.0)
	boss.h = field.size.y * 0.6
	boss.label = UiTheme.make_label(str(boss.hp), 64, UiTheme.BRASS, true)
	boss.label.visible = false
	boss.label.z_index = 20
	boss.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss.label.size = Vector2(240.0, 80.0)
	add_child(boss.label)
	_boss = boss
	boss_spawned.emit(zone)


func _step_boss(dt: float) -> void:
	if _boss == null:
		return
	var boss := _boss
	boss.pulse = maxf(0.0, boss.pulse - dt * 7.0)
	if not boss.landed:
		boss.h -= 900.0 * dt
		if boss.h <= 0.0:
			boss.h = 0.0
			boss.landed = true
			boss.label.visible = true
			_burst(boss.pos, 8.0)
			_shake = 1.0
		return
	boss.age += dt
	boss.label.position = boss.pos + Vector2(-120.0, -BOSS_SIZE - 80.0)
	if boss.age >= BOSS_LIFETIME:
		_burst(boss.pos, 8.0)
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
	_burst(boss.pos + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-60.0, 60.0)), 2.0)
	_shake = minf(1.0, _shake + 0.3)
	boss.pulse = 1.0
	if boss.hp <= 0:
		_break_boss()


func _break_boss() -> void:
	var boss := _boss
	_boss = null
	var pos := boss.pos
	boss.label.queue_free()
	for i in 3:
		_burst(pos + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-70.0, 40.0)), 10.0)
	var ore := mini(4, boss.zone + 1)
	for i in 4 + boss.zone:
		_spawn_gem_ore(pos, ore, 1.0)
	var payout := state.income_per_second() * BOSS_REWARD_SECONDS * state.boss_reward_factor()
	landed.emit(payout, true)
	_popup("+" + NumberFormat.short(payout), pos + Vector2(0.0, -BOSS_SIZE * 0.6), UiTheme.BRASS, true)
	_shake = 1.0
	boss_defeated.emit(boss.zone)


# ---------- Тряска и числа ----------

## «Серия ×N» над полем: видна, пока идёт серия касаний и куплена «Серия касаний».
func _update_combo_label() -> void:
	var shown := int(state.levels["combo"]) > 0 and state.combo >= 3
	_combo_label.visible = shown
	if shown:
		_combo_label.text = Tr.t("Серия ×%d") % mini(state.combo, ClickerState.COMBO_MAX)
		_combo_label.position = Vector2(field.position.x + field.size.x * 0.5 - 210.0, field.position.y + 16.0)
		_combo_label.scale = Vector2.ONE * (1.0 + 0.03 * minf(float(state.combo), 25.0))
		_combo_label.pivot_offset = Vector2(210.0, 30.0)


func _update_shake(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 3.4)
	var amount := 0.0 if reduce_motion else _shake * _shake * 4.0
	position = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))
	if _backdrop_root != null:
		_time += delta
		_backdrop_root.pivot_offset = _backdrop_root.size * 0.5
		_backdrop_root.scale = Vector2.ONE * (1.07 + 0.012 * sin(_time * 0.22))
		_backdrop_root.position = -position * 2.0


func _popup(text: String, at: Vector2, color: Color, big: bool) -> void:
	_popup_count += 1
	var label := UiTheme.make_label(text, 46 if big else 36, color, true)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.07, 0.06))
	label.add_theme_constant_override("outline_size", 10)
	label.z_index = 30
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(360.0, 64.0)
	add_child(label)
	label.position = at + Vector2(_rng.randf_range(-20.0, 20.0) - 180.0, -20.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 90.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.finished.connect(func() -> void:
			_popup_count -= 1
			label.queue_free())


# ---------- Рисование ----------

func _draw() -> void:
	if state == null or field.size.x < 10.0:
		return
	_draw_floor()
	_draw_decor()
	_draw_belt()
	_draw_gate_and_vault()
	_draw_items()
	for rock in _rocks:
		_draw_rock(rock)
	if _boss != null:
		_draw_boss()
	for gem in _gems:
		_draw_gem(gem)
	for crumb in _crumbs:
		var life: float = crumb["life"] / crumb["max"]
		var color: Color = crumb["color"]
		color.a = 1.0 if life < 0.6 else (1.0 - life) / 0.4
		var side: float = crumb["size"]
		draw_rect(Rect2((crumb["pos"] as Vector2) - Vector2(side, side) * 0.5, Vector2(side, side)), color)


func _draw_floor() -> void:
	if _floor_texture != null:
		draw_texture_rect(_floor_texture, field, false)
	# рама поля: тёмное дерево с тёмной окантовкой
	var wood := Color(0.23, 0.14, 0.09)
	var dark := Color(0.04, 0.07, 0.06)
	draw_rect(field, dark, false, 4.0)
	draw_rect(field.grow(-4.0), wood, false, 12.0)
	draw_rect(field.grow(-16.0), dark, false, 4.0)


func _draw_decor() -> void:
	for d in _decor:
		var tex := Icon.sprite_for(str(d["sprite"]))
		if tex == null:
			continue
		var side: float = d["size"]
		var p: Vector2 = d["pos"]
		draw_rect(Rect2(p + Vector2(-side * 0.4, side * 0.3), Vector2(side * 0.8, side * 0.16)), Color(0, 0, 0, 0.28))
		draw_texture_rect(tex, Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(0.9, 0.9, 0.9, 1.0))


func _draw_belt() -> void:
	if _path.size() < 2:
		return
	var alive := state.machine_unlocked("crusher") or _any_machine()
	var shade := 1.0 if alive else 0.8
	draw_polyline(_path, Color(0.04, 0.07, 0.06, 0.55), BELT_WIDTH + 14.0)
	draw_polyline(_path, Color(0.17 * shade, 0.20 * shade, 0.22 * shade), BELT_WIDTH)
	draw_polyline(_path, Color(0.29, 0.33, 0.38, 0.55), BELT_WIDTH - 30.0)
	var step := 30.0
	var s := fposmod(_belt_phase, step)
	while s < _path_length:
		var p := point_at(s)
		var d := direction_at(s)
		var n := Vector2(-d.y, d.x)
		draw_line(p - n * (BELT_WIDTH * 0.5 - 4.0), p + n * (BELT_WIDTH * 0.5 - 4.0), Color(0.10, 0.13, 0.15, 0.9), 4.0)
		s += step


func _any_machine() -> bool:
	for id in BUILDINGS:
		if _owned(id):
			return true
	return false


func _draw_gate_and_vault() -> void:
	# ворота шахты в начале ленты: тёмная арка из блоков
	var gate := _path[0] + Vector2(-GATE_X, 0.0)
	var dark := Color(0.04, 0.07, 0.06)
	var stone := Color(0.30, 0.31, 0.34)
	draw_rect(Rect2(gate + Vector2(0.0, -72.0), Vector2(36.0, 120.0)), dark)
	draw_rect(Rect2(gate + Vector2(0.0, -72.0), Vector2(36.0, 16.0)), stone)
	draw_rect(Rect2(gate + Vector2(0.0, 32.0), Vector2(36.0, 16.0)), stone)
	# хранилище в конце: сундук (слева или справа от конца ленты, в зависимости от последнего хода)
	var vault := Icon.sprite_for("chest")
	if vault != null and _path.size() > 0:
		var end := _path[_path.size() - 1]
		var left_end := (_lane_count - 1) % 2 == 1
		draw_texture_rect(vault, Rect2(end + Vector2(-96.0 if left_end else 0.0, -48.0), Vector2(96.0, 96.0)), false)


func _draw_items() -> void:
	for item in _items:
		var kind: String = item["kind"]
		var tex := Icon.sprite_for("ore_diamond" if kind == "gem" else ("ore_gold" if kind == "nugget" else "ore_copper"))
		if tex == null:
			continue
		var s: float = item["s"]
		var p := point_at(s)
		var side := 28.0 if kind != "rock" else 40.0
		var bob := sin(float(item["life"]) * 9.0) * 1.5
		var lift: float = item["lift"]
		var alpha := clampf(1.0 - lift / 120.0, 0.0, 1.0)
		draw_texture_rect(tex, Rect2(p + Vector2(-side * 0.5, -side + 8.0 - lift + bob), Vector2(side, side)), false, Color(1, 1, 1, alpha))


func _draw_rock(rock: Rock) -> void:
	var tex := Icon.sprite_for("rock")
	if tex == null:
		return
	var ground := rock.pos
	var shadow := Vector2(rock.size * 0.9, rock.size * 0.28)
	if rock.mode != 0:
		draw_rect(Rect2(ground - Vector2(shadow.x * 0.5, shadow.y * 0.3), shadow), Color(0, 0, 0, 0.3 * clampf(1.0 - rock.h / 500.0, 0.2, 1.0)))
	var center := ground + Vector2(0.0, -rock.h - rock.size * 0.5)
	var tint := Color(1.0, 0.82, 0.35) if rock.golden or _rush_active() else _rock_tint()
	draw_set_transform(center, rock.angle, Vector2.ONE)
	draw_texture_rect(tex, Rect2(Vector2(-rock.size, -rock.size) * 0.5, Vector2(rock.size, rock.size)), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rock.golden:
		_draw_glow(center, rock.size, Color(1.0, 0.88, 0.35), 6.0)


## Мягкое круглое свечение (три прозрачных круга) и четыре искорки, вращающиеся вокруг: вместо квадратной рамки.
func _draw_glow(center: Vector2, size: float, color: Color, speed: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * speed)
	for k in 3:
		var c := color
		c.a = (0.10 - 0.025 * k) * (0.7 + 0.5 * pulse)
		draw_circle(center, size * (0.62 + 0.18 * k), c)
	for i in 4:
		var angle := _time * 1.6 + float(i) * TAU / 4.0
		var p := center + Vector2(cos(angle), sin(angle)) * size * 0.78
		var tw := 0.5 + 0.5 * sin(_time * 7.0 + float(i) * 1.7)
		var star := color.lightened(0.5)
		star.a = 0.5 + 0.5 * tw
		var arm := 6.0 + 4.0 * tw
		draw_rect(Rect2(p - Vector2(arm, 2.0), Vector2(arm * 2.0, 4.0)), star)
		draw_rect(Rect2(p - Vector2(2.0, arm), Vector2(4.0, arm * 2.0)), star)


func _rock_tint() -> Color:
	var base: Color = STYLES[0]
	var wanted: Color = STYLES[clampi(_style, 0, STYLES.size() - 1)]
	return Color(clampf(wanted.r / base.r, 0.0, 1.6), clampf(wanted.g / base.g, 0.0, 1.6), clampf(wanted.b / base.b, 0.0, 1.6))


func _draw_gem(gem: Gem) -> void:
	var tex := Icon.sprite_for(ORE_SPRITES[gem.ore])
	if tex == null:
		return
	var k := 0.0 if gem.leaving < 0.0 else clampf(gem.leaving / 0.28, 0.0, 1.0)
	var side := gem.size * (1.0 - 0.5 * k)
	var lift := gem.h + 90.0 * k * k
	draw_rect(Rect2(gem.pos - Vector2(side * 0.4, side * 0.1), Vector2(side * 0.8, side * 0.2)), Color(0, 0, 0, 0.25 * (1.0 - k)))
	var twinkle := 1.0 + (0.15 * sin(_time * 8.0 + gem.pos.x) if gem.bounces >= 3 and gem.leaving < 0.0 else 0.0)
	draw_texture_rect(tex, Rect2(gem.pos + Vector2(-side * 0.5, -side - lift), Vector2(side, side)), false, Color(twinkle, twinkle, twinkle, 1.0 - k))


func _draw_boss() -> void:
	var boss := _boss
	var tex := Icon.sprite_for("rock")
	if tex == null:
		return
	var ore := mini(4, boss.zone + 1)
	var scale := 1.0 + 0.09 * boss.pulse
	var side := BOSS_SIZE * scale
	var center := boss.pos + Vector2(0.0, -boss.h - BOSS_SIZE * 0.5)
	draw_rect(Rect2(boss.pos - Vector2(BOSS_SIZE * 0.5, BOSS_SIZE * 0.1), Vector2(BOSS_SIZE, BOSS_SIZE * 0.22)), Color(0, 0, 0, 0.3))
	var tint := Color(0.55, 0.55, 0.6).lerp(ORE_COLORS[ore], 0.18)
	draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false, tint)
	_draw_glow(center, side, ORE_COLORS[ore], 3.0)
