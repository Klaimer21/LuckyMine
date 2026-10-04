class_name ClickerState
extends RefCounted
## Состояние LuckyMine: монеты, уровни улучшений, сохранение.

const SAVE_PATH := "user://luckymine_save.json"
const TEMP_PATH := "user://luckymine_save.tmp"
const BACKUP_PATH := "user://luckymine_save.bak"
## Ключ подписи сохранения. Он лежит в игре, поэтому это защита от правки блокнотом, а не от взлома.
const SAVE_KEY := "luckymine-save-v2-8f3a1c"
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0
## Улучшения: базовая цена и рост цены за уровень.
const UPGRADES := {
	"rain": {"base": 15.0, "growth": 1.5},
	"tap": {"base": 25.0, "growth": 1.45},
	"faces": {"base": 60.0, "growth": 2.0},
	"mult": {"base": 250.0, "growth": 2.6},
}
## Престиж «Новая шахта»: жилы = целая часть (заработанное за всё время / VEIN_BASE)^(1/3), минус уже полученные.
## Каждая жила даёт +VEIN_STEP к доходу навсегда. Числа подобраны симуляцией (docs/ROADMAP.md).
const VEIN_BASE := 1.0e6
const VEIN_STEP := 0.2
const PRESTIGE_GOOD_MIN := 5            # «пора» от стольких новых жил (и от 70% уже имеющихся)
## Коллекция руды: за каждую подобранную находку растёт счётчик; уровень — число пройденных вех.
## Каждый уровень любой руды: +3% дохода навсегда; «полный набор» (все четыре руды на уровне N): ещё +10% за N.
const MILESTONES := [100, 2000, 40000, 800000, 16000000]
const COLLECTION_STEP := 0.03
const FULL_SET_STEP := 0.10
const ORES := [1, 2, 3, 4]               # медь, железо, золото, алмаз
const MINI_FACTOR := 2.0                 # «Золотой запал» от золотого самородка
## Второй слой «Новая планета»: после ядра. Звёздная пыль тратится на постоянные мета-улучшения.
## id, название, описание, цены по уровням. Эффекты см. start_bonus_levels(), vein_step() и др. ниже.
const META := [
	{"id": "income", "name": "Планетарная добыча", "text": "+20% дохода за уровень", "costs": [5, 10, 20, 40, 80]},
	{"id": "start", "name": "Стартовый капитал", "text": "+3 стартовых уровня «Камнепада» и «Граней» после каждого сброса", "costs": [3, 6, 12, 24, 48]},
	{"id": "veins", "name": "Глубокие жилы", "text": "+0.03 дохода за каждую жилу", "costs": [4, 8, 16, 32, 64]},
	{"id": "offline", "name": "Долгая смена", "text": "+4 часа офлайн-дохода", "costs": [2, 4, 8]},
	{"id": "diamonds", "name": "Алмазный нюх", "text": "+25% алмазов", "costs": [3, 6, 12, 24]},
	{"id": "wisdom", "name": "Мудрость жил", "text": "+20% очков навыков за каждую «Новую шахту»", "costs": [6, 12, 24]},
	{"id": "guardian", "name": "Охотник на хранителей", "text": "награда хранителей +50%", "costs": [4, 8, 16]},
	{"id": "autobuy", "name": "Автоснабжение", "text": "автопокупка самого дешёвого улучшения: раз в 6 / 3 / 1.5 с", "costs": [8, 20, 50]},
	{"id": "expedition", "name": "Снаряжение походов", "text": "добыча походов +50%", "costs": [4, 8, 16]},
]
const MINI_SECONDS := 3.0
const MINI_COOLDOWN := 8.0              # пауза после малого запала, пока золото не запускает его снова
const BOOST_FACTOR := 7.0
const STYLE_PRICES := {7: 40, 8: 60, 9: 80}   # породы за алмазы
const BOOST_SECONDS := 15.0              # лихорадка от золотой глыбы
const RUSH_LONG_SECONDS := 300.0         # лихорадка за алмазы или рекламу
const RUSH_CAP_SECONDS := 600.0          # дольше не копится
const RUSH_COOLDOWN := 3600.0            # пауза между покупками лихорадки за алмазы (с начала прошлой)
## Эффекты навыков по уровню ветки (0…4).
const DRILL_BONUS := [0.0, 0.10, 0.20, 0.35, 0.60]
const YIELD_BONUS := [1.0, 1.15, 1.35, 1.6, 2.0]    # ветка «Добыча»: множитель дохода по уровню
const START_DYNAMITE := 3                  # динамит выдаётся за события, а не по перезарядке
const DYNAMITE_CAPS := [10, 20, 20, 20, 30]   # вместимость склада по уровню навыка «Динамит»
const DYNAMITE_SECONDS := [30.0, 30.0, 38.0, 38.0, 38.0]
const DYNAMITE_CHAIN := 0.3                # доля награды во втором взрыве (с 3-го уровня)
const START_SKILL_POINTS := 2
const ORDER := ["rain", "tap", "faces", "mult"]
const MAX_BULK := 10000                  # потолок режима «Макс» за одну покупку

