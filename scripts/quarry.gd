class_name Quarry
extends RefCounted
## «Забой», «Старьёвщик» и «Наряд дня»: всё, что тратит кирки и обновляется по дням.
## Забой — поле COLS×ROWS глыб; каждый удар кирки снимает одну крепость. Копать можно верхний ряд и соседей открытых
## клеток (сверху вниз, как в настоящем забое). Под глыбами добыча и один лаз на следующий ярус; рядом с лазом из открытой
## клетки тянет сквозняком. Кирки копятся по реальному времени (и при закрытой игре) до PICK_CAP.
## Старьёвщик — четыре товара за алмазы со случайным количеством и скидкой, новый набор каждые сутки (UTC).
## Наряд дня — очки за действия; тема дня недели даёт за свои действия втрое больше; три сундука за пороги.
## Состояние сохраняется внутри ClickerState (to_dict / from_dict); награды начисляются через него же.

const COLS := 5
const ROWS := 6
const PICK_SECONDS := 600.0              # одна кирка за 10 минут
const PICK_CAP := 30                     # дальше сами не копятся (купленные и наградные — сверх)
const START_PICKS := 15
const AD_PICKS := 5

## Что лежит под глыбой: вес выпадения. exit (лаз) кладётся отдельно, ровно один на ярус.
const LOOT_WEIGHTS := {"": 38, "coins": 28, "finds": 16, "diamonds": 10, "dynamite": 6, "chest": 2}
const COINS_SECONDS := 180.0             # монеты в клетке: столько секунд текущего дохода (растёт с ярусом)
const CHEST_SECONDS := 1200.0
const LAYER_STEP := 0.08                 # +8% к монетам за каждый ярус
const CHEST_EVERY := 5                   # за каждый 5-й ярус сундук при спуске

## Старьёвщик: товар -> {количество от, до, шаг; цена за единицу в алмазах × (1 + зона); вес}.
const JUNK_GOODS := {
	"picks": {"min": 5, "max": 15, "step": 5, "unit": 0.5, "weight": 30},
	"dynamite": {"min": 2, "max": 6, "step": 2, "unit": 0.9, "weight": 20},
	"finds": {"min": 20, "max": 60, "step": 20, "unit": 0.08, "weight": 20},
	"coins": {"min": 1, "max": 3, "step": 1, "unit": 3.0, "weight": 20},
	"rush": {"min": 1, "max": 1, "step": 1, "unit": 5.0, "weight": 7},
	"skill_point": {"min": 1, "max": 1, "step": 1, "unit": 12.0, "weight": 3},
}
const JUNK_SLOTS := 4
const JUNK_DISCOUNTS := [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35]

## Наряд дня: очки за действие; тема дня (понедельник = 0) утраивает очки своих действий, воскресенье удваивает все.
const RUSH_POINTS := {"pick": 2, "dynamite": 5, "golden": 10, "boss": 20, "expedition": 15, "junk": 5, "layer": 10}
const RUSH_THEMES := [
	{"name": "День кирки", "actions": ["pick", "layer"]},
	{"name": "День подрывника", "actions": ["dynamite"]},
	{"name": "Золотая среда", "actions": ["golden"]},
	{"name": "День хранителя", "actions": ["boss"]},
	{"name": "День походов", "actions": ["expedition"]},
	{"name": "Базарный день", "actions": ["junk", "pick"]},
	{"name": "Воскресный аврал", "actions": []},
]
const RUSH_THEME_FACTOR := 3
const RUSH_SUNDAY_FACTOR := 2
const RUSH_GOALS := [60, 150, 300]

var picks := START_PICKS
var pick_clock := 0.0                    # unix-время, от которого считается следующая кирка
var layer := 1
var best_layer := 1
var hp: Array = []                       # крепость клеток (0 — открыта)
var loot: Array = []                     # что под клеткой: "", coins, finds, diamonds, dynamite, chest, exit
var hits := 0                            # всего ударов (для достижения и статистики)

var junk_day := -1
var junk_slots: Array = []               # [{item, count, discount, sold}]
var junk_refreshes := 0                  # обновлений в этот день (меняет набор)

var rush_day := -1
var rush_points := 0
var rush_claimed := 0                    # битовая маска полученных сундуков

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	new_layer()


# ---------- Кирки ----------

## Начисляет кирки за прошедшее время. Откат часов назад не даёт лишних кирок.
func tick_picks(now: float) -> void:
	if pick_clock <= 0.0 or now < pick_clock:
		pick_clock = now
	if picks >= PICK_CAP:
		pick_clock = now
		return
	var gained := floori((now - pick_clock) / PICK_SECONDS)
	if gained <= 0:
		return
	picks = mini(PICK_CAP, picks + gained)
	pick_clock = now if picks >= PICK_CAP else pick_clock + gained * PICK_SECONDS


