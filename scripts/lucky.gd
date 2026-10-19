class_name Lucky
extends RefCounted
## «Сундук удачи»: копится от игры (раз в LUCKY_SECONDS игрового времени, до LUCKY_CAP) и выдаётся наградами пропуска.
## Открытый сундук предлагает три карты разной редкости, игрок берёт одну. Есть «рискованные» карты: большая награда сразу,
## но доход на время падает. Золотой сундук (из пропуска) даёт карты не ниже редкой. Один раз можно перебросить за алмазы.
## Выбор хранится в сохранении: перезапуск игры его не меняет.

const LUCKY_SECONDS := 420.0               # сундук за 7 минут игры
const LUCKY_CAP := 3
const CARDS := 3
const RARITY_WEIGHTS := [[60, 30, 9, 1], [0, 50, 40, 10]]     # обычный и золотой сундук
## Карта: значения по редкости (обычная, редкая, ценная, легендарная). Время — в секундах; монеты — минуты дохода.
const KINDS := {
	"coins": {"name": "Жила монет", "values": [5, 15, 40, 120], "weight": 22},
	"gems": {"name": "Россыпь алмазов", "values": [3, 8, 20, 50], "weight": 18},
	"picks": {"name": "Связка кирок", "values": [5, 10, 20, 40], "weight": 14},
	"tokens": {"name": "Жетоны узкоколейки", "values": [1, 3, 6, 12], "weight": 12},
	"dynamite": {"name": "Ящик динамита", "values": [2, 4, 6, 10], "weight": 10},
	"frenzy": {"name": "Удачная смена", "values": [60, 120, 240, 480], "weight": 14},
	"gamble": {"name": "Проклятое золото", "values": [30, 60, 120, 300], "weight": 8},
	"point": {"name": "Свиток мастера", "values": [0, 0, 0, 1], "weight": 2},
}
const FRENZY_FACTOR := 2.0
const CURSE_FACTOR := 0.5
const CURSE_SECONDS := [120.0, 180.0, 240.0, 300.0]

var chests := 0
var golden := 0
var progress := 0.0                        # секунд игры до следующего сундука
var offer: Array = []                      # открытый сундук: [{kind, rarity}], пусто — нет
var offer_golden := false
var rerolled := false
var opened := 0                            # всего открыто (статистика, достижения)


## Игровое время: копит прогресс к сундуку. Возвращает true, если только что появился сундук.
func tick(delta: float) -> bool:
	if chests >= LUCKY_CAP:
		progress = 0.0
		return false
	progress += delta
	if progress < LUCKY_SECONDS:
		return false
	progress -= LUCKY_SECONDS
	chests += 1
	return true


func available() -> int:
	return chests + golden + (1 if not offer.is_empty() else 0)


## Открывает сундук (золотой в первую очередь) — или возвращает уже открытый выбор.
func open() -> bool:
	if not offer.is_empty():
		return true
	if golden > 0:
		golden -= 1
		offer_golden = true
	elif chests > 0:
		chests -= 1
		offer_golden = false
	else:
		return false
	rerolled = false
	offer = roll_cards(offer_golden)
	return true


static func roll_cards(is_golden: bool, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var weights: Array = RARITY_WEIGHTS[1 if is_golden else 0]
	var cards: Array = []
	var used := {}
	while cards.size() < CARDS:
		var rarity := _pick_index(weights, rng)
		var pool := {}
		for kind in KINDS:
			if used.has(kind) or (kind == "point" and rarity < 3):
				continue
			pool[kind] = int(KINDS[kind]["weight"])
		if pool.is_empty():
			break
		var kind := str(pool.keys()[_pick_index(pool.values(), rng)])
		used[kind] = true
		cards.append({"kind": kind, "rarity": rarity})
	return cards


static func _pick_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return weights.size() - 1


func reroll_cost(s: ClickerState) -> int:
	return 3 * (1 + Biomes.index_for(s.total_earned, s.planet_scale()))


func reroll(s: ClickerState) -> bool:
	if offer.is_empty() or rerolled or s.diamonds < reroll_cost(s):
		return false
	s.diamonds -= reroll_cost(s)
	rerolled = true
	offer = roll_cards(offer_golden)
	return true


static func value_of(card: Dictionary) -> int:
	return int(KINDS[str(card["kind"])]["values"][int(card["rarity"])])


## Берёт карту index из открытого сундука. Возвращает выданное ({} — нельзя).
func take(index: int, s: ClickerState) -> Dictionary:
	if index < 0 or index >= offer.size():
		return {}
	var card: Dictionary = offer[index]
	var value := value_of(card)
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	var result := {"kind": str(card["kind"]), "rarity": int(card["rarity"])}
	match str(card["kind"]):
		"coins":
			var amount := maxf(100.0, s.reward_income_per_second() * 60.0 * value)
			s.add_coins(amount)
			result["coins"] = amount
		"gems":
			s.diamonds += value + zone
			result["diamonds"] = value + zone
		"picks":
			s.quarry.picks += value
			result["picks"] = value
		"tokens":
			s.railway.tickets += value
			result["tickets"] = value
		"dynamite":
			result["dynamite"] = s.add_dynamite(value)
		"frenzy":
			s.start_luck(FRENZY_FACTOR, float(value))
			result["seconds"] = value
		"gamble":
			var amount := maxf(100.0, s.reward_income_per_second() * 60.0 * value)
			s.add_coins(amount)          # доход до проклятия: награда честная, штраф потом
			s.start_luck(CURSE_FACTOR, CURSE_SECONDS[int(card["rarity"])])
			result["coins"] = amount
			result["curse"] = CURSE_SECONDS[int(card["rarity"])]
		"point":
			s.skill_points += value
			result["points"] = value
	offer = []
	opened += 1
	s.quarry.note("chest")
	return result


func to_dict() -> Dictionary:
	return {"chests": chests, "golden": golden, "progress": progress, "offer": offer, "offer_golden": offer_golden,
			"rerolled": rerolled, "opened": opened}


func from_dict(data: Dictionary) -> void:
	chests = ClickerState._count(data.get("chests"), 0, 1000)      # наградами пропуска можно скопить больше LUCKY_CAP
	golden = ClickerState._count(data.get("golden"), 0, 1000)
	progress = clampf(ClickerState._num(data.get("progress"), 0.0), 0.0, LUCKY_SECONDS)
	offer_golden = bool(data.get("offer_golden", false))
	rerolled = bool(data.get("rerolled", false))
	opened = ClickerState._count(data.get("opened"), 0)
	offer = []
	for card in ClickerState._as_array(data.get("offer")):
		if typeof(card) == TYPE_DICTIONARY and KINDS.has(str(card.get("kind", ""))):
			var rarity := clampi(int(ClickerState._num(card.get("rarity"), 0.0)), 0, 3)
			if str(card["kind"]) == "point":
				rarity = 3
			offer.append({"kind": str(card["kind"]), "rarity": rarity})
	if offer.size() != CARDS:
		offer = []
