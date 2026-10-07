# Машины планет: проект и промпты для картинок

Статус: **реализовано** (7 октября 2026). Картинки (по три облика) лежат в `assets/pixel/machines/{wood,iron,steel}/`, данные в `Machines.LIST`
(поле `planet`), эффекты в `ClickerState`, здания на ленте в `FieldTable`, карточки и подсказки в `MachineStrip`/`Hints`, переводы EN/ZH, тесты (`_test_planet_machines`).

Что вышло по сравнению с проектом ниже:
- Открытие: машина открывается на своей планете (или позже) в зоне 1 или 3 этой планеты и остаётся навсегда (`ClickerState._machine_condition_met`).
- Поле: четыре хода ленты, пятый появляется с машинами Марса и Луны, шестой с машинами Титана и Венеры (`ClickerState.field_lanes()`). На пяти и шести ходах здания показываются ×2 (128 px), на четырёх ×3 (192 px). Вагонетка принимает руду с ленты только при четырёх ходах.
- Шаги эффектов откалиброваны мягче: Марсоход +0.3% к сдвигу порога руды за уровень (до +6%, а не до +10%), чтобы вместе с Конвейером не раздувать поток находок.
- Цены: 2·10⁴ (машины зоны 1) и 2·10⁹ (зоны 3) в ценах Земли, дальше умножаются на масштаб планеты, как у остальных машин.
- «Новая шахта» сбрасывает уровни всех машин, в том числе планетных, но запас динамита сверх вместимости (Горелка) не отнимается, а только перестаёт пополняться.
- Баланс на `pace_bot` не менялся: машины планет действуют на касания, золотые глыбы, хранителей, динамит и офлайн, а не на основную скорость добычи.

Ниже исходный проект и промпты.

## 1. Идея

Каждая планета (`Biomes.PLANETS`) со своей особенностью получает **две своих машины**. Они открываются, когда игрок долетел до
планеты и дошёл до нужной зоны на ней, и **остаются на всех следующих планетах** (как коллекция). На ленте поля после каждой планеты
добавляется ещё один ход: путь удлиняется, места для новых зданий хватает, пустых мест не остаётся (украшения заполняют остальное).

| Планета | Особенность | Машина 1 | Машина 2 |
|---|---|---|---|
| Марс | +25% алмазов | **Марсоход** | **Атмосферный компрессор** |
| Луна | золотая глыба чаще | **Лунный экскаватор** | **Электромагнитная катапульта** |
| Титан | динамит чаще | **Криогенный реактор** | **Метановая горелка** |
| Венера | хранители слабее, награда вдвое | **Кислотная ванна** | **Солнечный концентратор** |

Для «экзопланет» (дальше Венеры) машины повторяются без новых картинок; облик (дерево, железо, сталь) считается по уровню, как у машин
Земли. Цены и пределы уровней тоже по образцу Земли: растут с масштабом планеты (`planet_scale()`).

## 2. Эффекты (на что опираются)

Числа ориентировочные: их надо откалибровать `pace_bot` и `economy_sim.py`, как делалось для машин Земли (docs/MACHINES.md, раздел 13).

| Машина | Эффект | Куда подключается |
|---|---|---|
| Марсоход | руда в глыбах чаще: порог ценности для руды ниже на 0.5% за уровень (до +10%) | `ore_shift()` |
| Атмосферный компрессор | алмазная жила чаще: +3% за уровень (до +45%) | `diamond_chance_factor()` |
| Лунный экскаватор | золотая глыба появляется на 1.5% чаще за уровень (до −25% интервала) | `golden_interval_factor()` |
| Электромагнитная катапульта | пойманная золотая глыба платит +4% за уровень | `golden_payout_factor()` |
| Криогенный реактор | динамит платит на 1 секунду дохода больше за уровень (до +12 с) | `dynamite_seconds()` |
| Метановая горелка | запас динамита +1 за 3 уровня (до +5) | `dynamite_max()` |
| Кислотная ванна | хранители слабее на 1.5% за уровень (до −20%) | `boss_hp_factor()` |
| Солнечный концентратор | награда хранителей +3% за уровень (до +30%) и офлайн-доход +1% за уровень | `boss_reward_factor()`, офлайн |

Принцип тот же, что у Земли: машины усиливают то, что игрок уже делает, и **не заменяют** касания и офлайн.

## 3. Как вести картинку

Одна машина: три облика (дерево, железо, сталь) по 64×64, на пиксельной сетке 2 (см. docs/PIXEL.md). Генерируйте **лист из двух машин планеты
в одном облике** (3 запроса на планету) или каждую отдельно крупно (до 1024 px), потом `tools/pixelize.py` (`--bg magenta --size 64 --outline 0b1210`).
Положите результат в `assets/pixel/machines/<облик>/<id>.png`, где `<id>`: `rover`, `compressor`, `excavator`, `catapult`, `reactor`, `burner`, `acid`, `solar`.

## 4. Префикс стиля (в начало каждого запроса)

