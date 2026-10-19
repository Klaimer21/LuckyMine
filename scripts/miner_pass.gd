class_name MinerPass
extends RefCounted
## «Пропуск шахтёра»: сезон SEASON_DAYS дней (по UTC, у всех одинаковый). Опыт пропуска — те же очки, что и в «Наряде дня»
## (со множителем темы дня). Каждые XP_PER_LEVEL очков — уровень; на каждом уровне награда бесплатной дорожки и, если куплен
## «Золотой пропуск», награда золотой (в 3–4 раза больше). После LEVELS каждые XP_PER_LEVEL очков дают сундук удачи.
## Новый сезон обнуляет опыт, полученные награды и золотой пропуск; незабранные награды прошлого сезона пропадают.

const SEASON_DAYS := 28
const LEVELS := 30
const XP_PER_LEVEL := 200
const PRODUCT := "miner_pass"              # id покупки в магазине (Store)
const SEASON_ZERO := 739                   # номер сезона до выхода пропуска (октябрь 2026): игроку показывается «Сезон 1, 2…»

## Награды по уровням: повторяющийся цикл из пяти; каждый 10-й уровень — особый.
const FREE_CYCLE := [{"picks": 5}, {"coins": 10}, {"tokens": 2}, {"diamonds": 5}, {"chest": 1}]
const GOLD_CYCLE := [{"picks": 20}, {"coins": 40}, {"tokens": 6}, {"diamonds": 20}, {"golden": 1}]
const FREE_SPECIAL := {10: {"points": 1}, 20: {"points": 1}, 30: {"points": 1, "diamonds": 20}}
const GOLD_SPECIAL := {10: {"points": 2, "golden": 1}, 20: {"points": 2, "golden": 1}, 30: {"points": 3, "golden": 3, "diamonds": 100}}

var season := -1
var xp := 0
var premium := false
var claimed_free := 0                       # битовая маска уровней 1…30 (бит level-1)
var claimed_gold := 0
var overflow_paid := 0                      # сундуков уже выдано за опыт сверх 30-го уровня


## Номер сезона для показа игроку (с 1).
static func season_number() -> int:
	return maxi(1, current_season() - SEASON_ZERO)


static func current_season() -> int:
	return floori(ClickerState.today() / float(SEASON_DAYS))


## Секунд до конца сезона.
static func season_left() -> float:
	return float((current_season() + 1) * SEASON_DAYS) * 86400.0 - ClickerState.now()


func _roll_season() -> void:
	var now_season := current_season()
	if now_season > season:                # только вперёд: откат часов не сжигает купленный пропуск
		season = now_season
		xp = 0
		premium = false
		claimed_free = 0
		claimed_gold = 0
		overflow_paid = 0


func add_xp(points: int) -> void:
	_roll_season()
	xp += maxi(0, points)


func current_xp() -> int:
	_roll_season()
	return xp


func level() -> int:
	return mini(LEVELS, floori(current_xp() / float(XP_PER_LEVEL)))


func has_premium() -> bool:
	_roll_season()
	return premium


func unlock_premium() -> void:
	_roll_season()
	premium = true


static func reward(track: String, lvl: int) -> Dictionary:
	if track == "gold":
		return GOLD_SPECIAL.get(lvl, GOLD_CYCLE[(lvl - 1) % GOLD_CYCLE.size()])
	return FREE_SPECIAL.get(lvl, FREE_CYCLE[(lvl - 1) % FREE_CYCLE.size()])


func claimed(track: String, lvl: int) -> bool:
	_roll_season()
	var mask := claimed_gold if track == "gold" else claimed_free
	return (mask & (1 << (lvl - 1))) != 0


func claimable(track: String, lvl: int) -> bool:
	if lvl < 1 or lvl > level() or claimed(track, lvl):
		return false
	return track == "free" or premium


func claimable_count() -> int:
	var n := 0
	for lvl in range(1, level() + 1):
		for track in ["free", "gold"]:
			if claimable(track, lvl):
				n += 1
	return n + overflow_ready()


## Сундуков за опыт сверх последнего уровня, которые ещё не выданы.
func overflow_ready() -> int:
	var extra := current_xp() - LEVELS * XP_PER_LEVEL
	if extra <= 0:
		return 0
	return floori(extra / float(XP_PER_LEVEL)) - overflow_paid


## Выдаёт награду уровня (и отмечает её). Возвращает выданное.
func claim(track: String, lvl: int, s: ClickerState) -> Dictionary:
	if not claimable(track, lvl):
		return {}
	if track == "gold":
		claimed_gold |= 1 << (lvl - 1)
	else:
		claimed_free |= 1 << (lvl - 1)
	return grant(reward(track, lvl), s)


## Забирает всё доступное (обе дорожки и сундуки сверх максимума). Возвращает сумму выданного.
func claim_all(s: ClickerState) -> Dictionary:
	var total := {}
	for lvl in range(1, level() + 1):
		for track in ["free", "gold"]:
			var got := claim(track, lvl, s)
			for key in got:
				total[key] = total.get(key, 0) + got[key]
	var extra := overflow_ready()
	if extra > 0:
		overflow_paid += extra
		s.lucky.chests += extra                 # награда сверх максимума может превысить склад сундуков
		total["chest"] = int(total.get("chest", 0)) + extra
	return total


static func grant(reward_data: Dictionary, s: ClickerState) -> Dictionary:
	var result := {}
	for key in reward_data:
		var value := int(reward_data[key])
		match str(key):
			"picks":
				s.quarry.picks += value
				result["picks"] = value
			"coins":
				var amount := maxf(100.0, s.reward_income_per_second() * 60.0 * value)
				s.add_coins(amount)
				result["coins"] = amount
			"tokens":
				s.railway.tickets += value
				result["tokens"] = value
			"diamonds":
				s.diamonds += value
				result["diamonds"] = value
			"chest":
				s.lucky.chests += value
				result["chest"] = value
			"golden":
				s.lucky.golden += value
				result["golden"] = value
			"points":
				s.skill_points += value
				result["points"] = value
	return result


func to_dict() -> Dictionary:
	return {"season": season, "xp": xp, "premium": premium, "claimed_free": claimed_free, "claimed_gold": claimed_gold,
			"overflow_paid": overflow_paid}


func from_dict(data: Dictionary) -> void:
	season = int(ClickerState._num(data.get("season"), -1.0))
	xp = ClickerState._count(data.get("xp"), 0)
	premium = bool(data.get("premium", false))
	var full := (1 << LEVELS) - 1
	claimed_free = clampi(int(ClickerState._num(data.get("claimed_free"), 0.0)), 0, full)
	claimed_gold = clampi(int(ClickerState._num(data.get("claimed_gold"), 0.0)), 0, full)
	overflow_paid = ClickerState._count(data.get("overflow_paid"), 0)
	_roll_season()