## Секунд до следующей кирки (0, если склад полон).
func pick_wait(now: float) -> float:
	if picks >= PICK_CAP:
		return 0.0
	return clampf(pick_clock + PICK_SECONDS - now, 0.0, PICK_SECONDS)


# ---------- Забой ----------

func index(col: int, row: int) -> int:
	return row * COLS + col


## Новый ярус: крепость растёт с глубиной, лаз — в нижней половине поля.
func new_layer() -> void:
	hp.clear()
	loot.clear()
	var hard2 := minf(0.12 + 0.03 * layer, 0.45)
	var hard3 := minf(0.015 * layer, 0.25)
	var total := 0
	for w in LOOT_WEIGHTS.values():
		total += int(w)
	for i in COLS * ROWS:
		var roll := _rng.randf()
		hp.append(3 if roll < hard3 else (2 if roll < hard3 + hard2 else 1))
		var pick := _rng.randi_range(1, total)
		var acc := 0
		var kind := ""
		for key in LOOT_WEIGHTS:
			acc += int(LOOT_WEIGHTS[key])
			if pick <= acc:
				kind = str(key)
				break
		loot.append(kind)
	var exit_row := _rng.randi_range(floori(ROWS / 2.0), ROWS - 1)
	loot[index(_rng.randi_range(0, COLS - 1), exit_row)] = "exit"


func is_open(i: int) -> bool:
	return int(hp[i]) <= 0


## Клетку можно бить: верхний ряд или рядом (по стороне) с открытой.
func can_dig(i: int) -> bool:
	if i < 0 or i >= hp.size() or is_open(i):
		return false
	var col := i % COLS
	var row := floori(i / float(COLS))
	if row == 0:
		return true
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: int = col + d.x
		var r: int = row + d.y
		if c >= 0 and c < COLS and r >= 0 and r < ROWS and is_open(index(c, r)):
			return true
	return false


## Из открытой клетки тянет сквозняком: лаз ещё закрыт и лежит по соседству (включая диагональ).
func draft_at(i: int) -> bool:
	if not is_open(i) or exit_open():
		return false
	var col := i % COLS
	var row := floori(i / float(COLS))
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var c: int = col + dc
			var r: int = row + dr
			if (dc != 0 or dr != 0) and c >= 0 and c < COLS and r >= 0 and r < ROWS and str(loot[index(c, r)]) == "exit":
				return true
	return false


func exit_open() -> bool:
	for i in loot.size():
		if str(loot[i]) == "exit":
			return is_open(i)
	return false


## Удар кирки по клетке. Возвращает {} (нельзя) или {"opened": bool, "kind", награды…}.
func dig(i: int, s: ClickerState) -> Dictionary:
	tick_picks(ClickerState.now())
	if picks <= 0 or not can_dig(i):
		return {}
	picks -= 1
	hits += 1
	note("pick")
	hp[i] = int(hp[i]) - 1
	if not is_open(i):
		return {"opened": false, "left": int(hp[i])}
	var result := grant(str(loot[i]), s)
	result["opened"] = true
	return result


## Монеты клетки на текущем ярусе.
func coins_for(seconds: float, s: ClickerState) -> float:
	return maxf(100.0, s.income_per_second() * seconds) * (1.0 + LAYER_STEP * (layer - 1))


## Выдаёт содержимое клетки (или сундука) и возвращает, что выдано.
func grant(kind: String, s: ClickerState) -> Dictionary:
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	var result := {"kind": kind}
	match kind:
		"coins":
			var amount := coins_for(COINS_SECONDS, s)
			s.add_coins(amount)
			result["coins"] = amount
		"finds":
			var ore := _rng.randi_range(1, mini(3, 1 + zone))
			var count := _rng.randi_range(3, 6)
			s.finds[ore] = int(s.finds[ore]) + count
			result["ore"] = ore
			result["count"] = count
		"diamonds":
			var gems := 2 + zone
			s.diamonds += gems
			result["diamonds"] = gems
		"dynamite":
			result["dynamite"] = s.add_dynamite(1)
		"chest":
			var amount := coins_for(CHEST_SECONDS, s)
			s.add_coins(amount)
			var gems := 5 + zone
			s.diamonds += gems
			picks += 3
			result["coins"] = amount
			result["diamonds"] = gems
			result["picks"] = 3
	return result