## false после сброса прогресса: пока сцена не перезагружена, старое состояние не должно записаться обратно.
var saving_enabled := true
## Подпись сохранения не сошлась: файл правили руками. Игра грузится, но флаг пригодится для рейтингов и покупок.
var tampered := false
var coins := 0.0
var total_earned := 0.0          # всего заработано за всё время (по нему растёт глубина)
var ending_seen := false
var veins := 0                     # жилы: постоянный множитель дохода
var prestiges := 0
var levels := {"rain": 0, "tap": 0, "faces": 0, "mult": 0}
var last_seen := 0.0
var auto_throw := true
var autobuy_on := true               # включатель автопокупки (работает, если куплено мета-улучшение)
var ads_removed := false             # куплено «Убрать рекламу»: награда выдаётся без ролика
var ads_watched := 0
var ad_ready_at := {}                # место рекламы -> unix-время, когда можно снова
var offline_away := 0.0              # сколько секунд игрока не было при последней загрузке (с учётом лимита)
var offline_capped := false          # время офлайна упёрлось в лимит
var skill_points := START_SKILL_POINTS
var skills := {"drill": 0, "dynamite": 0, "luck": 0, "yield": 0}
var golden_caught := 0
var dynamite_used := 0
var dynamite_stock := START_DYNAMITE
var dynamite_zone_best := 0          # самая глубокая зона планеты, за вход в которую уже выдан динамит
var bosses_defeated := 0
var achievements_claimed := {}            # id -> true
var daily_day := -1                       # номер суток (UTC) последней полученной награды
var daily_streak := 0
var expedition_type := -1                 # -1 — нет похода
var expedition_end := 0.0                 # unix-время конца похода
var tutorial_done := false
var hints_seen := {}                      # id подсказки -> true
var planet := 0
var stardust := 0
var meta := {"income": 0, "start": 0, "veins": 0, "offline": 0, "diamonds": 0, "wisdom": 0, "guardian": 0, "expedition": 0, "autobuy": 0}
var play_seconds := 0.0
var rocks_broken := 0
var lifetime_earned := 0.0
var diamonds := 0                  # вторая валюта: выпадает из алмазов-находок
var finds := {1: 0, 2: 0, 3: 0, 4: 0}
var boost_factor := BOOST_FACTOR
var mini_cooldown := 0.0
var skill_points_bought := 0         # купленные за алмазы очки навыков (цена растёт)
var styles_bought: Array = []        # индексы пород, купленных за алмазы
var rush_ready_at := 0.0            # unix-время, когда лихорадку за алмазы можно купить снова
var boost_time := 0.0             # «Золотая лихорадка»: сколько секунд осталось (не сохраняется)


## Сколько глыб падает в секунду сами.
func rain_rate() -> float:
	return (1.0 + 0.8 * levels["rain"]) * (1.0 + float(DRILL_BONUS[skill_level("drill")]))


func rocks_per_throw() -> int:
	return 1 + levels["tap"]


## Наибольшая ценность руды (глыба даёт от 1 до этого числа).
func max_face() -> int:
	return 6 + 2 * levels["faces"]


## Множитель добычи: улучшение «Добыча», бонус зоны и «Золотая лихорадка» (×7 после касания золотой глыбы).
func multiplier() -> float:
	return pow(1.5, levels["mult"]) * Biomes.factor(total_earned, planet_scale()) * vein_multiplier() * collection_multiplier() * (1.0 + 0.2 * int(meta["income"])) * float(YIELD_BONUS[skill_level("yield")]) * (boost_factor if boost_time > 0.0 else 1.0)


func average_value() -> float:
	return (1.0 + max_face()) / 2.0 * multiplier()


func income_per_second() -> float:
	return rain_rate() * average_value()


func cost(key: String) -> float:
	var info: Dictionary = UPGRADES[key]
	return float(info["base"]) * pow(float(info["growth"]), levels[key])


func can_buy(key: String) -> bool:
	return coins >= cost(key)


func buy(key: String) -> bool:
	return buy_n(key, 1) > 0


