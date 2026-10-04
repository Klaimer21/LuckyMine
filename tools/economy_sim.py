"""Симулятор экономики LuckyMine. Идеальный игрок без касаний: жадно покупает улучшения, делает «Новую шахту», когда
прибавится не меньше max(5, 0.7 × имеющихся) жил. Учитывает: жилы, бонус зон, коллекцию руды (находки считаются по
вероятностям руды в зоне), алмазы (дроп, цена «Золотой лихорадки» в лавке), навык «Бур» и очки навыков.
Не учитывает то, что требует касаний: золотые глыбы, динамит, хранителей, экспедиции, ежедневные награды.
Числа должны совпадать с scripts/clicker_state.gd, scripts/biomes.gd, scripts/table/mine_table.gd (DIAMOND_PER_HOUR, ORE_*).
Запуск: python3 tools/economy_sim.py [сценарий...]   (сценарии: base, coll, skills, rush; по умолчанию все четыре)"""
import bisect
import math
import sys

UP = {"rain": (15.0, 1.5), "faces": (60.0, 2.0), "mult": (250.0, 2.6)}
V0, VSTEP, VEIN_EXP, MIN_GAIN, RATIO = 1e6, 0.2, 1 / 3, 5, 0.7
MILESTONES = [100, 2000, 40000, 800000, 16000000]
COLLECTION_STEP, FULL_SET_STEP = 0.03, 0.10
ORE_LIMITS = [0.75, 0.88, 0.96]       # доля от максимума ценности: медь, железо, золото (алмаз — только алмазная жила)
MINI_SECONDS, MINI_COOLDOWN, MINI_FACTOR = 3.0, 8.0, 2.0   # «Золотой запал» от золотого самородка (пассивный)
MAX_ORE = [1, 2, 3, 3, 3, 3, 3]
DIAMOND_PER_HOUR = [0, 140, 180, 230, 300, 400, 500]   # алмазов в час «просто за игру»: не зависит от числа глыб
DRILL = [0.0, 0.10, 0.20, 0.35, 0.60]
SKILL_COSTS = [1, 2, 4, 6]
YIELD_COSTS = [1500, 3000, 6000, 12000]        # ветка «Добыча» (после ядра)
YIELD_BONUS = [1.0, 1.15, 1.35, 1.6, 2.0]
USE_YIELD = True
RATE_CAP = 35.0                      # глыб в секунду на картинке (высокое качество; на среднем 20, на низком 10)
RUSH_SECONDS, RUSH_FACTOR = 300.0, 7.0
RUSH_COOLDOWN = 3600.0   # между покупками лихорадки (с начала предыдущей)
FAC = [1, 1.1, 1.2, 1.35, 1.5, 1.7, 2.0]
TARGET_H = (1 / 6, 0.75, 3, 10, 48, 168)
_probs = {}


def ore_probs(m, zone, bundled, luck, vis):
    key = (m, zone, bundled, luck, round(vis, 1))
    if key in _probs:
        return _probs[key]
    counts = [0] * 5
    for v in range(1, m + 1):
        tier = sum(1 for x in ORE_LIMITS if v / m >= x)
        if bundled:
            tier = max(tier, 2)
        counts[min(tier, MAX_ORE[zone])] += 1
    pd = min(0.5, DIAMOND_PER_HOUR[zone] / 3600.0 * (1.3 if luck else 1.0) / max(vis, 0.2))   # шанс алмазной жилы у одной глыбы
    p = [c / m * (1 - pd) for c in counts]
    p[4] += pd
    _probs[key] = (p, pd)
    return _probs[key]


def spark_factor(vis, p, luck):
    """Средний множитель от «Золотого запала»: после запала перерыв MINI_COOLDOWN, потом ждём следующее золото."""
    gold_rate = vis * p[3]
    if gold_rate <= 0:
        return 1.0
    seconds = MINI_SECONDS + (2.0 if luck >= 2 else 0.0)
    uptime = seconds / (seconds + MINI_COOLDOWN + 1.0 / gold_rate)
    return 1.0 + (MINI_FACTOR - 1.0) * uptime


def collection_mult(finds):
    levels = [sum(1 for x in MILESTONES if finds[o] >= x) for o in range(1, 5)]
    return (1 + COLLECTION_STEP * sum(levels)) * (1 + FULL_SET_STEP * min(levels))