## Спуск в открытый лаз: новый ярус; за каждый CHEST_EVERY-й — сундук. Возвращает награду ({} — лаз закрыт).
func descend(s: ClickerState) -> Dictionary:
	if not exit_open():
		return {}
	layer += 1
	best_layer = maxi(best_layer, layer)
	note("layer")
	new_layer()
	var result := {"layer": layer}
	if layer % CHEST_EVERY == 0:
		result.merge(grant("chest", s))
	return result


# ---------- Старьёвщик ----------

func junk_refresh_if_new_day() -> void:
	var day := ClickerState.today()
	if day != junk_day:
		junk_day = day
		junk_refreshes = 0
		_roll_junk()


## Набор зависит только от дня и числа обновлений: перезапуск игры его не меняет.
func _roll_junk() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(junk_day * 31 + junk_refreshes * 7919 + 17)
	var pool: Array = JUNK_GOODS.keys()
	junk_slots.clear()
	while junk_slots.size() < JUNK_SLOTS and not pool.is_empty():
		var total := 0
		for key in pool:
			total += int(JUNK_GOODS[key]["weight"])
		var roll := rng.randi_range(1, total)
		var acc := 0
		for key in pool:
			acc += int(JUNK_GOODS[key]["weight"])
			if roll <= acc:
				var good: Dictionary = JUNK_GOODS[key]
				var steps := floori(float(int(good["max"]) - int(good["min"])) / float(good["step"]))
				var count := int(good["min"]) + rng.randi_range(0, steps) * int(good["step"])
				var discount: float = JUNK_DISCOUNTS[rng.randi_range(0, JUNK_DISCOUNTS.size() - 1)]
				junk_slots.append({"item": str(key), "count": count, "discount": discount, "sold": false,
						"ore": rng.randi_range(1, 3)})
				pool.erase(key)
				break


func junk_price(slot: int, s: ClickerState) -> int:
	if slot < 0 or slot >= junk_slots.size():
		return 0
	var entry: Dictionary = junk_slots[slot]
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	var full := float(entry["count"]) * float(JUNK_GOODS[str(entry["item"])]["unit"]) * (1.0 + zone)
	return maxi(1, int(round(full * (1.0 - float(entry["discount"])))))


func junk_full_price(slot: int, s: ClickerState) -> int:
	var entry: Dictionary = junk_slots[slot]
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	return maxi(1, int(round(float(entry["count"]) * float(JUNK_GOODS[str(entry["item"])]["unit"]) * (1.0 + zone))))


## Цена нового набора растёт с каждым обновлением за день: пересматривать товар можно, скупать всё подряд — дорого.
func junk_refresh_cost(s: ClickerState) -> int:
	return 3 * (1 + Biomes.index_for(s.total_earned, s.planet_scale())) * (1 + junk_refreshes)


## Новый набор товаров (за алмазы или за рекламу: тогда pay = false).
func junk_reroll(s: ClickerState, pay := true) -> bool:
	junk_refresh_if_new_day()
	if pay:
		var cost := junk_refresh_cost(s)
		if s.diamonds < cost:
			return false
		s.diamonds -= cost
	junk_refreshes += 1
	_roll_junk()
	return true


func junk_buy(slot: int, s: ClickerState) -> Dictionary:
	junk_refresh_if_new_day()
	if slot < 0 or slot >= junk_slots.size() or bool(junk_slots[slot]["sold"]):
		return {}
	var price := junk_price(slot, s)
	if s.diamonds < price:
		return {}
	var entry: Dictionary = junk_slots[slot]
	var count := int(entry["count"])
	var result := {"item": str(entry["item"]), "count": count}
	match str(entry["item"]):
		"picks":
			picks += count
		"dynamite":
			result["count"] = s.add_dynamite(count)
			if int(result["count"]) <= 0:
				return {}                                   # склад полон: не продаём впустую
		"finds":
			var ore := int(entry.get("ore", 1))
			s.finds[ore] = int(s.finds[ore]) + count
			result["ore"] = ore
		"coins":
			var amount := maxf(100.0, s.income_per_second() * 3600.0 * count)
			s.add_coins(amount)
			result["coins"] = amount
		"rush":
			s.start_rush(ClickerState.RUSH_LONG_SECONDS)
		"skill_point":
			s.skill_points += count
	s.diamonds -= price
	entry["sold"] = true
	note("junk")
	return result


# ---------- Наряд дня ----------

static func weekday() -> int:
	return (ClickerState.today() + 3) % 7         # 1 января 1970 — четверг; понедельник = 0


func _rush_roll_day() -> void:
	var day := ClickerState.today()
	if day != rush_day:
		rush_day = day
		rush_points = 0
		rush_claimed = 0


func rush_theme() -> Dictionary:
	return RUSH_THEMES[weekday()]


