class_name Tower
extends RefCounted
## «Башня испытаний»: этажи-глыбы, которые нужно разбить касаниями за FIGHT_SECONDS. Прочность растёт на 10% за этаж,
## каждый 5-й этаж — хранитель (×2.5 прочности, большая награда). Сила удара — от питомцев, исследований, зоны и планеты.
## Попыток три в день (UTC); победа попытку не тратит, поражение тратит. Реклама даёт ещё одну.

const BASE_HP := 150.0
const HP_GROWTH := 1.1
const BOSS_EVERY := 5
const BOSS_HP := 2.5
const FIGHT_SECONDS := 20.0
const ATTEMPTS := 3
const DYNAMITE_SHARE := 0.25               # динамит снимает четверть прочности этажа

var next_floor := 1
var best := 0
var attempts := ATTEMPTS
var attempts_day := -1


static func is_boss(floor_number: int) -> bool:
	return floor_number % BOSS_EVERY == 0


static func hp_for(floor_number: int) -> float:
	return round(BASE_HP * pow(HP_GROWTH, floor_number - 1) * (BOSS_HP if is_boss(floor_number) else 1.0))


## Сила удара: питомцы (все собранные), исследования, глубина и планета.
static func tap_damage(s: ClickerState) -> float:
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	return 5.0 + float(s.pets.power()) + 2.0 * s.workshop.total_levels() + 5.0 * zone + 10.0 * s.planet


func _roll_day() -> void:
	var day := ClickerState.today()
	if day != attempts_day:
		attempts_day = day
		attempts = maxi(attempts, ATTEMPTS)        # дополнительные попытки (реклама) сверх трёх не сгорают


func attempts_left() -> int:
	_roll_day()
	return attempts


func can_fight() -> bool:
	return attempts_left() > 0


## Итог боя на этаже next_floor. Возвращает награду ({"won": false} при поражении).
func finish(won: bool, s: ClickerState) -> Dictionary:
	_roll_day()
	if not won:
		attempts = maxi(0, attempts - 1)
		return {"won": false, "floor": next_floor}
	var floor_number := next_floor
	var result := reward(floor_number, s)
	next_floor += 1
	best = maxi(best, floor_number)
	s.quarry.note("tower")
	result["won"] = true
	result["floor"] = floor_number
	return result


## Награда этажа: алмазы и приманка; хранитель — ещё приманки и золотой сундук; каждый 25-й — очко навыков.
static func reward(floor_number: int, s: ClickerState) -> Dictionary:
	var result := {}
	var gems := 2 + floori(floor_number / 5.0)
	s.diamonds += gems
	result["diamonds"] = gems
	var baits := 3 if is_boss(floor_number) else 1
	s.pets.baits += baits
	result["baits"] = baits
	if is_boss(floor_number):
		s.lucky.golden += 1
		result["golden"] = 1
	if floor_number % 25 == 0:
		s.skill_points += 1
		result["points"] = 1
	return result


func to_dict() -> Dictionary:
	return {"next_floor": next_floor, "best": best, "attempts": attempts, "attempts_day": attempts_day}


func from_dict(data: Dictionary) -> void:
	next_floor = maxi(1, ClickerState._count(data.get("next_floor"), 1, 100000))
	best = clampi(ClickerState._count(data.get("best"), 0, 100000), 0, next_floor - 1)
	attempts = ClickerState._count(data.get("attempts"), ATTEMPTS, 100)
	attempts_day = int(ClickerState._num(data.get("attempts_day"), -1.0))
