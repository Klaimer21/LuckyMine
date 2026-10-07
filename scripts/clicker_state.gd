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
	# дополнительные (7 октября 2026): открываются с зоны "zone", уровней не больше "max". Числа сверены с tools/economy_sim.py (NEW_UP)
	"crit": {"base": 5000.0, "growth": 2.2, "max": 20, "zone": 1},      # «Критический обвал»: шанс глыбы заплатить ×5
	"combo": {"base": 3000.0, "growth": 2.0, "max": 10, "zone": 1},     # «Серия касаний»: бонус за глыбы от касаний подряд
	"nose": {"base": 12000.0, "growth": 2.0, "max": 15, "zone": 2},     # «Рудный нюх»: руда в глыбах чаще
	"spark": {"base": 9000.0, "growth": 2.1, "max": 10, "zone": 2},     # «Золотой запал+»: запал дольше и чаще
	"dbl": {"base": 30000.0, "growth": 2.3, "max": 20, "zone": 3},      # «Двойной улов»: шанс глыбы заплатить ×2
	"dynamo": {"base": 15000.0, "growth": 2.2, "max": 10, "zone": 3},   # «Динамитчик»: динамит копится сам
}
const CRIT_CHANCE_STEP := 0.01          # шанс крита за уровень (до 20%)
const CRIT_MULT := 5.0
const DOUBLE_CHANCE_STEP := 0.015       # шанс удвоения за уровень (до 30%)
const NOSE_STEP := 0.01                 # сдвиг порога руды за уровень «Рудного нюха»
const SPARK_SECONDS_STEP := 0.3         # секунд к «Золотому запалу» за уровень
const SPARK_COOLDOWN_STEP := 0.4        # секунд минус от паузы за уровень
const COMBO_STEP := 0.004               # прибавка к монетам за глыбы от касаний за уровень и за каждое касание серии
const COMBO_MAX := 25                   # касаний серии, дальше бонус не растёт
const COMBO_WINDOW := 1.5               # секунд между касаниями, чтобы серия шла дальше
const DYNAMO_BASE_PERIOD := 900.0       # секунд на один динамит на 0-м уровне (минус DYNAMO_STEP за уровень)
const DYNAMO_STEP := 60.0
const DYNAMO_MIN_PERIOD := 300.0
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
## Новые ветки навыков (по уровню 0…4): «Рука», «Походы», «Хранители», «Машины», «Смена».
const HAND_PAYOUT := [1.0, 1.25, 1.25, 1.6, 2.0]       # монеты за глыбы от касаний
const HAND_EXTRA := [0, 0, 1, 1, 2]                    # дополнительные глыбы за касание
const TRIPS_TIME := [1.0, 0.85, 0.85, 0.85, 0.85]
const TRIPS_RELIC := [0.40, 0.40, 0.55, 0.55, 1.0]     # шанс диковинки за поход
const TRIPS_LOOT := [0.0, 0.0, 0.0, 0.3, 0.3]          # прибавка к добыче походов
const GUARD_HP := [1.0, 0.85, 0.85, 0.85, 0.68]
const GUARD_REWARD := [1.0, 1.0, 1.25, 1.25, 1.5625]
const GOLDEN_PAYOUT := [1.0, 1.0, 1.0, 1.5, 1.5]
const SHIFT_CAP_HOURS := [0.0, 2.0, 2.0, 2.0, 6.0]
const SHIFT_INCOME := [1.0, 1.0, 1.15, 1.15, 1.3]
const SHIFT_LAB_CAP := [0, 0, 0, 12, 12]               # прибавка к офлайн-алмазам Лаборатории
const ORDER := ["rain", "tap", "faces", "mult", "crit", "combo", "nose", "spark", "dbl", "dynamo"]
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
var levels := {"rain": 0, "tap": 0, "faces": 0, "mult": 0, "crit": 0, "combo": 0, "nose": 0, "spark": 0, "dbl": 0, "dynamo": 0}
var upgrades_unlocked := {}            # key -> true: открытые дополнительные улучшения (остаются навсегда)
var dynamo_progress := 0.0             # секунд до следующего динамита «Динамитчика»
var combo := 0                         # касаний подряд (не сохраняется)
var combo_left := 0.0
var machines := Machines.blank_levels()   # уровни машин (сбрасываются с «Новой шахтой»)
var machines_unlocked := {}            # id -> true: открытые машины (остаются навсегда)
var machine_boost_time := 0.0          # реклама «Машины ×2»: секунд осталось (не сохраняется)
var lab_progress := 0.0                # секунд накоплено до следующего алмаза Лаборатории
var offline_lab_diamonds := 0          # алмазов от Лаборатории за последнее отсутствие
var last_seen := 0.0
var auto_throw := true
var autobuy_on := true               # включатель автопокупки (работает, если куплено мета-улучшение)
var ads_removed := false             # куплено «Убрать рекламу»: награда выдаётся без ролика
var ads_watched := 0
var ad_ready_at := {}                # место рекламы -> unix-время, когда можно снова
var offline_away := 0.0              # сколько секунд игрока не было при последней загрузке (с учётом лимита)
var offline_capped := false          # время офлайна упёрлось в лимит
var skill_points := START_SKILL_POINTS
var skills := {"drill": 0, "dynamite": 0, "luck": 0, "yield": 0, "hand": 0, "trips": 0, "guard": 0, "machines": 0, "shift": 0}
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
## Диковинки из экспедиций (коллекция, не сбрасывается престижем): виды и сколько найдено каждой.
const RELICS := ["map", "coin", "bone", "crystal"]
const RELIC_CHANCE := 0.4                     # шанс диковинки за экспедицию
var relics := {"map": 0, "coin": 0, "bone": 0, "crystal": 0}
var boost_factor := BOOST_FACTOR
var mini_cooldown := 0.0
var skill_points_bought := 0         # купленные за алмазы очки навыков (цена растёт)
var styles_bought: Array = []        # индексы пород, купленных за алмазы
var rush_ready_at := 0.0            # unix-время, когда лихорадку за алмазы можно купить снова
var boost_time := 0.0             # «Золотая лихорадка»: сколько секунд осталось (не сохраняется)


