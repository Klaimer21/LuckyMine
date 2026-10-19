class_name Workshop
extends RefCounted
## «Мастерская»: исследования за монеты и реальное время. Одно исследование за раз; идёт и при закрытой игре.
## Уровни остаются навсегда (и после «Новой шахты», и после новой планеты). Цена — минуты текущего дохода,
## поэтому исследования доступны на любой стадии; время и цена удваиваются с каждым уровнем.

const RESEARCH := [
	{"id": "steel", "name": "Закалённая сталь", "text": "+5% дохода за уровень", "icon": "px_hammer", "max": 5},
	{"id": "forge", "name": "Кузница кирок", "text": "кирка копится на минуту быстрее", "icon": "px_pickaxe", "max": 5},
	{"id": "rack", "name": "Стойка для кирок", "text": "склад кирок +6", "icon": "px_rope", "max": 5},
	{"id": "maps", "name": "Карты подземелий", "text": "редкие походы попадаются чаще", "icon": "px_map", "max": 4},
	{"id": "guides", "name": "Проводники", "text": "добыча походов +10%", "icon": "px_compass", "max": 5},
	{"id": "rails", "name": "Новые рельсы", "text": "награды узкоколейки +10%", "icon": "px_cart", "max": 5},
	{"id": "powder", "name": "Пороховой склад", "text": "склад динамита +2", "icon": "px_bomb", "max": 5},
]
const BASE_SECONDS := 900.0              # первый уровень — 15 минут, дальше ×2
const BASE_COST_SECONDS := 600.0         # цена первого уровня — 10 минут дохода, дальше ×2
const MIN_COST := 1000.0
const AD_HURRY := 1800.0                 # реклама сокращает на 30 минут

var levels := {}
var active := ""                         # id идущего исследования ("" — нет)
var active_end := 0.0                    # unix-время конца
var active_total := 0.0                  # длительность (для шкалы)


func _init() -> void:
	for entry in RESEARCH:
		levels[str(entry["id"])] = 0


static func entry_of(id: String) -> Dictionary:
	for entry in RESEARCH:
		if str(entry["id"]) == id:
			return entry
	return {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


func maxed(id: String) -> bool:
	var entry := entry_of(id)
	return entry.is_empty() or level(id) >= int(entry["max"])


func seconds_for(id: String) -> float:
	return BASE_SECONDS * pow(2.0, level(id))


func cost_for(id: String, s: ClickerState) -> float:
	return maxf(MIN_COST, s.income_per_second() * BASE_COST_SECONDS * pow(2.0, level(id)))


func busy() -> bool:
	return active != ""


func remaining(now: float) -> float:
	if not busy():
		return 0.0
	return clampf(active_end - now, 0.0, active_total)       # откат часов не растягивает исследование


func ready(now: float) -> bool:
	return busy() and remaining(now) <= 0.0


func start(id: String, s: ClickerState) -> bool:
	if busy() or maxed(id):
		return false
	var cost := cost_for(id, s)
	if s.coins < cost:
		return false
	s.coins -= cost
	active = id
	active_total = seconds_for(id)
	active_end = ClickerState.now() + active_total
	return true


## Готовое исследование: уровень +1. Возвращает id (или "").
func finish(now: float) -> String:
	if not ready(now):
		return ""
	var id := active
	levels[id] = level(id) + 1
	active = ""
	active_end = 0.0
	active_total = 0.0
	return id


## Ускорить: seconds = INF — закончить сразу.
func hurry(seconds: float) -> bool:
	if not busy() or ready(ClickerState.now()):
		return false
	active_end = ClickerState.now() if seconds == INF else active_end - seconds
	return true


## Цена мгновенного завершения в алмазах: 2 за каждый начатый час.
func hurry_cost(now: float) -> int:
	return maxi(2, 2 * ceili(remaining(now) / 3600.0))


## Всего изученных уровней (для достижения «Инженер»).
func total_levels() -> int:
	var total := 0
	for id in levels:
		total += int(levels[id])
	return total


func income_factor() -> float:
	return 1.0 + 0.05 * level("steel")


func to_dict() -> Dictionary:
	return {"levels": levels, "active": active, "active_end": active_end, "active_total": active_total}


func from_dict(data: Dictionary) -> void:
	var saved := ClickerState._as_dict(data.get("levels"))
	for entry in RESEARCH:
		var id := str(entry["id"])
		levels[id] = ClickerState._count(saved.get(id), 0, int(entry["max"]))
	active = str(data.get("active", ""))
	if entry_of(active).is_empty() or maxed(active):
		active = ""
	active_total = clampf(ClickerState._num(data.get("active_total"), 0.0), 0.0, BASE_SECONDS * 64.0)
	active_end = ClickerState._num(data.get("active_end"), 0.0)
	if active == "":
		active_end = 0.0
		active_total = 0.0