## Цена n следующих уровней подряд (сумма геометрической прогрессии).
func cost_for(key: String, n: int) -> float:
	var info: Dictionary = UPGRADES[key]
	var growth := float(info["growth"])
	return cost(key) * (pow(growth, n) - 1.0) / (growth - 1.0)


## Сколько уровней подряд хватит монет купить (для режима «Макс»).
func max_affordable(key: String) -> int:
	var info: Dictionary = UPGRADES[key]
	var growth := float(info["growth"])
	var first := cost(key)
	if coins < first:
		return 0
	var n := int(floor(log(coins * (growth - 1.0) / first + 1.0) / log(growth)))
	while n > 0 and cost_for(key, n) > coins:
		n -= 1
	while n < MAX_BULK and cost_for(key, n + 1) <= coins:
		n += 1
	return mini(n, MAX_BULK)


## Покупает ровно n уровней или ничего; возвращает, сколько куплено.
func buy_n(key: String, n: int) -> int:
	if n < 1:
		return 0
	var price := cost_for(key, n)
	if not (coins >= price):          # так и NaN вместо монет ничего не покупает
		return 0
	coins -= price
	levels[key] += n
	return n


# ---------- Навыки ----------

func skill_level(branch: String) -> int:
	return int(skills[branch])


## Цена следующего навыка ветки в очках; 0, если ветка прокачана до конца.
func skill_cost(branch: String) -> int:
	var level := skill_level(branch)
	return 0 if level >= Skills.MAX_LEVEL else int(Skills.costs_of(branch)[level])


func can_buy_skill(branch: String) -> bool:
	var price := skill_cost(branch)
	return price > 0 and skill_points >= price


func buy_skill(branch: String) -> bool:
	if not can_buy_skill(branch):
		return false
	skill_points -= skill_cost(branch)
	skills[branch] = skill_level(branch) + 1
	return true


## Возвращает все потраченные очки (за алмазы, цену см. shop_cost("respec")).
func respec() -> void:
	for branch in skills:
		for level in skill_level(branch):
			skill_points += int(Skills.costs_of(branch)[level])
		skills[branch] = 0
	dynamite_stock = mini(dynamite_stock, dynamite_max())      # склад уменьшился: лишний динамит не остаётся


func dynamite_max() -> int:
	return int(DYNAMITE_CAPS[skill_level("dynamite")])


## Кладёт динамит на склад (на Титане выдаётся на 50% больше, сверх вместимости не берётся). Возвращает, сколько добавлено.
func add_dynamite(amount: int) -> int:
	if amount <= 0:
		return 0
	var bonus := 1.5 if Biomes.planet_mod(planet) == "dynamite" else 1.0
	var added := mini(int(round(amount * bonus)), maxi(0, dynamite_max() - dynamite_stock))
	dynamite_stock += added
	return added


func use_dynamite() -> bool:
	if dynamite_stock <= 0:
		return false
	dynamite_stock -= 1
	dynamite_used += 1
	return true


func dynamite_seconds() -> float:
	return DYNAMITE_SECONDS[skill_level("dynamite")]


## Находок, которые динамит выбивает из породы: 3 плюс по одной за каждые две зоны.
func dynamite_finds() -> int:
	return 3 + floori(Biomes.index_for(total_earned, planet_scale()) / 2.0)


func dynamite_chain() -> float:
	return DYNAMITE_CHAIN if skill_level("dynamite") >= 3 else 0.0


func dynamite_spark() -> bool:
	return skill_level("dynamite") >= 4


func diamond_chance_factor() -> float:
	return (1.3 if skill_level("luck") >= 1 else 1.0) * (1.0 + 0.25 * int(meta["diamonds"])) * (1.25 if Biomes.planet_mod(planet) == "diamonds" else 1.0)


func mini_seconds() -> float:
	return MINI_SECONDS + (2.0 if skill_level("luck") >= 2 else 0.0)


func golden_interval_factor() -> float:
	return (0.7 if skill_level("luck") >= 3 else 1.0) * (0.7 if Biomes.planet_mod(planet) == "golden" else 1.0)


## Хранители зон на планете «Венера» слабее на 30% и платят вдвое; мета «Охотник на хранителей» добавляет +50% за уровень.
func boss_hp_factor() -> float:
	return 0.7 if Biomes.planet_mod(planet) == "boss" else 1.0


func boss_reward_factor() -> float:
	return (2.0 if Biomes.planet_mod(planet) == "boss" else 1.0) * (1.0 + 0.5 * int(meta["guardian"]))


func lucky_rock_chance() -> float:
	return 0.03 if skill_level("luck") >= 4 else 0.0


