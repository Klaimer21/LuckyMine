class_name Railway
extends RefCounted
## «Узкоколейка»: кольцо из 20 клеток-перегонов вокруг шахты. Жетон — один бросок кубика (1–6), вагонетка едет вперёд
## и забирает награду клетки, на которую встала. Стрелка везёт ещё на 3 клетки, звезда удваивает следующую награду,
## обвал пуст. Проезд через «Депо» — круг: алмазы и кирки, каждый 5-й круг ещё очко навыков.
## Жетоны дают: ярусы забоя, походы (больше за редкие), хранители, сундуки наряда, ежедневная награда, реклама, старьёвщик.

const BOARD := [
	"start", "coins_s", "picks", "finds", "coins_m", "arrow",
	"gems", "collapse", "coins_s", "dynamite",
	"chest", "coins_m", "finds", "star", "gems", "collapse",
	"coins_l", "picks", "arrow", "finds",
]
const ARROW_STEPS := 3
const COINS_SECONDS := {"coins_s": 120.0, "coins_m": 360.0, "coins_l": 1200.0, "chest": 900.0}
const AD_TICKETS := 2
const LAP_POINT_EVERY := 5

var tickets := 3
var pos := 0
var laps := 0
var rolls := 0
var double_next := false                 # звезда: следующая награда ×2
var last_path: Array = []                # клетки, по которым проехала вагонетка в последнем броске (для анимации)
var last_roll := 0
var animate_pending := false             # интерфейс ещё не показал последний бросок
var last_result := {}                    # итог последнего броска (подпись после анимации; не сохраняется)

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Бросок. roll_value > 0 подставляет значение кубика (тесты). Возвращает {} (нет жетонов) или итог броска.
func roll(s: ClickerState, roll_value := 0) -> Dictionary:
	if tickets <= 0:
		return {}
	tickets -= 1
	rolls += 1
	s.quarry.note("cart")
	var die := roll_value if roll_value > 0 else _rng.randi_range(1, 6)
	last_roll = die
	last_path = []
	var result := {"die": die, "laps": 0}
	_move(die, result)
	var cell := str(BOARD[pos])
	if cell == "arrow":
		result["arrow"] = true
		_move(ARROW_STEPS, result)
		cell = str(BOARD[pos])
	result["cell"] = cell
	var factor := 2.0 if double_next and cell != "star" else 1.0
	double_next = cell == "star"                 # звезда копит удвоение, любая другая клетка его тратит (обвал — впустую)
	result["doubled"] = factor > 1.0
	result.merge(grant(cell, s, factor * s.rail_factor()))
	if int(result["laps"]) > 0:
		result["lap"] = lap_reward(s, int(result["laps"]))
	animate_pending = true
	last_result = result
	return result


func _move(steps: int, result: Dictionary) -> void:
	for i in steps:
		pos = (pos + 1) % BOARD.size()
		last_path.append(pos)
		if pos == 0:
			laps += 1
			result["laps"] = int(result["laps"]) + 1


## Награда клетки (и круга, если вагонетка проехала депо).
func grant(cell: String, s: ClickerState, factor: float) -> Dictionary:
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	var result := {}
	match cell:
		"coins_s", "coins_m", "coins_l":
			var amount := maxf(100.0, s.income_per_second() * float(COINS_SECONDS[cell])) * factor
			s.add_coins(amount)
			result["coins"] = amount
		"gems":
			var gems := int(round((2 + zone) * factor))
			s.diamonds += gems
			result["diamonds"] = gems
		"finds":
			var ore := _rng.randi_range(1, mini(3, 1 + zone))
			var count := int(round(_rng.randi_range(4, 8) * factor))
			s.finds[ore] = int(s.finds[ore]) + count
			result["ore"] = ore
			result["count"] = count
		"picks":
			var add := int(round(4 * factor))
			s.quarry.picks += add
			result["picks"] = add
		"dynamite":
			result["dynamite"] = s.add_dynamite(int(round(1 * factor)))
		"chest":
			var amount := maxf(100.0, s.income_per_second() * float(COINS_SECONDS["chest"])) * factor
			s.add_coins(amount)
			var gems := int(round((3 + zone) * factor))
			s.diamonds += gems
			var add := int(round(3 * factor))
			s.quarry.picks += add
			result["coins"] = amount
			result["diamonds"] = gems
			result["picks"] = add
	return result


## Награда за круг (если бросок провёз через депо): алмазы, кирки, каждый 5-й — очко навыков.
func lap_reward(s: ClickerState, lap_count: int) -> Dictionary:
	if lap_count <= 0:
		return {}
	var zone := Biomes.index_for(s.total_earned, s.planet_scale())
	var gems := (5 + 2 * zone) * lap_count
	s.diamonds += gems
	s.quarry.picks += 5 * lap_count
	var points := 0
	for i in lap_count:
		if (laps - i) % LAP_POINT_EVERY == 0:
			points += 1
	s.skill_points += points
	return {"diamonds": gems, "picks": 5 * lap_count, "points": points}


func to_dict() -> Dictionary:
	return {"tickets": tickets, "pos": pos, "laps": laps, "rolls": rolls, "double_next": double_next}


func from_dict(data: Dictionary) -> void:
	tickets = ClickerState._count(data.get("tickets"), 3, 100000)
	pos = clampi(int(ClickerState._num(data.get("pos"), 0.0)), 0, BOARD.size() - 1)
	laps = ClickerState._count(data.get("laps"), 0)
	rolls = ClickerState._count(data.get("rolls"), 0)
	double_next = bool(data.get("double_next", false))