> Pixel art game sprite, crisp hard pixels, no anti-aliasing, no gradients, no dithering noise, limited palette, 1-pixel dark outline (#0b1210),
> flat shading in 3 tones, light from the top left, three-quarter isometric view, one machine centered on a solid pure magenta (#FF00FF)
> background, no text, no ground shadow, no characters. Same visual style as a small mining-game machine: chunky, readable at 64x64.

**Материал (последний абзац, меняется по облику):**
- Дерево: `Material: rough wooden planks, rope, rusty nails and brass rivets, warm brown and copper tones.`
- Железо: `Material: riveted dark iron plates with brass rivets, blue-gray steel tones.`
- Сталь: `Material: polished bright steel with gold trim, light blue highlights and gold details.`

## 5. Промпты по машинам

### Марс

**1. Марсоход (`rover`)**
> [Префикс]. A small six-wheeled Mars rover for a mining game: a boxy chassis with a drill arm on the front, a scoop bucket, a tiny antenna
> and a camera mast, dusty red-orange paint accents. [Материал].

**2. Атмосферный компрессор (`compressor`)**
> [Префикс]. A chunky atmospheric compressor: a big round pressure tank with a pipe manifold, a valve wheel, a pressure gauge and two
> exhaust pipes puffing small steam, sitting on a metal base. [Материал].

### Луна

**3. Лунный экскаватор (`excavator`)**
> [Префикс]. A lunar excavator: a tracked chassis with a jointed arm ending in a big toothed bucket full of gray moon rock, a small cab
> with a round window, wide treads. [Материал].

**4. Электромагнитная катапульта (`catapult`)**
> [Префикс]. An electromagnetic mass-driver catapult: a long angled rail launcher with two glowing blue coils along the barrel, a support
> frame, and a small cluster of ore chunks on the loading platform. [Материал].

### Титан

**5. Криогенный реактор (`reactor`)**
> [Префикс]. A cryogenic reactor: a tall cylinder with frosted glass window showing glowing cyan liquid, frost on the pipes, a coil
> of cold blue pipes and a small control panel with lights. [Материал].

**6. Метановая горелка (`burner`)**
> [Префикс]. A methane burner: a squat furnace with a wide chimney, a bright orange flame in the open grate, gas tanks on the side and a
> pipe with a shut-off valve. [Материал].

### Венера

**7. Кислотная ванна (`acid`)**
> [Префикс]. An acid bath: a wide open metal vat filled with bubbling yellow-green acid, a hoist with a hook holding a chunk of ore,
> corroded metal edges, small bubbles rising. [Материал].

**8. Солнечный концентратор (`solar`), «солнечная печь»**
> [Префикс]. A sun-furnace: a big round parabolic mirror dish made of many small shiny tiles on a thick stand, a bright yellow beam of light going from the
> dish into a glowing orange crucible of molten gold in front of it. Recognizable as a mirror and a cauldron, not an abstract gadget. [Материал].

## 6. Значки и «здания»

Для каждой машины нужен значок 24×24 для карточки и журнала (идёт в `assets/pixel/icons/`): упрощённый силуэт той же машины, один цвет акцента.
Промпт: `[Префикс]. A tiny 24x24 icon of the <machine>, simple bold silhouette, two or three colors.`

## 7. Что сделаю после картинок

1. Данные в `Machines.LIST` (поле `planet`, условие открытия, цена, предел, шаг), эффекты в `ClickerState`, тесты на каждую.
2. Ход ленты и здания на поле (`FieldTable`): число ходов растёт с планетой, места зданий считаются от длины пути.
3. Карточки, подсказки, переводы (EN/ZH), обучение при открытии первой планетной машины.
4. Калибровка на `pace_bot` и `economy_sim.py`; запись результатов в docs/MACHINES.md.

## 8. Листы целиком (все 8 машин в одном облике, как делали для Земли)

Каждый лист: сетка 4×2, строка 1 — Марс (Марсоход, Компрессор) и Луна (Экскаватор, Катапульта), строка 2 — Титан (Реактор, Горелка) и Венера (Кислотная ванна,
Концентратор). Порядок слева направо и сверху вниз = порядку имён для `pixelize.py`. Генерируйте три листа, меняется только последний абзац `Material`.

> Pixel art game sprite sheet, crisp hard pixels, no anti-aliasing, no gradients, no dithering noise, limited palette, 1-pixel dark outline,
> flat shading in 3 tones, light from the top left, three-quarter isometric view, no text, no ground shadows, no characters, every machine
> centered in its own cell with equal spacing on a solid pure magenta (#FF00FF) background. A 4x2 grid of eight separate mining-game
> machines, each about 64x64 pixels in size, in this exact order, left to right, top to bottom:
> 1) a six-wheeled Mars rover with a drill arm, scoop bucket and antenna,
> 2) an atmospheric compressor: round pressure tank, pipe manifold, valve wheel, pressure gauge, two small steam pipes,
> 3) a lunar excavator: tracked chassis, jointed arm with a toothed bucket full of gray rock, small cab,
> 4) an electromagnetic mass-driver catapult: long angled rail with two glowing blue coils and ore chunks on the loading platform,
> 5) a cryogenic reactor: tall cylinder with frosted window showing glowing cyan liquid, frosty cold blue pipes, small control panel,
> 6) a methane burner: squat furnace with wide chimney, bright orange flame in the grate, gas tanks and a valve pipe,
> 7) an acid bath: wide open metal vat of bubbling yellow-green acid with a hoist holding an ore chunk, corroded edges,
> 8) a Venus sun-furnace: a big round parabolic mirror dish made of many small shiny tiles, tilted toward the viewer, on a thick wooden or metal stand, with a bright yellow beam of light going from the dish into a glowing orange crucible full of molten gold on the ground in front of it.
> Material: **[WOODEN: rough planks, rope, rusty nails and brass rivets, warm brown and copper tones] / [IRON: riveted dark iron plates with
> brass rivets, blue-gray steel tones] / [STEEL: polished bright steel with gold trim, light blue highlights and gold details]**.

Обработка листа (подставьте облик в папку):

```bash
python tools/pixelize.py sheet_wood.png --grid 4x2 --size 64 --bg magenta --outline 0b1210 \
    -o assets/pixel/machines/wood/ --names rover,compressor,excavator,catapult,reactor,burner,acid,solar
```

Если генератор плохо держит сетку 4×2, делайте два листа 2×2 (Марс и Луна, Титан и Венера) тем же текстом, оставив по четыре машины.