## Короткий «Золотой запал» (например, от динамита): не перебивает идущий буст.
func start_mini(seconds: float) -> void:
	if boost_time <= 0.0:
		boost_factor = MINI_FACTOR
		boost_time = seconds


# ---------- Достижения ----------

func achievement_value(achievement: Dictionary) -> float:
	match str(achievement["kind"]):
		"zone":
			return float(Biomes.index_for(total_earned, planet_scale()))
		"prestige":
			return float(prestiges)
		"gold":
			return float(finds[3])
		"diamond":
			return float(finds[4])
		"golden":
			return float(golden_caught)
		"dynamite":
			return float(dynamite_used)
		"boss":
			return float(bosses_defeated)
		"planet":
			return float(planet)
		"rocks":
			return float(rocks_broken)
		"meta":
			var total_meta := 0
			for key in meta:
				total_meta += int(meta[key])
			return float(total_meta)
		"set":
			return float(full_set_level())
	return 0.0


func achievement_done(achievement: Dictionary) -> bool:
	return achievement_value(achievement) >= float(achievement["goal"])


func achievement_claimed(achievement: Dictionary) -> bool:
	return achievements_claimed.has(str(achievement["id"]))


func achievement_claimable(achievement: Dictionary) -> bool:
	return achievement_done(achievement) and not achievement_claimed(achievement)


func claimable_achievements() -> int:
	var n := 0
	for achievement in Retention.ACHIEVEMENTS:
		if achievement_claimable(achievement):
			n += 1
	return n


## Забирает награду; возвращает ее словарь (пустой, если нельзя).
func claim_achievement(achievement: Dictionary) -> Dictionary:
	if not achievement_claimable(achievement):
		return {}
	achievements_claimed[str(achievement["id"])] = true
	var reward: Dictionary = achievement["reward"]
	diamonds += int(reward.get("diamonds", 0))
	skill_points += int(reward.get("points", 0))
	add_dynamite(int(reward.get("dynamite", 0)))
	return reward


## Порода-косметика открыта: гранит всегда, остальные — наградами за достижения.
func style_unlocked(index: int) -> bool:
	if index == 0 or styles_bought.has(index):
		return true
	for achievement in Retention.ACHIEVEMENTS:
		var reward: Dictionary = achievement["reward"]
		if int(reward.get("style", -1)) == index and achievement_claimed(achievement):
			return true
	return false


# ---------- Ежедневная награда ----------

static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func daily_available() -> bool:
	return daily_day != today()


## День серии (0…6), который будет выдан при получении.
func daily_next_slot() -> int:
	if daily_day == today() - 1:
		return daily_streak % Retention.DAILY.size()
	return 0


func claim_daily() -> Dictionary:
	if not daily_available():
		return {}
	var slot := daily_next_slot()
	daily_streak = slot + 1
	daily_day = today()
	var reward: Dictionary = Retention.DAILY[slot]
	var result := {"slot": slot}
	if reward.has("coins"):
		var coins_reward := maxf(100.0, income_per_second() * float(reward["coins"]))
		add_coins(coins_reward)
		result["coins"] = coins_reward
	if reward.has("diamonds"):
		diamonds += int(reward["diamonds"])
		result["diamonds"] = int(reward["diamonds"])
	if reward.has("points"):
		skill_points += int(reward["points"])
		result["points"] = int(reward["points"])
	if reward.has("dynamite"):
		result["dynamite"] = add_dynamite(int(reward["dynamite"]))
	return result


# ---------- Экспедиции ----------

func expedition_active() -> bool:
	return expedition_type >= 0


func expedition_remaining() -> float:
	return maxf(0.0, expedition_end - Time.get_unix_time_from_system()) if expedition_active() else 0.0


func expedition_ready() -> bool:
	return expedition_active() and expedition_remaining() <= 0.0


func start_expedition(index: int) -> bool:
	if expedition_active() or index < 0 or index >= Retention.EXPEDITIONS.size():
		return false
	expedition_type = index
	expedition_end = Time.get_unix_time_from_system() + float(Retention.EXPEDITIONS[index]["hours"]) * 3600.0
	return true