## Сколько глыб падает в секунду сами.
func rain_rate() -> float:
	return (1.0 + 0.8 * levels["rain"]) * (1.0 + float(DRILL_BONUS[skill_level("drill")]))


## Глыбы в секунду от Дробилки: доля потока «Камнепада» за каждый уровень машины (и навык «Бур» действует на оба потока).
func crusher_rate() -> float:
	var info: Dictionary = Machines.data("crusher")
	return float(info["step"]) * machine_level("crusher") * (1.0 + 0.8 * levels["rain"]) * (1.0 + float(DRILL_BONUS[skill_level("drill")])) * machine_boost_factor() * (1.15 if skill_level("machines") >= 1 else 1.0)


## Все глыбы в секунду: «Камнепад» плюс машины.
func total_rock_rate() -> float:
	return rain_rate() + crusher_rate()


## Реклама «Машины ×2»: Дробилка и Подрывник работают вдвое быстрее, пока идёт время.
func machine_boost_factor() -> float:
	return Machines.AD_BOOST_FACTOR if machine_boost_time > 0.0 else 1.0


## Лаборатория: секунд на один алмаз (0 — не куплена).
func lab_interval() -> float:
	var level := machine_level("lab")
	if level < 1:
		return 0.0
	return maxf(Machines.LAB_MIN_PERIOD, Machines.LAB_BASE_PERIOD - float(Machines.data("lab")["step"]) * level) * (0.8 if skill_level("machines") >= 4 else 1.0)


## Вагонетка: пауза между «Золотыми запалами» и их длительность.
func mini_cooldown_seconds() -> float:
	return maxf(2.0, MINI_COOLDOWN - float(Machines.data("cart")["step"]) * machine_level("cart") - SPARK_COOLDOWN_STEP * int(levels["spark"]))


## Каждый кадр: время рекламного буста машин и капли алмазов Лаборатории. Возвращает, сколько алмазов только что выпало.
func tick_machines(delta: float) -> int:
	machine_boost_time = maxf(0.0, machine_boost_time - delta)
	var interval := lab_interval()
	if interval <= 0.0:
		lab_progress = 0.0
		return 0
	lab_progress += delta
	var gained := 0
	while lab_progress >= interval and gained < 5:
		lab_progress -= interval
		diamonds += 1
		gained += 1
	return gained


