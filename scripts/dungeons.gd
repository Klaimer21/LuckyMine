class_name Dungeons
extends RefCounted
## «Подземелья дня» (по мотивам ежедневных подземелий референса): три подземелья, у каждого своя награда и свои уровни.
## Вход — ключ (два в день на каждое). Бой как в башне: разбить глыбу за время; правило дня меняет условия.
## Победа открывает следующий уровень и тратит ключ, поражение ключ не тратит. Пройденный уровень можно «зачистить»
## без боя (за ключ) — награда лучшего уровня. Награды растут с уровнем линейно.

const LIST := [
	{"id": "adit", "name": "Затопленная штольня", "reward": "coins", "icon": "px_rope", "text": "монеты и кирки"},
	{"id": "grotto", "name": "Кристальный грот", "reward": "gems", "icon": "gem", "text": "алмазы и приманки"},
	{"id": "crypt", "name": "Склеп древних", "reward": "shards", "icon": "px_scroll", "text": "осколки артефактов"},
]
const KEYS := 2
const BASE_HP := 120.0
const HP_GROWTH := 1.12
const SECONDS := 20.0
## Правило дня (понедельник = 0): прочность, время, доля динамита (0 — не работает), каждое N-е касание ×3, множитель награды.
const RULES := [
	{"name": "Каменная кожа", "text": "прочность ×1.5, но 25 секунд", "hp": 1.5, "seconds": 25.0},
	{"name": "Хрупкая порода", "text": "динамит снимает половину прочности", "dynamite": 0.5},
	{"name": "Спешка", "text": "12 секунд, но прочность ×0.6", "hp": 0.6, "seconds": 12.0},
	{"name": "Трещины", "text": "каждое 8-е касание бьёт втрое", "crit_every": 8},
	{"name": "Сырые стены", "text": "динамит не горит, прочность ×0.8", "hp": 0.8, "dynamite": 0.0},
	{"name": "Ярмарка", "text": "награда ×1.5", "reward": 1.5},
	{"name": "Праздник рудокопа", "text": "награда ×2", "reward": 2.0},
]

var best := {}                                 # id -> лучший пройденный уровень
var keys := {}                                 # id -> ключей на сегодня
var keys_day := -1


func _init() -> void:
	for entry in LIST:
		best[str(entry["id"])] = 0
		keys[str(entry["id"])] = KEYS


static func data(id: String) -> Dictionary:
	for entry in LIST:
		if str(entry["id"]) == id:
			return entry
	return {}


static func rule() -> Dictionary:
	return RULES[Quarry.weekday()]


func _roll_day() -> void:
	var day := ClickerState.today()
	if day != keys_day:
		keys_day = day
		for entry in LIST:
			var id := str(entry["id"])
			keys[id] = maxi(int(keys.get(id, 0)), KEYS)       # ключи сверх двух (реклама) не сгорают


func keys_left(id: String) -> int:
	_roll_day()
	return int(keys.get(id, 0))


func add_keys(amount: int) -> void:
	_roll_day()
	for entry in LIST:
		var id := str(entry["id"])
		keys[id] = int(keys[id]) + amount


func next_level(id: String) -> int:
	return int(best.get(id, 0)) + 1


static func hp_for(level: int) -> float:
	return round(BASE_HP * pow(HP_GROWTH, level - 1) * float(rule().get("hp", 1.0)))


static func seconds() -> float:
	return float(rule().get("seconds", SECONDS))


## Награда уровня (без начисления): coins — минуты дохода, picks, diamonds, baits, shards.
static func reward_for(id: String, level: int) -> Dictionary:
	var factor := float(rule().get("reward", 1.0))
	match str(data(id).get("reward", "")):
		"coins":
			return {"minutes": int(round((10 + 2 * level) * factor)), "picks": int(round((3 + floori(level / 3.0)) * factor))}
		"gems":
			return {"diamonds": int(round((8 + 2 * level) * factor)), "baits": int(round((1 + floori(level / 10.0)) * factor))}
		"shards":
			return {"shards": int(round((3 + floori(level / 2.0)) * factor))}
	return {}


static func grant(id: String, level: int, s: ClickerState) -> Dictionary:
	var reward := reward_for(id, level)
	var result := {}
	if reward.has("minutes"):
		var amount := maxf(100.0, s.income_per_second() * 60.0 * int(reward["minutes"]))
		s.add_coins(amount)
		result["coins"] = amount
	if reward.has("picks"):
		s.quarry.picks += int(reward["picks"])
		result["picks"] = int(reward["picks"])
	if reward.has("diamonds"):
		s.diamonds += int(reward["diamonds"])
		result["diamonds"] = int(reward["diamonds"])
	if reward.has("baits"):
		s.pets.baits += int(reward["baits"])
		result["baits"] = int(reward["baits"])
	if reward.has("shards"):
		result["shards"] = s.artifacts.drop(int(reward["shards"]))
	return result


## Итог боя на следующем уровне подземелья id.
func finish(id: String, won: bool, s: ClickerState) -> Dictionary:
	_roll_day()
	if data(id).is_empty() or keys_left(id) <= 0:
		return {}
	var level := next_level(id)
	if not won:
		return {"won": false, "level": level}
	keys[id] = int(keys[id]) - 1
	best[id] = level
	s.quarry.note("dungeon")
	var result := grant(id, level, s)
	result["won"] = true
	result["level"] = level
	return result


## Зачистка лучшего пройденного уровня без боя (за ключ).
func sweep(id: String, s: ClickerState) -> Dictionary:
	_roll_day()
	var level := int(best.get(id, 0))
	if level <= 0 or keys_left(id) <= 0:
		return {}
	keys[id] = int(keys[id]) - 1
	s.quarry.note("dungeon")
	var result := grant(id, level, s)
	result["level"] = level
	result["won"] = true
	return result


func best_any() -> int:
	var top := 0
	for id in best:
		top = maxi(top, int(best[id]))
	return top


func to_dict() -> Dictionary:
	return {"best": best, "keys": keys, "keys_day": keys_day}


func from_dict(data_in: Dictionary) -> void:
	var saved_best := ClickerState._as_dict(data_in.get("best"))
	var saved_keys := ClickerState._as_dict(data_in.get("keys"))
	for entry in LIST:
		var id := str(entry["id"])
		best[id] = ClickerState._count(saved_best.get(id), 0, 100000)
		keys[id] = ClickerState._count(saved_keys.get(id), KEYS, 100)
	keys_day = int(ClickerState._num(data_in.get("keys_day"), -1.0))
