class_name Pets
extends RefCounted
## «Подземные друзья»: 12 питомцев четырёх редкостей. Призыв за алмазы или приманки; уровень призыва растёт с числом
## призывов и улучшает шансы. Повторный питомец даёт звезду (копий на звёзды: 1, 2, 4, 8, 16 — всего 31 на 5★).
## Три питомца в слотах дают свой эффект (сила эффекта по звёздам); все собранные питомцы прибавляют силу удара в башне.

const PETS := [
	{"id": "mole", "name": "Крот Копуша", "rarity": 0, "effect": "picks", "text": "кирки копятся быстрее на %d%%"},
	{"id": "bat", "name": "Нетопырь Тень", "rarity": 0, "effect": "income", "text": "доход +%d%%"},
	{"id": "rat", "name": "Крыса Шнырь", "rarity": 0, "effect": "trips", "text": "добыча походов +%d%%"},
	{"id": "firefly", "name": "Светлячок Искорка", "rarity": 0, "effect": "diamonds", "text": "алмазные жилы чаще на %d%%"},
	{"id": "lizard", "name": "Ящерка Медянка", "rarity": 1, "effect": "golden", "text": "золотые глыбы чаще на %d%%"},
	{"id": "owl", "name": "Сыч Полуночник", "rarity": 1, "effect": "offline", "text": "офлайн-доход +%d%%"},
	{"id": "crab", "name": "Рудный краб", "rarity": 1, "effect": "rail", "text": "награды узкоколейки +%d%%"},
	{"id": "fox", "name": "Огнёвка", "rarity": 2, "effect": "dynamite", "text": "динамит приносит +%d%%"},
	{"id": "golem", "name": "Голем Валун", "rarity": 2, "effect": "guard", "text": "хранители слабее на %d%%"},
	{"id": "salamander", "name": "Саламандра", "rarity": 2, "effect": "income", "text": "доход +%d%%"},
	{"id": "dragon", "name": "Рудный дракон", "rarity": 3, "effect": "income", "text": "доход +%d%%"},
	{"id": "serpent", "name": "Хрустальный змей", "rarity": 3, "effect": "lucky", "text": "сундуки удачи чаще на %d%%"},
]
const RARITY_STEP := [0.03, 0.05, 0.08, 0.12]          # сила эффекта за звезду (обычный … легендарный)
const RARITY_POWER := [3, 5, 8, 14]                    # сила удара в башне за звезду
const STAR_TOTALS := [1, 3, 7, 15, 31]                 # копий всего для 1★ … 5★
const SLOTS := 3
const SUMMON_LEVELS := [0, 30, 100, 240, 450, 750]     # призывов всего для уровня призыва 1…6
const SUMMON_ODDS := [[90, 10, 0, 0], [80, 17, 3, 0], [70, 24, 5, 1], [62, 28, 8, 2], [55, 31, 11, 3], [50, 32, 14, 4]]
const PULL_COST := 10
const PULL10_COST := 90

var copies := {}                                       # id -> сколько копий получено
var equipped: Array = []                               # id питомцев в слотах (до SLOTS)
var pulls := 0
var baits := 0                                         # приманки: бесплатные призывы
var free_day := -1                                     # день (UTC) последнего бесплатного призыва

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	for pet in PETS:
		copies[str(pet["id"])] = 0


static func data(id: String) -> Dictionary:
	for pet in PETS:
		if str(pet["id"]) == id:
			return pet
	return {}


func owned(id: String) -> bool:
	return int(copies.get(id, 0)) > 0


func kinds() -> int:
	var n := 0
	for id in copies:
		if int(copies[id]) > 0:
			n += 1
	return n


func stars(id: String) -> int:
	var count := int(copies.get(id, 0))
	var result := 0
	for total in STAR_TOTALS:
		if count >= int(total):
			result += 1
	return result