## Конвейер: на сколько опускаются пороги ценности, с которых в глыбе есть руда (доля от максимума).
func ore_shift() -> float:
	return (float(Machines.data("conveyor")["step"]) * machine_level("conveyor") + float(Machines.data("rover")["step"]) * machine_level("rover")) * (1.25 if skill_level("machines") >= 4 else 1.0) + NOSE_STEP * int(levels["nose"])


## Подрывник: секунд между малыми взрывами (0 — не куплен).
func blaster_interval() -> float:
	var level := machine_level("blaster")
	if level < 1:
		return 0.0
	return maxf(Machines.BLASTER_MIN_PERIOD, Machines.BLASTER_BASE_PERIOD - float(Machines.data("blaster")["step"]) * level) / machine_boost_factor() * (0.85 if skill_level("machines") >= 2 else 1.0)


## Доля дохода от глыб, которую в среднем добавляют взрывы Подрывника.
func blaster_share() -> float:
	var interval := blaster_interval()
	return Machines.BLASTER_SECONDS / interval if interval > 0.0 else 0.0


## Лебёдка: во сколько раз походы короче обычного.
func expedition_time_factor() -> float:
	return (1.0 - float(Machines.data("winch")["step"]) * machine_level("winch")) * float(TRIPS_TIME[skill_level("trips")])


## Длительность похода типа index с учётом Лебёдки.
func expedition_total_seconds(index: int) -> float:
	return float(Retention.EXPEDITIONS[index]["hours"]) * 3600.0 * expedition_time_factor()


func rocks_per_throw() -> int:
	return 1 + levels["tap"] + int(HAND_EXTRA[skill_level("hand")])


## Навык «Рука»: во сколько раз больше монет за глыбы от касаний.
func hand_payout_factor() -> float:
	return float(HAND_PAYOUT[skill_level("hand")])


## Навык «Хранители»: золотая глыба, пойманная касанием, платит больше.
func golden_payout_factor() -> float:
	return float(GOLDEN_PAYOUT[skill_level("guard")]) * (1.0 + float(Machines.data("catapult")["step"]) * machine_level("catapult"))


## Реклама «Машины ×2» идёт столько секунд (навык «Машины» удваивает).
func machine_boost_seconds() -> float:
	return Machines.AD_BOOST_SECONDS * (2.0 if skill_level("machines") >= 3 else 1.0)


## Шанс диковинки за поход (навык «Походы»; на 4-м уровне она в каждом походе).
func relic_chance() -> float:
	return float(TRIPS_RELIC[skill_level("trips")])


## Прибавка к добыче похода: мета «Снаряжение походов» и навык «Походы».
func expedition_bonus() -> float:
	return 1.0 + 0.5 * int(meta["expedition"]) + float(TRIPS_LOOT[skill_level("trips")])


## Наибольшая ценность руды (глыба даёт от 1 до этого числа).
func max_face() -> int:
	return 6 + 2 * levels["faces"]


## Множитель добычи: улучшение «Добыча», бонус зоны и «Золотая лихорадка» (×7 после касания золотой глыбы).
func multiplier() -> float:
	return pow(1.5, levels["mult"]) * Biomes.factor(total_earned, planet_scale()) * vein_multiplier() * collection_multiplier() * (1.0 + 0.2 * int(meta["income"])) * float(YIELD_BONUS[skill_level("yield")]) * (boost_factor if boost_time > 0.0 else 1.0)


## Шанс критического обвала и удвоения (улучшения «Критический обвал» и «Двойной улов»).
func crit_chance() -> float:
	return CRIT_CHANCE_STEP * int(levels["crit"])


func double_chance() -> float:
	return DOUBLE_CHANCE_STEP * int(levels["dbl"])


## Во сколько раз в среднем крит и удвоение увеличивают выплату глыбы (мат. ожидание; по нему считаются доход, офлайн и награды).
func payout_ev() -> float:
	return (1.0 + crit_chance() * (CRIT_MULT - 1.0)) * (1.0 + double_chance())