## Забирает добычу похода: монеты от дохода, алмазы, находки в журнал. Возвращает итог для окна.
func claim_expedition() -> Dictionary:
	if not expedition_ready():
		return {}
	var data: Dictionary = Retention.EXPEDITIONS[expedition_type]
	var bonus := 1.0 + 0.5 * int(meta["expedition"])
	var coins_reward := maxf(100.0, income_per_second() * float(data["hours"]) * 3600.0 * float(data["coins"])) * bonus
	add_coins(coins_reward)
	var diamonds_reward := int(round(float(data["diamonds"]) * bonus))
	diamonds += diamonds_reward
	var dynamite_reward := add_dynamite(int(data.get("dynamite", 0)))
	var found := {1: 0, 2: 0, 3: 0, 4: 0}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var total_weight := 0
	for w in Retention.FIND_WEIGHTS:
		total_weight += int(w)
	for i in int(round(float(data["finds"]) * bonus)):
		var roll := rng.randi_range(1, total_weight)
		var ore := 1
		var acc := 0
		for j in Retention.FIND_WEIGHTS.size():
			acc += int(Retention.FIND_WEIGHTS[j])
			if roll <= acc:
				ore = j + 1
				break
		finds[ore] = int(finds[ore]) + 1
		found[ore] = int(found[ore]) + 1
	expedition_type = -1
	expedition_end = 0.0
	return {"coins": coins_reward, "diamonds": diamonds_reward, "dynamite": dynamite_reward, "found": found}


## Есть что забрать или потратить: журнал в шапке подсвечивается.
func needs_attention() -> bool:
	return skill_points > 0 or claimable_achievements() > 0 or expedition_ready() or planet_ready()


## Подсказка показывается один раз: возвращает true, если это первый раз (и запоминает).
func take_hint(id: String) -> bool:
	if hints_seen.has(id):
		return false
	hints_seen[id] = true
	return true


# ---------- Новая планета ----------

func planet_scale() -> float:
	return Biomes.scale_for(planet)


func start_bonus_levels() -> int:
	return 3 * int(meta["start"])


## Сколько секунд до следующего показа рекламы в этом месте (0 — можно).
func ad_remaining(placement: String) -> float:
	return maxf(0.0, float(ad_ready_at.get(placement, 0.0)) - Time.get_unix_time_from_system())


func ad_mark(placement: String) -> void:
	ad_ready_at[placement] = Time.get_unix_time_from_system() + float(Ads.PLACEMENTS[placement]["cooldown"])


## Алмазы за рекламу: растут с зоной.
func ad_diamonds() -> int:
	return 3 + Biomes.index_for(total_earned, planet_scale())


## Секунд между автопокупками (0 — не куплено).
func autobuy_interval() -> float:
	return [0.0, 6.0, 3.0, 1.5][clampi(int(meta["autobuy"]), 0, 3)]


## Покупает один уровень самого дешёвого из доступных улучшений; возвращает его ключ или "".
func autobuy_step() -> String:
	var best := ""
	var best_price := INF
	for key in ORDER:
		var price := cost(key)
		if price <= coins and price < best_price:
			best = key
			best_price = price
	if best != "":
		buy_n(best, 1)
	return best


func offline_cap_seconds() -> float:
	return OFFLINE_CAP_SECONDS + 4.0 * 3600.0 * int(meta["offline"])


## Ядро достигнуто на этой планете: можно лететь на следующую.
func planet_ready() -> bool:
	return Biomes.index_for(total_earned, planet_scale()) >= Biomes.CORE


## Звёздная пыль за «Новую планету»: растёт с планетой и с числом жил.
func planet_gain() -> int:
	return 3 + 2 * planet + int(sqrt(float(veins)) / 8.0)


func meta_level(id: String) -> int:
	return int(meta[id])


## Цена следующего уровня в звёздной пыли; 0, если улучшение прокачано.
func meta_cost(id: String) -> int:
	for entry in META:
		if str(entry["id"]) == id:
			var costs: Array = entry["costs"]
			var level := meta_level(id)
			return 0 if level >= costs.size() else int(costs[level])
	return 0


func buy_meta(id: String) -> bool:
	var price := meta_cost(id)
	if price <= 0 or stardust < price:
		return false
	stardust -= price
	meta[id] = meta_level(id) + 1
	return true


## «Новая планета»: монеты, улучшения, жилы и глубина сбрасываются; остаются навыки, коллекция, алмазы, достижения и мета.
## Возвращает полученную звёздную пыль (0, если ядро ещё не достигнуто).
func new_planet() -> int:
	if not planet_ready():
		return 0
	var gained := planet_gain()
	stardust += gained
	planet += 1
	dynamite_zone_best = 0
	veins = 0
	total_earned = 0.0
	coins = 0.0
	boost_time = 0.0
	ending_seen = false
	_reset_run_levels()
	return gained


## Улучшения в начале забега: нули плюс стартовые уровни из мета-улучшения.
func _reset_run_levels() -> void:
	for key in ORDER:
		levels[key] = 0
	levels["rain"] = start_bonus_levels()
	levels["faces"] = start_bonus_levels()