## Копий до следующей звезды (0 — максимум).
func copies_to_next(id: String) -> int:
	var s := stars(id)
	if s >= STAR_TOTALS.size():
		return 0
	return int(STAR_TOTALS[s]) - int(copies.get(id, 0))


## Сила эффекта питомца (доля: 0.15 = 15%).
func effect_value(id: String) -> float:
	var pet := data(id)
	if pet.is_empty():
		return 0.0
	return float(RARITY_STEP[int(pet["rarity"])]) * stars(id)


## Сумма эффектов питомцев в слотах по виду эффекта.
func bonus(effect: String) -> float:
	var total := 0.0
	for id in equipped:
		var pet := data(str(id))
		if not pet.is_empty() and str(pet["effect"]) == effect:
			total += effect_value(str(id))
	return total


## Сила всех собранных питомцев (удар в башне).
func power() -> int:
	var total := 0
	for pet in PETS:
		total += int(RARITY_POWER[int(pet["rarity"])]) * stars(str(pet["id"]))
	return total


func summon_level() -> int:
	var level := 0
	for need in SUMMON_LEVELS:
		if pulls >= int(need):
			level += 1
	return level


## Призывов до следующего уровня призыва (0 — максимум).
func pulls_to_next_level() -> int:
	var level := summon_level()
	if level >= SUMMON_LEVELS.size():
		return 0
	return int(SUMMON_LEVELS[level]) - pulls


func free_available() -> bool:
	return ClickerState.today() > free_day


## Призыв count питомцев: сначала бесплатный (раз в день, если free), потом приманки, остальное за алмазы.
## Возвращает список id (пусто — не хватает алмазов).
func summon(count: int, s: ClickerState, free := false) -> Array:
	var paid := count
	var use_free := free and free_available()
	if use_free:
		paid -= 1
	var from_baits := mini(baits, paid)
	paid -= from_baits
	var cost := PULL10_COST if count == 10 and paid == 10 else PULL_COST * paid
	if s.diamonds < cost:
		return []
	s.diamonds -= cost
	baits -= from_baits
	if use_free:
		free_day = ClickerState.today()
	var result: Array = []
	for i in count:
		result.append(roll_one())
	s.quarry.note("summon", count)
	return result


## Один призыв по шансам текущего уровня; копия засчитывается сразу.
func roll_one() -> String:
	var odds: Array = SUMMON_ODDS[summon_level() - 1]
	var total := 0.0
	for w in odds:
		total += float(w)
	var roll := _rng.randf() * total
	var rarity := 0
	for r in odds.size():
		roll -= float(odds[r])
		if roll < 0.0:
			rarity = r
			break
	var pool: Array = []
	for pet in PETS:
		if int(pet["rarity"]) == rarity:
			pool.append(str(pet["id"]))
	var id: String = pool[_rng.randi() % pool.size()]
	copies[id] = int(copies[id]) + 1
	pulls += 1
	return id


## Поставить питомца в слот или убрать из слота. Возвращает true, если что-то изменилось.
func toggle(id: String) -> bool:
	if equipped.has(id):
		equipped.erase(id)
		return true
	if not owned(id) or equipped.size() >= SLOTS:
		return false
	equipped.append(id)
	return true


func to_dict() -> Dictionary:
	return {"copies": copies, "equipped": equipped, "pulls": pulls, "baits": baits, "free_day": free_day}


func from_dict(data_in: Dictionary) -> void:
	var saved := ClickerState._as_dict(data_in.get("copies"))
	for pet in PETS:
		var id := str(pet["id"])
		copies[id] = ClickerState._count(saved.get(id), 0, 100000)
	equipped = []
	for id in ClickerState._as_array(data_in.get("equipped")):
		if owned(str(id)) and not equipped.has(str(id)) and equipped.size() < SLOTS:
			equipped.append(str(id))
	pulls = ClickerState._count(data_in.get("pulls"), 0)
	baits = ClickerState._count(data_in.get("baits"), 0, 100000)
	free_day = int(ClickerState._num(data_in.get("free_day"), -1.0))