## «Серия касаний»: касание (или «Обвал») продолжает серию, если с прошлого прошло не больше COMBO_WINDOW секунд.
func note_tap() -> void:
	combo = combo + 1 if combo_left > 0.0 else 1
	combo_left = COMBO_WINDOW


func tick_combo(delta: float) -> void:
	if combo_left > 0.0:
		combo_left = maxf(0.0, combo_left - delta)
		if combo_left <= 0.0:
			combo = 0


## Бонус монет за глыбы от касаний по серии (уровень «Серии касаний» × касаний в серии, до COMBO_MAX).
func combo_bonus() -> float:
	return 1.0 + COMBO_STEP * int(levels["combo"]) * mini(combo, COMBO_MAX)


## «Динамитчик»: секунд на один динамит (0 — не куплен).
func dynamo_period() -> float:
	var level := int(levels["dynamo"])
	return 0.0 if level <= 0 else maxf(DYNAMO_MIN_PERIOD, DYNAMO_BASE_PERIOD - DYNAMO_STEP * level)


## Каждый кадр: копит динамит «Динамитчика»; возвращает, сколько динамита только что добавилось.
func tick_dynamo(delta: float) -> int:
	var period := dynamo_period()
	if period <= 0.0:
		dynamo_progress = 0.0
		return 0
	dynamo_progress += delta
	var added := 0
	while dynamo_progress >= period:
		dynamo_progress -= period
		added += add_dynamite(1)
	return added


func average_value() -> float:
	return (1.0 + max_face()) / 2.0 * multiplier()


## Доход от глыб без взрывов Подрывника (по нему же считается награда взрыва).
func base_income_per_second() -> float:
	return total_rock_rate() * average_value() * payout_ev()


func income_per_second() -> float:
	return base_income_per_second() * (1.0 + blaster_share())


func cost(key: String) -> float:
	var info: Dictionary = UPGRADES[key]
	if not upgrade_unlocked(key) or upgrade_maxed(key):
		return INF                       # закрытое или добранное до предела улучшение не покупается (и не попадает в «самое дешёвое»)
	return float(info["base"]) * pow(float(info["growth"]), levels[key])


## Предел уровней улучшения (у первых четырёх нет).
func upgrade_cap(key: String) -> int:
	return int((UPGRADES[key] as Dictionary).get("max", 1000000))


func upgrade_maxed(key: String) -> bool:
	return int(levels[key]) >= upgrade_cap(key)


## Открыто ли улучшение (у первых четырёх условия нет; остальные открываются с зоны и остаются).
func upgrade_unlocked(key: String) -> bool:
	return not (UPGRADES[key] as Dictionary).has("zone") or upgrades_unlocked.has(key)


## Открывает улучшения, до зоны которых игрок дошёл; возвращает только что открытые (для сообщения).
func update_upgrade_unlocks() -> Array:
	var opened: Array = []
	var zone := Biomes.index_for(total_earned, planet_scale())
	for key in ORDER:
		var info: Dictionary = UPGRADES[key]
		if info.has("zone") and not upgrades_unlocked.has(key) and zone >= int(info["zone"]):
			upgrades_unlocked[key] = true
			opened.append(key)
	return opened


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
	var room := upgrade_cap(key) - int(levels[key])
	var n := int(floor(log(coins * (growth - 1.0) / first + 1.0) / log(growth)))
	while n > 0 and cost_for(key, n) > coins:
		n -= 1
	while n < MAX_BULK and n < room and cost_for(key, n + 1) <= coins:
		n += 1
	return mini(mini(n, MAX_BULK), room)


## Покупает ровно n уровней или ничего; возвращает, сколько куплено.
func buy_n(key: String, n: int) -> int:
	if n < 1 or not upgrade_unlocked(key):
		return 0
	n = mini(n, upgrade_cap(key) - int(levels[key]))      # выше предела не покупается
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
	return int(DYNAMITE_CAPS[skill_level("dynamite")]) + int(float(Machines.data("burner")["step"]) * machine_level("burner") + 0.01)


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
	return DYNAMITE_SECONDS[skill_level("dynamite")] + float(Machines.data("reactor")["step"]) * machine_level("reactor")