def simulate(TH, FAC, collection=True, skills=True, rush=False, hours=24 * 8, marks_h=TARGET_H, trace=False,
             scale=1.0, start_levels=0, vstep=VSTEP, income_mult=1.0, init=None, stop_core=False):
    """init: состояние с прежней планеты {finds, drill, luck, points}; scale — во сколько раз пороги зон выше;
    start_levels — стартовые уровни «Камнепада» и «Граней» (мета-улучшение); stop_core — остановиться, дойдя до ядра."""
    TH = [x * scale for x in TH]
    l = {"rain": start_levels, "faces": start_levels, "mult": 0}
    state = {}
    coins = total = 0.0
    veins = 0
    t = 0.0
    dt = 1.0
    prest, marks, notes = [], {}, []
    finds = list(init["finds"]) if init else [0.0, 0.0, 0.0, 0.0, 0.0]
    diamonds = 0.0
    diamonds_total = 0.0
    boost_until = 0.0
    boost_time_total = 0.0
    points = (2 if skills else 0) if not init else init["points"]
    drill, luck = (0, 0) if not init else (init["drill"], init["luck"])
    yld = init.get("yield", 0) if init else 0
    core_time = None
    next_rush = 0.0
    while t < hours * 3600:
        zone = bisect.bisect_right(TH, total)
        rate = (1 + 0.8 * l["rain"]) * (1 + DRILL[drill])
        vis = min(rate, RATE_CAP)
        weight = math.ceil(rate / RATE_CAP) if rate > RATE_CAP else 1
        m = 6 + 2 * l["faces"]
        p, pd = ore_probs(m, zone, weight > 1, luck >= 1, vis)
        coll = collection_mult(finds) if collection else 1.0
        spark = spark_factor(vis, p, luck)
        base_income = rate * (1 + m) / 2 * 1.5 ** l["mult"] * (1 + vstep * veins) * FAC[zone] * coll * (1 + 2 * pd) * spark * income_mult * YIELD_BONUS[yld]

        # покупки улучшений: жадно по приросту дохода на монету
        while True:
            best, bs = None, 0.0
            for k in UP:
                c = UP[k][0] * UP[k][1] ** l[k]
                if c > coins:
                    continue
                l[k] += 1
                rate2 = (1 + 0.8 * l["rain"]) * (1 + DRILL[drill])
                m2 = 6 + 2 * l["faces"]
                gain = rate2 * (1 + m2) / 2 * 1.5 ** l["mult"] - rate * (1 + m) / 2 * 1.5 ** (l["mult"] - (1 if k == "mult" else 0))
                l[k] -= 1
                # прирост относительно прежнего дохода (множители одинаковы)
                if gain / c > bs:
                    bs, best = gain / c, k
            if best is None:
                break
            coins -= UP[best][0] * UP[best][1] ** l[best]
            l[best] += 1
            rate = (1 + 0.8 * l["rain"]) * (1 + DRILL[drill])
            m = 6 + 2 * l["faces"]
            spark = spark_factor(vis, p, luck)
            base_income = rate * (1 + m) / 2 * 1.5 ** l["mult"] * (1 + vstep * veins) * FAC[zone] * coll * (1 + 2 * pd) * spark * income_mult * YIELD_BONUS[yld]
            vis = min(rate, RATE_CAP)
            weight = math.ceil(rate / RATE_CAP) if rate > RATE_CAP else 1
            p, pd = ore_probs(m, zone, weight > 1, luck >= 1, vis)
        step = min(dt, 10.0 if rush else dt)
        boosted = 0.0
        if rush:
            cost = 5 * (1 + zone)
            if boost_until <= t and t >= next_rush and diamonds >= cost:
                next_rush = t + RUSH_COOLDOWN
                diamonds -= cost
                boost_until = t + RUSH_SECONDS
            boosted = max(0.0, min(step, boost_until - t))
            boost_time_total += boosted
        mult = 1 + (RUSH_FACTOR - 1) * boosted / step
        gained = base_income * mult * step
        coins += gained
        total += gained
        for o in range(1, 5):
            finds[o] += vis * p[o] * step
        diamonds += vis * p[4] * step
        diamonds_total += vis * p[4] * step
        t += step
        pot = int((total / V0) ** VEIN_EXP)
        gain = pot - veins
        if gain >= max(MIN_GAIN, RATIO * veins):
            veins = pot
            prest.append((round(t / 3600, 2), gain, veins))
            l = {"rain": start_levels, "faces": start_levels, "mult": 0}
            coins = 0.0
            if skills:
                points += 1 + int(math.sqrt(gain))
                while drill < 4 and points >= SKILL_COSTS[drill]:
                    points -= SKILL_COSTS[drill]
                    drill += 1
                while drill >= 4 and luck < 4 and points >= SKILL_COSTS[luck]:
                    points -= SKILL_COSTS[luck]
                    luck += 1
                while USE_YIELD and drill >= 4 and luck >= 4 and yld < 4 and points >= YIELD_COSTS[yld]:
                    points -= YIELD_COSTS[yld]
                    yld += 1
                    notes.append((round(t / 3600, 1), yld))
        if skills and veins == 0:
            while drill < 4 and points >= SKILL_COSTS[drill]:
                points -= SKILL_COSTS[drill]
                drill += 1
        for h in marks_h:
            if h not in marks and t >= h * 3600:
                marks[h] = (total, collection_mult(finds) if collection else 1.0, diamonds_total, boost_time_total / t)
        if core_time is None and zone >= 6:
            core_time = t
            state = {"finds": list(finds), "drill": drill, "luck": luck, "points": points, "veins": veins, "yield": yld}
            if stop_core:
                break
        dt = min(30.0, dt * 1.002)
    marks["core_time"] = core_time
    marks["state"] = state
    marks["notes"] = notes
    return prest, marks


def calibrate(collection, skills, rush, iterations=5):
    TH = [1e99] * 6
    for _ in range(iterations):
        prest, marks = simulate(TH, FAC, collection, skills, rush)
        TH = [marks[h][0] for h in TARGET_H]
    return TH, prest, marks


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["base", "coll", "skills", "rush"]
    scenarios = {"base": (False, False, False), "coll": (True, False, False), "skills": (True, True, False), "rush": (True, True, True)}
    fixed = None
    for name in wanted:
        coll, skills, rush = scenarios[name]
        if fixed is None:
            fixed, _, _ = calibrate(*scenarios["base"])
            print("пороги базового сценария:", ["%.2e" % x for x in fixed])
        prest, marks = simulate(fixed, FAC, coll, skills, rush)
        print(f"\n== {name}: коллекция={coll} навыки={skills} лавка={rush} (с порогами базового сценария)")
        print("   сбросы:", [(a, b, c) for a, b, c in prest[:8]])
        for h in TARGET_H:
            total, cm, dia, up = marks[h]
            print(f"   {h:7.2f} ч: заработано {total:.2e}  коллекция ×{cm:.2f}  алмазов за всё время {dia:,.0f}  лихорадка {up*100:.0f}% времени")