func find_level(ore: int) -> int:
	var level := 0
	for need in MILESTONES:
		if int(finds[ore]) >= int(need):
			level += 1
	return level


func collection_levels_sum() -> int:
	var sum := 0
	for ore in ORES:
		sum += find_level(ore)
	return sum


func full_set_level() -> int:
	var lowest := MILESTONES.size()
	for ore in ORES:
		lowest = mini(lowest, find_level(ore))
	return lowest


func collection_multiplier() -> float:
	return (1.0 + COLLECTION_STEP * collection_levels_sum()) * (1.0 + FULL_SET_STEP * full_set_level())


## Подобрана находка: в журнал; золото продлевает/запускает буст, алмаз — в кошелёк.
func collect_find(ore: int) -> void:
	if not finds.has(ore):
		return
	finds[ore] = int(finds[ore]) + 1
	match ore:
		3:
			# золотые находки во время лихорадки её не продлевают (иначе при быстром потоке она шла бы бесконечно)
			if boost_time <= 0.0 and mini_cooldown <= 0.0:
				boost_factor = MINI_FACTOR
				boost_time = mini_seconds()
		4:
			diamonds += 1


## Тик бустов: убывает время; когда малый запал закончился, включается пауза до следующего.
func tick_boost(delta: float) -> void:
	if boost_time > 0.0:
		boost_time = maxf(0.0, boost_time - delta)
		if boost_time <= 0.0 and boost_factor < BOOST_FACTOR:
			mini_cooldown = MINI_COOLDOWN
	elif mini_cooldown > 0.0:
		mini_cooldown = maxf(0.0, mini_cooldown - delta)


## «Золотая лихорадка»: ×7 на заданное время (продлевается, если уже идёт, но не дольше RUSH_CAP_SECONDS).
## stack = false (золотая глыба): время не складывается с идущей лихорадкой, а лишь обновляется до seconds.
func start_rush(seconds: float = BOOST_SECONDS, stack := true) -> void:
	var was_rush := boost_time > 0.0 and boost_factor >= BOOST_FACTOR
	boost_factor = BOOST_FACTOR
	if was_rush:
		boost_time = minf(boost_time + seconds, RUSH_CAP_SECONDS) if stack else maxf(boost_time, seconds)
	else:
		boost_time = seconds


## Секунд до следующей покупки лихорадки за алмазы (0 — можно).
func rush_remaining() -> float:
	return maxf(0.0, rush_ready_at - Time.get_unix_time_from_system())


## Цены лавки растут с зоной: за лихорадку и за мгновенную перезарядку динамита.
func shop_cost(item: String) -> int:
	var zone := Biomes.index_for(total_earned, planet_scale())
	if item.begins_with("style_"):
		return STYLE_PRICES.get(int(item.substr(6)), 50)
	match item:
		"dynamite":
			return 3 + zone                     # за три динамита
		"golden":
			return 4 * (1 + zone)
		"boss":
			return 6 + 3 * zone
		"skill_point":
			return 20 + 10 * skill_points_bought
		"expedition_skip":
			return maxi(2, 2 * ceili(expedition_remaining() / 3600.0))
	return 5 * (1 + zone)


## Можно ли сейчас купить товар лавки (кроме цены): нужна ли для него подходящая ситуация.
func shop_available(item: String) -> bool:
	if item.begins_with("style_"):
		return not styles_bought.has(int(item.substr(6)))
	match item:
		"dynamite":
			return dynamite_stock < dynamite_max()
		"rush":
			return rush_remaining() <= 0.0
		"boss":
			return Biomes.index_for(total_earned, planet_scale()) >= 1
		"expedition_skip":
			return expedition_active() and not expedition_ready()
	return true


func vein_step() -> float:
	return VEIN_STEP + 0.03 * int(meta["veins"])


func vein_multiplier() -> float:
	return 1.0 + vein_step() * veins


## Сколько жил всего положено за всё заработанное.
func potential_veins() -> int:
	return int(pow(total_earned / VEIN_BASE, 1.0 / 3.0))


## Сколько новых жил даст «Новая шахта» прямо сейчас.
func pending_veins() -> int:
	return maxi(0, potential_veins() - veins)


## Хороший момент для сброса: жил заметно прибавится.
func prestige_recommended() -> bool:
	return pending_veins() >= maxi(PRESTIGE_GOOD_MIN, int(0.7 * veins))


## «Новая шахта»: монеты и улучшения сбрасываются, глубина и зона остаются, жилы прибавляются.
func prestige() -> int:
	var gained := pending_veins()
	if gained < 1:
		return 0
	veins += gained
	prestiges += 1
	skill_points += int((1 + int(sqrt(float(gained)))) * (1.0 + 0.2 * int(meta["wisdom"])))
	coins = 0.0
	boost_time = 0.0
	_reset_run_levels()
	return gained