## Находок, которые динамит выбивает из породы: 3 плюс по одной за каждые две зоны.
func dynamite_finds() -> int:
	return 3 + floori(Biomes.index_for(total_earned, planet_scale()) / 2.0)


func dynamite_chain() -> float:
	return DYNAMITE_CHAIN if skill_level("dynamite") >= 3 else 0.0


func dynamite_spark() -> bool:
	return skill_level("dynamite") >= 4


func diamond_chance_factor() -> float:
	return (1.3 if skill_level("luck") >= 1 else 1.0) * (1.0 + 0.25 * int(meta["diamonds"])) * (1.25 if Biomes.planet_mod(planet) == "diamonds" else 1.0) * (1.0 + float(Machines.data("compressor")["step"]) * machine_level("compressor"))


func mini_seconds() -> float:
	return MINI_SECONDS + (2.0 if skill_level("luck") >= 2 else 0.0) + Machines.CART_SECONDS_STEP * machine_level("cart") + SPARK_SECONDS_STEP * int(levels["spark"])


func golden_interval_factor() -> float:
	return (0.7 if skill_level("luck") >= 3 else 1.0) * (0.7 if Biomes.planet_mod(planet) == "golden" else 1.0) * (1.0 - float(Machines.data("excavator")["step"]) * machine_level("excavator"))


## Хранители зон на планете «Венера» слабее на 30% и платят вдвое; мета «Охотник на хранителей» добавляет +50% за уровень.
func boss_hp_factor() -> float:
	return (0.7 if Biomes.planet_mod(planet) == "boss" else 1.0) * float(GUARD_HP[skill_level("guard")]) * (1.0 - float(Machines.data("acid")["step"]) * machine_level("acid"))


func boss_reward_factor() -> float:
	return (2.0 if Biomes.planet_mod(planet) == "boss" else 1.0) * (1.0 + 0.5 * int(meta["guardian"])) * float(GUARD_REWARD[skill_level("guard")]) * (1.0 + float(Machines.data("solar")["step"]) * machine_level("solar"))


func lucky_rock_chance() -> float:
	return 0.03 if skill_level("luck") >= 4 else 0.0


## Короткий «Золотой запал» (например, от динамита): не перебивает идущий буст.
func start_mini(seconds: float) -> void:
	if boost_time <= 0.0:
		boost_factor = MINI_FACTOR
		boost_time = seconds


# ---------- Машины ----------

func machine_level(id: String) -> int:
	return int(machines.get(id, 0))


func machine_unlocked(id: String) -> bool:
	return machines_unlocked.has(id)


## Сколько ходов ленты нужно полю: 4, пятый добавляют машины Марса и Луны, шестой машины Титана и Венеры.
func field_lanes() -> int:
	var lanes := 4
	var inner := false
	var outer := false
	for entry in Machines.LIST:
		var from := Machines.planet_of(entry)
		if from > 0 and machine_unlocked(str(entry["id"])):
			if from <= 2:
				inner = true
			else:
				outer = true
	if inner or outer:
		lanes = 5
	if outer:
		lanes = 6
	return lanes


## Выполнено ли условие открытия машины: достаточно уровня «Камнепада» или зоны шахты.
func _machine_condition_met(entry: Dictionary) -> bool:
	var planet_need := Machines.planet_of(entry)
	if planet_need > 0:
		# машина планеты: нужна эта планета (или дальше) и зона на ней; открытая остаётся навсегда
		if planet < planet_need:
			return false
		if planet > planet_need:
			return true
		return Biomes.index_for(total_earned, planet_scale()) >= int(entry["unlock_zone"])
	var rain_need := int(entry["unlock_rain"])
	var zone_need := int(entry["unlock_zone"])
	if rain_need > 0 and int(levels["rain"]) >= rain_need:
		return true
	return zone_need >= 0 and Biomes.index_for(total_earned, planet_scale()) >= zone_need


## Открывает машины, условия которых выполнены; возвращает только что открытые (для сообщения игроку).
func update_machine_unlocks() -> Array:
	var opened: Array = []
	for entry in Machines.LIST:
		var id := str(entry["id"])
		if not machines_unlocked.has(id) and _machine_condition_met(entry):
			machines_unlocked[id] = true
			opened.append(id)
	return opened