func rush_factor(action: String) -> int:
	var day := weekday()
	if day == 6:
		return RUSH_SUNDAY_FACTOR
	return RUSH_THEME_FACTOR if (RUSH_THEMES[day]["actions"] as Array).has(action) else 1


## Действие засчитано: очки наряда (с множителем темы дня).
func note(action: String, times := 1) -> void:
	_rush_roll_day()
	rush_points += int(RUSH_POINTS.get(action, 0)) * rush_factor(action) * times


func rush_now_points() -> int:
	_rush_roll_day()
	return rush_points


func rush_claimable(step: int) -> bool:
	_rush_roll_day()
	return step >= 0 and step < RUSH_GOALS.size() and rush_points >= int(RUSH_GOALS[step]) and (rush_claimed & (1 << step)) == 0


func rush_claimed_step(step: int) -> bool:
	_rush_roll_day()
	return (rush_claimed & (1 << step)) != 0


func rush_any_claimable() -> bool:
	for step in RUSH_GOALS.size():
		if rush_claimable(step):
			return true
	return false


## Сундук наряда: 1-й — кирки, 2-й — алмазы и динамит, 3-й — кирки, алмазы и час дохода.
func rush_claim(step: int, s: ClickerState) -> Dictionary:
	if not rush_claimable(step):
		return {}
	rush_claimed |= 1 << step
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	var result := {}
	match step:
		0:
			picks += 5
			result["picks"] = 5
		1:
			s.diamonds += 3 + zone
			result["diamonds"] = 3 + zone
			result["dynamite"] = s.add_dynamite(2)
		_:
			picks += 10
			s.diamonds += 5 + 2 * zone
			var amount := maxf(100.0, s.income_per_second() * 3600.0)
			s.add_coins(amount)
			result["picks"] = 10
			result["diamonds"] = 5 + 2 * zone
			result["coins"] = amount
	return result


# ---------- Сохранение ----------

func to_dict() -> Dictionary:
	return {"picks": picks, "pick_clock": pick_clock, "layer": layer, "best_layer": best_layer, "hp": hp, "loot": loot,
			"hits": hits, "junk_day": junk_day, "junk_slots": junk_slots, "junk_refreshes": junk_refreshes,
			"rush_day": rush_day, "rush_points": rush_points, "rush_claimed": rush_claimed}


func from_dict(data: Dictionary) -> void:
	picks = ClickerState._count(data.get("picks"), START_PICKS, 100000)
	pick_clock = ClickerState._num(data.get("pick_clock"), 0.0)
	layer = maxi(1, ClickerState._count(data.get("layer"), 1, 1000000))
	best_layer = maxi(layer, ClickerState._count(data.get("best_layer"), 1, 1000000))
	hits = ClickerState._count(data.get("hits"), 0)
	var saved_hp := ClickerState._as_array(data.get("hp"))
	var saved_loot := ClickerState._as_array(data.get("loot"))
	if saved_hp.size() == COLS * ROWS and saved_loot.size() == COLS * ROWS and saved_loot.has("exit"):
		hp = []
		loot = []
		for i in COLS * ROWS:
			hp.append(clampi(int(ClickerState._num(saved_hp[i], 1.0)), 0, 3))
			var kind := str(saved_loot[i])
			loot.append(kind if kind == "exit" or LOOT_WEIGHTS.has(kind) else "")
	else:
		new_layer()
	junk_day = int(ClickerState._num(data.get("junk_day"), -1.0))
	junk_refreshes = ClickerState._count(data.get("junk_refreshes"), 0, 100000)
	junk_slots = []
	for entry in ClickerState._as_array(data.get("junk_slots")):
		if typeof(entry) == TYPE_DICTIONARY and JUNK_GOODS.has(str(entry.get("item", ""))):
			var good: Dictionary = JUNK_GOODS[str(entry["item"])]
			junk_slots.append({"item": str(entry["item"]),
					"count": clampi(int(ClickerState._num(entry.get("count"), 1.0)), int(good["min"]), int(good["max"])),
					"discount": clampf(ClickerState._num(entry.get("discount"), 0.0), 0.0, 0.35),
					"sold": bool(entry.get("sold", false)), "ore": clampi(int(ClickerState._num(entry.get("ore"), 1.0)), 1, 3)})
	if junk_slots.size() != JUNK_SLOTS:
		junk_day = -1                            # набор повреждён: при открытии лавки соберётся заново
	rush_day = int(ClickerState._num(data.get("rush_day"), -1.0))
	rush_points = ClickerState._count(data.get("rush_points"), 0)
	rush_claimed = clampi(int(ClickerState._num(data.get("rush_claimed"), 0.0)), 0, (1 << RUSH_GOALS.size()) - 1)