## Начисляет монеты (и в общий счёт заработанного, от которого зависит глубина).
func add_coins(amount: float) -> void:
	coins += amount
	total_earned += amount
	lifetime_earned += amount


## Награда за разбитую глыбу с ценностью value.
func payout(value: int) -> float:
	return value * multiplier()


## Подписанный текст сохранения (формат v2): им же делится «код переноса».
func serialize() -> String:
	var finds_out := {}
	for ore in ORES:
		finds_out[str(ore)] = int(finds[ore])
	var data := {"coins": coins, "total_earned": total_earned, "ending_seen": ending_seen, "veins": veins, "prestiges": prestiges, "planet": planet, "stardust": stardust, "meta": meta, "play_seconds": play_seconds, "rocks_broken": rocks_broken, "lifetime_earned": lifetime_earned, "diamonds": diamonds, "tutorial_done": tutorial_done, "hints": hints_seen.keys(), "finds": finds_out, "skill_points": skill_points, "skills": skills, "golden_caught": golden_caught, "dynamite_used": dynamite_used, "dynamite_stock": dynamite_stock, "dynamite_zone_best": dynamite_zone_best, "bosses_defeated": bosses_defeated, "achievements": achievements_claimed.keys(), "daily_day": daily_day, "daily_streak": daily_streak, "expedition_type": expedition_type, "expedition_end": expedition_end, "auto_throw": auto_throw, "autobuy_on": autobuy_on, "ads_removed": ads_removed, "rush_ready_at": rush_ready_at, "skill_points_bought": skill_points_bought, "styles_bought": styles_bought, "ads_watched": ads_watched, "ad_ready_at": ad_ready_at, "levels": levels, "last_seen": Time.get_unix_time_from_system()}
	var payload := JSON.stringify(data)
	return JSON.stringify({"v": 2, "payload": payload, "sig": _sign(payload)})


func save() -> void:
	if not saving_enabled:
		return
	# пишем во временный файл и переименовываем: обрыв записи не портит основное сохранение
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("LuckyMine: cannot open %s for writing" % TEMP_PATH)
		return
	file.store_string(serialize())
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_warning("LuckyMine: save write error (%d)" % write_error)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
		return
	if FileAccess.file_exists(SAVE_PATH):
		# прошлая версия остаётся запасной копией
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))


static func _sign(payload: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, SAVE_KEY.to_utf8_buffer(), payload.to_utf8_buffer()).hex_encode()


## Читает сохранение из файла; пустой словарь, если файла нет или он повреждён. Формат v2 — {payload, sig};
## старый (просто словарь) читается как есть. При неверной подписи в результат кладётся "_tampered".
static func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not parsed.has("payload"):
		return parsed
	var payload = parsed["payload"]
	if typeof(payload) != TYPE_STRING:
		return {}
	var inner = JSON.parse_string(payload)
	if typeof(inner) != TYPE_DICTIONARY:
		return {}
	inner["_tampered"] = str(parsed.get("sig", "")) != _sign(payload)
	return inner


static func _as_dict(value) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _as_array(value) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


## Число из сохранения: не число, NaN и бесконечность заменяются значением по умолчанию.
static func _num(value, default: float) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default
	var number := float(value)
	return number if is_finite(number) else default


static func _count(value, default: int, max_value := 2000000000) -> int:
	return int(clampf(_num(value, float(default)), 0.0, float(max_value)))