## Цена n следующих уровней машины (геометрическая прогрессия, масштаб планеты как у зон).
func machine_cost(id: String, n: int) -> float:
	var info: Dictionary = Machines.data(id)
	var growth := float(info["growth"])
	var level := machine_level(id)
	return float(info["base_cost"]) * planet_scale() * pow(growth, level) * (pow(growth, n) - 1.0) / (growth - 1.0)


func machine_max_level(id: String) -> int:
	return int(Machines.data(id)["max_level"])


## Сколько уровней подряд хватит монет купить (не больше предела машины).
func machine_max_affordable(id: String) -> int:
	var n := 0
	var room := machine_max_level(id) - machine_level(id)
	while n < room and machine_cost(id, n + 1) <= coins:
		n += 1
	return n


## Покупает ровно n уровней (но не выше предела) или ничего; возвращает, сколько куплено.
func buy_machine(id: String, n: int) -> int:
	if not machine_unlocked(id) or n < 1:
		return 0
	n = mini(n, machine_max_level(id) - machine_level(id))
	if n < 1:
		return 0
	var price := machine_cost(id, n)
	if not (coins >= price):
		return 0
	coins -= price
	machines[id] = machine_level(id) + n
	return n


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
		"relics":
			return float(relic_kinds())
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

## Текущее время (unix, секунды). Всё, что зависит от часов (офлайн, походы, награды, реклама), берёт его отсюда;
## clock_offset нужен тестам: сдвигает «часы» вперёд и назад.
static var clock_offset := 0.0


static func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset


static func today() -> int:
	return int(now() / 86400.0)


func daily_available() -> bool:
	return today() > daily_day          # откат часов назад не даёт забрать награду второй раз


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
	if not expedition_active():
		return 0.0
	var total := expedition_total_seconds(expedition_type)
	return clampf(expedition_end - now(), 0.0, total)       # откат часов не растягивает поход дольше его длительности


func expedition_ready() -> bool:
	return expedition_active() and expedition_remaining() <= 0.0


func start_expedition(index: int) -> bool:
	if expedition_active() or index < 0 or index >= Retention.EXPEDITIONS.size():
		return false
	expedition_type = index
	expedition_end = now() + expedition_total_seconds(index)
	return true


## Забирает добычу похода: монеты от дохода, алмазы, находки в журнал. Возвращает итог для окна.
func claim_expedition() -> Dictionary:
	if not expedition_ready():
		return {}
	var data: Dictionary = Retention.EXPEDITIONS[expedition_type]
	var bonus := expedition_bonus()
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
	var relic := ""
	if rng.randf() < relic_chance():
		relic = str(RELICS[rng.randi() % RELICS.size()])
		relics[relic] = int(relics[relic]) + 1
	return {"coins": coins_reward, "diamonds": diamonds_reward, "dynamite": dynamite_reward, "found": found, "relic": relic}


## Сколько разных диковинок найдено (для достижения «Коллекционер»).
func relic_kinds() -> int:
	var kinds := 0
	for id in RELICS:
		if int(relics[id]) > 0:
			kinds += 1
	return kinds


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
	return maxf(0.0, float(ad_ready_at.get(placement, 0.0)) - now())


func ad_mark(placement: String) -> void:
	ad_ready_at[placement] = now() + float(Ads.PLACEMENTS[placement]["cooldown"])


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
	return OFFLINE_CAP_SECONDS + 4.0 * 3600.0 * int(meta["offline"]) + Machines.WINCH_OFFLINE_STEP * machine_level("winch") + 3600.0 * float(SHIFT_CAP_HOURS[skill_level("shift")])


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
	for id in machines:
		machines[id] = 0
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
	return (1.0 + COLLECTION_STEP * collection_levels_sum()) * (1.0 + FULL_SET_STEP * full_set_level()) * relic_multiplier()


## Бонус диковинок: +2% к доходу за каждую найденную разновидность и ещё +4% за полный набор (всего до ×1.12).
const RELIC_STEP := 0.02
const RELIC_SET_BONUS := 0.04


