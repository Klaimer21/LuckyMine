class_name Artifacts
extends RefCounted
## «Артефакты» (по мотивам реликвий референса): восемь древностей четырёх редкостей. У каждой свои осколки: из «Склепа
## древних» (подземелья дня) и с хранителей башни. Набрали осколков на открытие — уровень 1, дальше уровни до 10 за
## растущее число осколков. Бонус действует всегда (не нужен слот): шаг × уровень. Уровни не сбрасываются никогда.

const LIST := [
	{"id": "pick", "name": "Кирка первого шахтёра", "rarity": 0, "effect": "hand", "step": 0.04, "text": "монеты за касания +%d%%"},
	{"id": "helmet", "name": "Старая каска", "rarity": 0, "effect": "offline", "step": 0.03, "text": "офлайн-доход +%d%%"},
	{"id": "compass", "name": "Медный компас", "rarity": 0, "effect": "trips_time", "step": 0.02, "text": "походы короче на %d%%"},
	{"id": "lamp", "name": "Фонарь рудокопа", "rarity": 1, "effect": "diamonds", "step": 0.04, "text": "алмазные жилы чаще на %d%%"},
	{"id": "abacus", "name": "Счёты казначея", "rarity": 1, "effect": "income", "step": 0.02, "text": "доход +%d%%"},
	{"id": "flint", "name": "Огниво", "rarity": 2, "effect": "dynamite", "step": 0.04, "text": "динамит приносит +%d%%"},
	{"id": "heart", "name": "Сердце горы", "rarity": 2, "effect": "strike", "step": 0.05, "text": "удар в башне и подземельях +%d%%"},
	{"id": "crown", "name": "Корона подземного короля", "rarity": 3, "effect": "income", "step": 0.05, "text": "доход +%d%%"},
]
const MAX_LEVEL := 10
const UNLOCK := [10, 15, 20, 30]                              # осколков на открытие (уровень 1) по редкости
const LEVEL_COST := [4, 6, 8, 10, 13, 16, 20, 25, 30]         # осколков на уровни 2…10 (обычная редкость)
const RARITY_COST := [1.0, 1.5, 2.0, 3.0]
const DROP_WEIGHTS := [50, 30, 15, 5]                         # какой артефакт получает случайный осколок

var shards := {}                                              # id -> накоплено осколков
var levels := {}                                              # id -> уровень (0 — не открыт)
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	for entry in LIST:
		shards[str(entry["id"])] = 0
		levels[str(entry["id"])] = 0


static func data(id: String) -> Dictionary:
	for entry in LIST:
		if str(entry["id"]) == id:
			return entry
	return {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


func unlocked_count() -> int:
	var n := 0
	for id in levels:
		if int(levels[id]) > 0:
			n += 1
	return n


## Осколков на следующий уровень (0 — максимум).
func cost_next(id: String) -> int:
	var entry := data(id)
	var lvl := level(id)
	if entry.is_empty() or lvl >= MAX_LEVEL:
		return 0
	var rarity := int(entry["rarity"])
	if lvl == 0:
		return int(UNLOCK[rarity])
	return int(ceil(float(LEVEL_COST[lvl - 1]) * float(RARITY_COST[rarity])))


func can_upgrade(id: String) -> bool:
	var cost := cost_next(id)
	return cost > 0 and int(shards.get(id, 0)) >= cost


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	shards[id] = int(shards[id]) - cost_next(id)
	levels[id] = level(id) + 1
	return true


## Сумма бонусов открытых артефактов по виду эффекта (доля).
func bonus(effect: String) -> float:
	var total := 0.0
	for entry in LIST:
		if str(entry["effect"]) == effect:
			total += float(entry["step"]) * level(str(entry["id"]))
	return total


## Случайные осколки: count штук, каждый достаётся артефакту по весу редкости. Возвращает {id: сколько}.
func drop(count: int) -> Dictionary:
	var got := {}
	for i in count:
		var total := 0
		for entry in LIST:
			total += int(DROP_WEIGHTS[int(entry["rarity"])])
		var roll := _rng.randi_range(1, total)
		for entry in LIST:
			roll -= int(DROP_WEIGHTS[int(entry["rarity"])])
			if roll <= 0:
				var id := str(entry["id"])
				shards[id] = int(shards[id]) + 1
				got[id] = int(got.get(id, 0)) + 1
				break
	return got


func any_upgradable() -> bool:
	for entry in LIST:
		if can_upgrade(str(entry["id"])):
			return true
	return false


func to_dict() -> Dictionary:
	return {"shards": shards, "levels": levels}


func from_dict(data_in: Dictionary) -> void:
	var saved_shards := ClickerState._as_dict(data_in.get("shards"))
	var saved_levels := ClickerState._as_dict(data_in.get("levels"))
	for entry in LIST:
		var id := str(entry["id"])
		shards[id] = ClickerState._count(saved_shards.get(id), 0, 1000000)
		levels[id] = ClickerState._count(saved_levels.get(id), 0, MAX_LEVEL)