## Загружает сохранение и возвращает заработанное за время отсутствия (0, если сохранения нет).
## Повреждённый основной файл заменяется запасной копией.
func load_save() -> float:
	var data := _read_save_file(SAVE_PATH)
	if data.is_empty():
		data = _read_save_file(BACKUP_PATH)
	if data.is_empty():
		return 0.0
	tampered = bool(data.get("_tampered", false))
	if tampered:
		push_warning("LuckyMine: save signature mismatch")
	coins = maxf(0.0, _num(data.get("coins"), 0.0))
	total_earned = maxf(_num(data.get("total_earned"), coins), coins)
	ending_seen = bool(data.get("ending_seen", false))
	veins = _count(data.get("veins"), 0)
	prestiges = _count(data.get("prestiges"), 0)
	planet = _count(data.get("planet"), 0, 100)
	play_seconds = maxf(0.0, _num(data.get("play_seconds"), 0.0))
	rocks_broken = _count(data.get("rocks_broken"), 0)
	lifetime_earned = maxf(_num(data.get("lifetime_earned"), total_earned), total_earned)
	stardust = _count(data.get("stardust"), 0)
	var saved_meta := _as_dict(data.get("meta"))
	for entry in META:
		var id := str(entry["id"])
		meta[id] = _count(saved_meta.get(id), 0, (entry["costs"] as Array).size())
	diamonds = _count(data.get("diamonds"), 0)
	hints_seen = {}
	for hint_id in _as_array(data.get("hints")):
		hints_seen[str(hint_id)] = true
	tutorial_done = bool(data.get("tutorial_done", true))     # у старых сохранений обучения нет
	skill_points = _count(data.get("skill_points"), START_SKILL_POINTS)
	golden_caught = _count(data.get("golden_caught"), 0)
	dynamite_used = _count(data.get("dynamite_used"), 0)
	dynamite_stock = _count(data.get("dynamite_stock"), 5)      # старые сохранения: небольшой запас
	bosses_defeated = _count(data.get("bosses_defeated"), 0)
	achievements_claimed = {}
	for id in _as_array(data.get("achievements")):
		achievements_claimed[str(id)] = true
	daily_day = int(_num(data.get("daily_day"), -1.0))
	daily_streak = _count(data.get("daily_streak"), 0)
	expedition_type = int(_num(data.get("expedition_type"), -1.0))
	if expedition_type < 0 or expedition_type >= Retention.EXPEDITIONS.size():
		expedition_type = -1
	expedition_end = _num(data.get("expedition_end"), 0.0)
	var saved_skills := _as_dict(data.get("skills"))
	for branch in skills:
		skills[branch] = clampi(int(_num(saved_skills.get(branch), 0.0)), 0, Skills.MAX_LEVEL)
	dynamite_stock = mini(dynamite_stock, dynamite_max())
	var saved_finds := _as_dict(data.get("finds"))
	for ore in ORES:
		finds[ore] = _count(saved_finds.get(str(ore)), 0)
	auto_throw = bool(data.get("auto_throw", true))
	autobuy_on = bool(data.get("autobuy_on", true))
	ads_removed = bool(data.get("ads_removed", false))
	rush_ready_at = _num(data.get("rush_ready_at"), 0.0)
	skill_points_bought = _count(data.get("skill_points_bought"), 0)
	styles_bought.clear()
	for bought in _as_array(data.get("styles_bought")):
		styles_bought.append(int(_num(bought, 0.0)))
	ads_watched = _count(data.get("ads_watched"), 0)
	ad_ready_at = {}
	var saved_ads := _as_dict(data.get("ad_ready_at"))
	for placement in Ads.PLACEMENTS:
		if saved_ads.has(placement):
			ad_ready_at[placement] = _num(saved_ads[placement], 0.0)
	var saved_levels := _as_dict(data.get("levels"))
	for key in ORDER:
		levels[key] = _count(saved_levels.get(key), 0, 100000)
	dynamite_zone_best = _count(data.get("dynamite_zone_best"), Biomes.index_for(total_earned, planet_scale()), 1000)
	var gone := maxf(0.0, Time.get_unix_time_from_system() - _num(data.get("last_seen"), 0.0))
	var away := minf(gone, offline_cap_seconds())
	offline_away = away
	offline_capped = gone > offline_cap_seconds()
	var earned := income_per_second() * away
	add_coins(earned)
	return earned


## Удаляет сохранение и его копии (сброс прогресса). Дальше сохранять нельзя, пока не перезапущена сцена.
static func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------- Перенос прогресса кодом ----------

const CODE_PREFIX := "LM1:"
const MAX_SAVE_BYTES := 2000000          # файл или код больше этого не читаем (защита от мусора в буфере обмена)


## Код со всем прогрессом: копируется в буфер обмена и вставляется на другом устройстве.
func export_code() -> String:
	return CODE_PREFIX + Marshalls.utf8_to_base64(serialize())


## Проверяет код и кладёт его на место сохранения (текущее уходит в запасную копию). true — код принят.
## Код с неверной подписью (правленный) не принимается. После успеха сцену нужно перезагрузить.
static func import_code(code: String) -> bool:
	if code.length() > MAX_SAVE_BYTES * 2:
		return false
	code = code.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	if not code.begins_with(CODE_PREFIX):
		return false
	var text := Marshalls.base64_to_utf8(code.substr(CODE_PREFIX.length()))
	if text.is_empty():
		return false
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("payload")) != TYPE_STRING:
		return false
	if str(parsed.get("sig", "")) != _sign(parsed["payload"]) or typeof(JSON.parse_string(parsed["payload"])) != TYPE_DICTIONARY:
		return false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