func relic_multiplier() -> float:
	var kinds := relic_kinds()
	return 1.0 + RELIC_STEP * kinds + (RELIC_SET_BONUS if kinds == RELICS.size() else 0.0)


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
			mini_cooldown = mini_cooldown_seconds()
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
	return maxf(0.0, rush_ready_at - now())


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
	var data := {"coins": coins, "total_earned": total_earned, "ending_seen": ending_seen, "veins": veins, "prestiges": prestiges, "planet": planet, "stardust": stardust, "meta": meta, "play_seconds": play_seconds, "rocks_broken": rocks_broken, "lifetime_earned": lifetime_earned, "diamonds": diamonds, "tutorial_done": tutorial_done, "hints": hints_seen.keys(), "finds": finds_out, "skill_points": skill_points, "skills": skills, "golden_caught": golden_caught, "relics": relics, "dynamite_used": dynamite_used, "dynamite_stock": dynamite_stock, "dynamite_zone_best": dynamite_zone_best, "bosses_defeated": bosses_defeated, "achievements": achievements_claimed.keys(), "daily_day": daily_day, "daily_streak": daily_streak, "expedition_type": expedition_type, "expedition_end": expedition_end, "auto_throw": auto_throw, "autobuy_on": autobuy_on, "ads_removed": ads_removed, "rush_ready_at": rush_ready_at, "skill_points_bought": skill_points_bought, "styles_bought": styles_bought, "ads_watched": ads_watched, "ad_ready_at": ad_ready_at, "levels": levels, "upgrades_unlocked": upgrades_unlocked.keys(), "dynamo_progress": dynamo_progress, "machines": machines, "machines_unlocked": machines_unlocked.keys(), "lab_progress": lab_progress, "last_seen": now()}
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
	return _parse_save_text(file.get_as_text())


static func _parse_save_text(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
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
	return _apply_save(data)


## То же из текста (serialize()): без диска, для тестов.
func load_from_text(text: String) -> float:
	return _apply_save(_parse_save_text(text))


func _apply_save(data: Dictionary) -> float:
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
	var saved_relics := _as_dict(data.get("relics"))
	for id in RELICS:
		relics[id] = _count(saved_relics.get(id), 0)
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
	dynamite_stock = mini(dynamite_stock, maxi(dynamite_max(), 99))      # запас может быть выше вместимости (после «Новой шахты» уровень Горелки сбрасывается): не отнимаем, только не добавляем
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
		levels[key] = _count(saved_levels.get(key), 0, upgrade_cap(key) if key in ["crit", "combo", "nose", "spark", "dbl", "dynamo"] else 100000)
	upgrades_unlocked = {}
	for key in _as_array(data.get("upgrades_unlocked")):
		if UPGRADES.has(str(key)) and (UPGRADES[str(key)] as Dictionary).has("zone"):
			upgrades_unlocked[str(key)] = true
	dynamo_progress = clampf(_num(data.get("dynamo_progress"), 0.0), 0.0, 100000.0)
	var saved_machines := _as_dict(data.get("machines"))
	for id in Machines.ids():
		machines[id] = _count(saved_machines.get(id), 0, int(Machines.data(id)["max_level"]))
	lab_progress = clampf(_num(data.get("lab_progress"), 0.0), 0.0, 100000.0)
	machines_unlocked = {}
	for id in _as_array(data.get("machines_unlocked")):
		if Machines.ids().has(str(id)):
			machines_unlocked[str(id)] = true
	dynamite_zone_best = _count(data.get("dynamite_zone_best"), Biomes.index_for(total_earned, planet_scale()), 1000)
	update_machine_unlocks()
	var gone := maxf(0.0, now() - _num(data.get("last_seen"), 0.0))
	var away := minf(gone, offline_cap_seconds())
	offline_away = away
	offline_lab_diamonds = 0
	var lab_period := lab_interval()
	if lab_period > 0.0:
		offline_lab_diamonds = mini(floori((away + lab_progress) / lab_period), Machines.LAB_OFFLINE_CAP + int(SHIFT_LAB_CAP[skill_level("shift")]))
		diamonds += offline_lab_diamonds
	update_upgrade_unlocks()
	var dynamo := dynamo_period()
	if dynamo > 0.0:
		var made := floori((away + dynamo_progress) / dynamo)
		add_dynamite(made)
		dynamo_progress = fposmod(away + dynamo_progress, dynamo)
	offline_capped = gone > offline_cap_seconds()
	var earned := income_per_second() * away * float(SHIFT_INCOME[skill_level("shift")]) * (1.0 + 0.01 * machine_level("solar"))
	add_coins(earned)
	return earned


## Удаляет сохранение и его копии (сброс прогресса). Дальше сохранять нельзя, пока не перезапущена сцена.
static func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------- Перенос прогресса кодом ----------

const CODE_PREFIX := "LM2:"
const CODE_TTL := 3600.0                  # код действует час: старый код, пересланный другим, больше не работает
const USED_CODES_PATH := "user://luckymine_used_codes.json"
const MAX_SAVE_BYTES := 2000000          # файл или код больше этого не читаем (защита от мусора в буфере обмена)


## Код со всем прогрессом: копируется в буфер обмена и вставляется на другом устройстве. Действует час, один раз на
## устройство (код уже введённый здесь повторно не принимается), покупки не переносятся (их возвращает магазин).
func export_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wrapper := JSON.stringify({"save": serialize(), "exp": now() + CODE_TTL, "id": "%08x%08x" % [rng.randi(), rng.randi()]})
	return CODE_PREFIX + Marshalls.utf8_to_base64(JSON.stringify({"w": wrapper, "sig": _sign(wrapper)}))


static func _used_code_ids() -> Array:
	if not FileAccess.file_exists(USED_CODES_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(USED_CODES_PATH))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


static func _remember_code_id(id: String) -> void:
	var ids := _used_code_ids()
	ids.append(id)
	if ids.size() > 50:
		ids = ids.slice(ids.size() - 50)
	var file := FileAccess.open(USED_CODES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(ids))
		file.close()


## Кладёт сохранение из облака на место локального (текущее уходит в запасную копию). Подпись проверяется; true — принято.
## После успеха сцену нужно перезагрузить.
static func import_save_text(text: String) -> bool:
	if text.length() > MAX_SAVE_BYTES:
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


## Проверяет код и кладёт его на место сохранения (текущее уходит в запасную копию). true — код принят.
## Не принимается: код с неверной подписью, просроченный, уже введённый на этом устройстве. После успеха сцену нужно перезагрузить.
static func import_code(code: String) -> bool:
	if code.length() > MAX_SAVE_BYTES * 2:
		return false
	code = code.strip_edges().replace("
", "").replace("
", "").replace(" ", "")
	if not code.begins_with(CODE_PREFIX):
		return false
	var outer = JSON.parse_string(Marshalls.base64_to_utf8(code.substr(CODE_PREFIX.length())))
	if typeof(outer) != TYPE_DICTIONARY or typeof(outer.get("w")) != TYPE_STRING or str(outer.get("sig", "")) != _sign(outer["w"]):
		return false
	var wrapper = JSON.parse_string(outer["w"])
	if typeof(wrapper) != TYPE_DICTIONARY or typeof(wrapper.get("save")) != TYPE_STRING:
		return false
	if now() > _num(wrapper.get("exp"), 0.0):
		return false                      # просрочен
	var id := str(wrapper.get("id", ""))
	if id == "" or _used_code_ids().has(id):
		return false                      # уже вводили
	var parsed = JSON.parse_string(wrapper["save"])
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("payload")) != TYPE_STRING:
		return false
	if str(parsed.get("sig", "")) != _sign(parsed["payload"]) or typeof(JSON.parse_string(parsed["payload"])) != TYPE_DICTIONARY:
		return false
	# покупки не переезжают с кодом: «убрать рекламу» восстанавливается через магазин (подпись ставим заново)
	var data: Dictionary = JSON.parse_string(parsed["payload"])
	data["ads_removed"] = false
	var payload := JSON.stringify(data)
	var text := JSON.stringify({"v": 2, "payload": payload, "sig": _sign(payload)})
	_remember_code_id(id)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
